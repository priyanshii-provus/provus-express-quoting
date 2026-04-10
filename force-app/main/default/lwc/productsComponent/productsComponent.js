import { LightningElement, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getProducts from "@salesforce/apex/ProductController.getProducts";
import createProduct from "@salesforce/apex/ProductController.createProduct";
import deleteProduct from "@salesforce/apex/ProductController.deleteProduct";
import updateProducts from "@salesforce/apex/ProductController.updateProducts";
import importProducts from "@salesforce/apex/ProductController.importProducts";
import { refreshApex } from "@salesforce/apex";

const actions = [
  { label: "Edit", name: "edit" },
  { label: "Delete", name: "delete" }
];

const columns = [
  { label: "Product Name", fieldName: "Name", editable: true },
  { label: "Product Code", fieldName: "ProductCode", editable: true },
  { label: "Family", fieldName: "Family", editable: true },
  { label: "Active", fieldName: "IsActive", type: "boolean", editable: true },
  {
    type: "action",
    typeAttributes: { rowActions: actions }
  }
];

const CSV_TEMPLATE_HEADER = "Name,ProductCode,Description,Family,Price,Cost,Is_Active";
const CSV_TEMPLATE_ROWS = [
  "Cloud Hosting Plan,CHP-001,Enterprise cloud hosting solution,Software,500,350,true",
  "API Integration Service,AIS-001,REST API integration package,Service,1200,800,true",
  "Security Suite,SEC-001,Advanced cybersecurity tools,Software,750,500,true",
  "Data Analytics Platform,DAP-001,Business intelligence dashboard,Software,950,600,true",
  "Support Package,SUP-001,24/7 premium support service,Service,300,150,true"
];

export default class ProductsComponent extends LightningElement {
  @track products = [];
  @track draftValues = [];
  @track isModalOpen = false;
  @track isImportModalOpen = false;
  @track newProduct = {
    name: "",
    productCode: "",
    description: "",
    family: "",
    cost: null,
    price: null
  };
  columns = columns;
  wiredProductsResult;

  // Import state
  @track importFileName = "";
  @track importRowCount = 0;
  @track importError = "";
  @track isImporting = false;
  @track isDragOver = false;
  parsedRows = [];

  get familyOptions() {
    return [
      { label: "None", value: "" },
      { label: "Software", value: "Software" },
      { label: "Hardware", value: "Hardware" },
      { label: "Service", value: "Service" }
    ];
  }

  get dropzoneClass() {
    let cls = "dropzone";
    if (this.isDragOver) cls += " dropzone-active";
    if (this.importFileName) cls += " dropzone-has-file";
    return cls;
  }

  get isImportDisabled() {
    return !this.importFileName || this.isImporting;
  }

  get importButtonLabel() {
    return this.isImporting ? "Importing..." : "Import";
  }

  @wire(getProducts, { activeOnly: false })
  wiredProducts(result) {
    this.wiredProductsResult = result;
    if (result.data) {
      this.products = result.data;
    } else if (result.error) {
      console.error("Error fetching products:", result.error);
    }
  }

  handleNewProduct() {
    this.newProduct = {
      name: "",
      productCode: "",
      description: "",
      family: "",
      cost: null,
      price: null
    };
    this.isModalOpen = true;
  }

  closeModal() {
    this.isModalOpen = false;
  }

  handleModalFieldChange(event) {
    const field = event.target.dataset.field;
    if (field) {
      this.newProduct = { ...this.newProduct, [field]: event.target.value };
    }
  }

  handleModalFamilyChange(event) {
    this.newProduct = { ...this.newProduct, family: event.detail.value };
  }

  handleSaveNewProduct() {
    if (!this.newProduct.name) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "Product Name is required",
          variant: "error"
        })
      );
      return;
    }
    createProduct({
      name: this.newProduct.name,
      productCode: this.newProduct.productCode,
      description: this.newProduct.description,
      family: this.newProduct.family,
      cost: this.newProduct.cost ? parseFloat(this.newProduct.cost) : 0,
      price: this.newProduct.price ? parseFloat(this.newProduct.price) : 0
    })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Product created",
            variant: "success"
          })
        );
        this.isModalOpen = false;
        return refreshApex(this.wiredProductsResult);
      })
      .catch((error) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: error.body?.message || "Error creating product",
            variant: "error"
          })
        );
      });
  }

  handleSave(event) {
    this.draftValues = event.detail.draftValues;
    const records = this.draftValues.slice().map((draft) => {
      return { ...draft };
    });

    updateProducts({ products: records })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Products updated",
            variant: "success"
          })
        );
        this.draftValues = [];
        return refreshApex(this.wiredProductsResult);
      })
      .catch((error) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: error.body?.message || "Error updating products",
            variant: "error"
          })
        );
      });
  }

  handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;
    switch (actionName) {
      case "edit":
        break;
      case "delete":
        deleteProduct({ productId: row.Id })
          .then(() => {
            this.dispatchEvent(
              new ShowToastEvent({
                title: "Success",
                message: "Product deleted",
                variant: "success"
              })
            );
            return refreshApex(this.wiredProductsResult);
          })
          .catch((error) => {
            console.error("Error deleting product", error);
          });
        break;
      default:
    }
  }


  // ═══════════ CSV IMPORT LOGIC ═══════════

  handleOpenImportModal() {
    this.isImportModalOpen = true;
    this.importFileName = "";
    this.importRowCount = 0;
    this.importError = "";
    this.parsedRows = [];
    this.isDragOver = false;
  }

  closeImportModal() {
    this.isImportModalOpen = false;
  }

  handleDragOver(event) {
    event.preventDefault();
    this.isDragOver = true;
  }

  handleDragLeave() {
    this.isDragOver = false;
  }

  handleDrop(event) {
    event.preventDefault();
    this.isDragOver = false;
    const files = event.dataTransfer.files;
    if (files.length > 0) {
      this.processFile(files[0]);
    }
  }

  handleDropzoneClick() {
    const fileInput = this.template.querySelector('input[type="file"]');
    if (fileInput) fileInput.click();
  }

  handleFileChange(event) {
    const files = event.target.files;
    if (files.length > 0) this.processFile(files[0]);
  }

  processFile(file) {
    this.importError = "";
    if (!file.name.endsWith(".csv")) {
      this.importError = "Please upload a .csv file.";
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      this.importError = "File size exceeds 5MB limit.";
      return;
    }
    this.importFileName = file.name;
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const rows = this.parseCsv(e.target.result);
        if (rows.length === 0) {
          this.importError = "No valid data rows found in CSV.";
          this.importFileName = "";
          return;
        }
        this.parsedRows = rows;
        this.importRowCount = rows.length;
      } catch (err) {
        this.importError = "Error parsing CSV: " + err.message;
        this.importFileName = "";
      }
    };
    reader.readAsText(file);
  }

  parseCsv(text) {
    const lines = text.split(/\r\n|\n/).filter((l) => l.trim());
    if (lines.length < 2) return [];
    const headers = lines[0].split(",").map((h) => h.trim());
    const rows = [];
    for (let i = 1; i < lines.length; i++) {
      const values = lines[i].split(",").map((v) => v.trim());
      if (values.length < headers.length) continue;
      const row = {};
      headers.forEach((header, idx) => {
        row[header] = values[idx] || "";
      });
      if (row.Name) rows.push(row);
    }
    return rows;
  }

  handleImportCsv() {
    if (this.parsedRows.length === 0) {
      this.importError = "No data to import.";
      return;
    }
    this.isImporting = true;
    this.importError = "";

    importProducts({ products: this.parsedRows })
      .then((count) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Import Successful",
            message: `${count} product(s) imported successfully.`,
            variant: "success"
          })
        );
        this.isImportModalOpen = false;
        this.isImporting = false;
        return refreshApex(this.wiredProductsResult);
      })
      .catch((error) => {
        this.importError = error.body?.message || "An error occurred during import.";
        this.isImporting = false;
      });
  }

  handleDownloadTemplate() {
    const csvContent = CSV_TEMPLATE_HEADER + "\n" + CSV_TEMPLATE_ROWS.join("\n");
    const blob = new Blob([csvContent], { type: "text/csv" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "products_template.csv";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }
}

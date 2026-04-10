import { LightningElement, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getAddons from "@salesforce/apex/AddonController.getAddons";
import createAddon from "@salesforce/apex/AddonController.createAddon";
import deleteAddon from "@salesforce/apex/AddonController.deleteAddon";
import updateAddons from "@salesforce/apex/AddonController.updateAddons";
import importAddons from "@salesforce/apex/AddonController.importAddons";
import { refreshApex } from "@salesforce/apex";

const actions = [
  { label: "Edit", name: "edit" },
  { label: "Delete", name: "delete" }
];

const columns = [
  { label: "Add-on Name", fieldName: "Name", editable: true },
  {
    label: "Price",
    fieldName: "Price__c",
    type: "currency",
    editable: true,
    typeAttributes: { currencyCode: "INR" }
  },
  {
    label: "Cost",
    fieldName: "Cost__c",
    type: "currency",
    editable: true,
    typeAttributes: { currencyCode: "INR" }
  },
  { label: "Active", fieldName: "Active__c", type: "boolean", editable: true },
  {
    type: "action",
    typeAttributes: { rowActions: actions }
  }
];

const CSV_TEMPLATE_HEADER = "Name,Description,Price,Cost,Billing_Unit,Is_Active";
const CSV_TEMPLATE_ROWS = [
  "Project Management,Project management services,125,100,Hour,true",
  "Code Review,Additional code review service,50,30,Hour,true",
  "Training Sessions,On-site training workshops,200,120,Each,true",
  "Extended Warranty,Extended 2-year warranty,300,180,Each,true",
  "Priority Support,Priority queue support plan,150,90,Hour,true"
];

export default class AddonsComponent extends LightningElement {
  @track addons = [];
  @track draftValues = [];
  @track isModalOpen = false;
  @track isImportModalOpen = false;
  @track newAddon = {
    name: "",
    price: null,
    cost: null,
    billingUnit: "Each",
    description: ""
  };
  columns = columns;
  wiredAddonsResult;

  // Import state
  @track importFileName = "";
  @track importRowCount = 0;
  @track importError = "";
  @track isImporting = false;
  @track isDragOver = false;
  parsedRows = [];

  get billingUnitOptions() {
    return [{ label: "Each", value: "Each" }];
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

  @wire(getAddons, { activeOnly: false })
  wiredAddonsResponse(result) {
    this.wiredAddonsResult = result;
    if (result.data) {
      this.addons = result.data;
    } else if (result.error) {
      console.error("Error fetching addons:", result.error);
    }
  }

  handleNewAddon() {
    this.newAddon = {
      name: "",
      price: null,
      cost: null,
      billingUnit: "Each",
      description: ""
    };
    this.isModalOpen = true;
  }

  closeModal() {
    this.isModalOpen = false;
  }

  handleModalFieldChange(event) {
    const field = event.target.dataset.field;
    if (field) {
      this.newAddon = { ...this.newAddon, [field]: event.target.value };
    }
  }

  handleModalBillingChange(event) {
    this.newAddon = { ...this.newAddon, billingUnit: event.detail.value };
  }

  handleSaveNewAddon() {
    if (!this.newAddon.name) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "Add-on Name is required",
          variant: "error"
        })
      );
      return;
    }
    createAddon({
      name: this.newAddon.name,
      price: this.newAddon.price ? parseFloat(this.newAddon.price) : 0,
      cost: this.newAddon.cost ? parseFloat(this.newAddon.cost) : 0,
      billingUnit: this.newAddon.billingUnit,
      description: this.newAddon.description
    })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Add-on created",
            variant: "success"
          })
        );
        this.isModalOpen = false;
        return refreshApex(this.wiredAddonsResult);
      })
      .catch((error) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: error.body?.message || "Error creating add-on",
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

    updateAddons({ addons: records })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Add-ons updated",
            variant: "success"
          })
        );
        this.draftValues = [];
        return refreshApex(this.wiredAddonsResult);
      })
      .catch((error) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: error.body?.message || "Error updating add-ons",
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
        deleteAddon({ addonId: row.Id })
          .then(() => {
            this.dispatchEvent(
              new ShowToastEvent({
                title: "Success",
                message: "Add-on deleted",
                variant: "success"
              })
            );
            return refreshApex(this.wiredAddonsResult);
          })
          .catch((error) => console.error("Error deleting", error));
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
    if (files.length > 0) this.processFile(files[0]);
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

    importAddons({ addons: this.parsedRows })
      .then((count) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Import Successful",
            message: `${count} add-on(s) imported successfully.`,
            variant: "success"
          })
        );
        this.isImportModalOpen = false;
        this.isImporting = false;
        return refreshApex(this.wiredAddonsResult);
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
    a.download = "addons_template.csv";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }
}

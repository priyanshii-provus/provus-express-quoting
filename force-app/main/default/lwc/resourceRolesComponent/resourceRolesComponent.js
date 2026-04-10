import { LightningElement, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getResourceRoles from "@salesforce/apex/ResourceRoleController.getResourceRoles";
import createResourceRole from "@salesforce/apex/ResourceRoleController.createResourceRole";
import deleteResourceRole from "@salesforce/apex/ResourceRoleController.deleteResourceRole";
import updateResourceRoles from "@salesforce/apex/ResourceRoleController.updateResourceRoles";
import importResourceRoles from "@salesforce/apex/ResourceRoleController.importResourceRoles";
import { refreshApex } from "@salesforce/apex";

const actions = [
  { label: "Edit", name: "edit" },
  { label: "Delete", name: "delete" }
];

const columns = [
  { label: "Role Name", fieldName: "Name", editable: true },
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

const CSV_TEMPLATE_HEADER = "Name,Billing_Unit,Price,Cost,Location,Is_Active";
const CSV_TEMPLATE_ROWS = [
  "Senior Developer,Hour,150,120,San Francisco,true",
  "Project Manager,Hour,175,140,New York,true",
  "QA Engineer,Hour,100,80,Austin,true",
  "UX Designer,Hour,130,100,Remote,true",
  "DevOps Engineer,Hour,160,125,Chicago,true"
];

export default class ResourceRolesComponent extends LightningElement {
  @track resources = [];
  @track draftValues = [];
  @track isModalOpen = false;
  @track isImportModalOpen = false;
  @track newRole = {
    name: "",
    billingUnit: "Hour",
    price: null,
    cost: null,
    location: ""
  };
  columns = columns;
  wiredRolesResult;

  // Import state
  @track importFileName = "";
  @track importRowCount = 0;
  @track importError = "";
  @track isImporting = false;
  @track isDragOver = false;
  parsedRows = [];

  get billingUnitOptions() {
    return [{ label: "Hour", value: "Hour" }];
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

  @wire(getResourceRoles, { activeOnly: false })
  wiredRoles(result) {
    this.wiredRolesResult = result;
    if (result.data) {
      this.resources = result.data;
    } else if (result.error) {
      console.error("Error fetching resource roles:", result.error);
    }
  }

  handleNewResource() {
    this.newRole = {
      name: "",
      billingUnit: "Hour",
      price: null,
      cost: null,
      location: ""
    };
    this.isModalOpen = true;
  }

  closeModal() {
    this.isModalOpen = false;
  }

  handleModalFieldChange(event) {
    const field = event.target.dataset.field;
    if (field) {
      this.newRole = { ...this.newRole, [field]: event.target.value };
    }
  }

  handleModalBillingChange(event) {
    this.newRole = { ...this.newRole, billingUnit: event.detail.value };
  }

  handleSaveNewRole() {
    if (!this.newRole.name) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "Role Name is required",
          variant: "error"
        })
      );
      return;
    }
    createResourceRole({
      name: this.newRole.name,
      billingUnit: this.newRole.billingUnit,
      price: this.newRole.price ? parseFloat(this.newRole.price) : 0,
      cost: this.newRole.cost ? parseFloat(this.newRole.cost) : 0,
      location: this.newRole.location
    })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Resource Role created",
            variant: "success"
          })
        );
        this.isModalOpen = false;
        return refreshApex(this.wiredRolesResult);
      })
      .catch((error) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: error.body?.message || "Error creating role",
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

    updateResourceRoles({ roles: records })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Resource Roles updated",
            variant: "success"
          })
        );
        this.draftValues = [];
        return refreshApex(this.wiredRolesResult);
      })
      .catch((error) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: error.body?.message || "Error updating roles",
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
        deleteResourceRole({ roleId: row.Id })
          .then(() => {
            this.dispatchEvent(
              new ShowToastEvent({
                title: "Success",
                message: "Resource Role deleted",
                variant: "success"
              })
            );
            return refreshApex(this.wiredRolesResult);
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
    if (files.length > 0) {
      this.processFile(files[0]);
    }
  }

  handleDropzoneClick() {
    const fileInput = this.template.querySelector('input[type="file"]');
    if (fileInput) {
      fileInput.click();
    }
  }

  handleFileChange(event) {
    const files = event.target.files;
    if (files.length > 0) {
      this.processFile(files[0]);
    }
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
        const text = e.target.result;
        const rows = this.parseCsv(text);
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
      // Only add if Name is present
      if (row.Name) {
        rows.push(row);
      }
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

    importResourceRoles({ roles: this.parsedRows })
      .then((count) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Import Successful",
            message: `${count} resource role(s) imported successfully.`,
            variant: "success"
          })
        );
        this.isImportModalOpen = false;
        this.isImporting = false;
        return refreshApex(this.wiredRolesResult);
      })
      .catch((error) => {
        this.importError =
          error.body?.message || "An error occurred during import.";
        this.isImporting = false;
      });
  }

  handleDownloadTemplate() {
    const csvContent =
      CSV_TEMPLATE_HEADER + "\n" + CSV_TEMPLATE_ROWS.join("\n");
    const blob = new Blob([csvContent], { type: "text/csv" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "resource_roles_template.csv";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }
}

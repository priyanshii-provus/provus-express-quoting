import { LightningElement, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getResourceRoles from "@salesforce/apex/ResourceRoleController.getResourceRoles";
import createResourceRole from "@salesforce/apex/ResourceRoleController.createResourceRole";
import deleteResourceRole from "@salesforce/apex/ResourceRoleController.deleteResourceRole";
import updateResourceRoles from "@salesforce/apex/ResourceRoleController.updateResourceRoles";
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
    typeAttributes: { currencyCode: "USD" }
  },
  {
    label: "Cost",
    fieldName: "Cost__c",
    type: "currency",
    editable: true,
    typeAttributes: { currencyCode: "USD" }
  },
  { label: "Active", fieldName: "Active__c", type: "boolean", editable: true },
  {
    type: "action",
    typeAttributes: { rowActions: actions }
  }
];

export default class ResourceRolesComponent extends LightningElement {
  @track resources = [];
  @track draftValues = [];
  @track isModalOpen = false;
  @track newRole = {
    name: "",
    billingUnit: "Hour",
    price: null,
    cost: null,
    location: ""
  };
  columns = columns;
  wiredRolesResult;

  get billingUnitOptions() {
    return [{ label: "Hour", value: "Hour" }];
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

  handleAIAssistant() {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "AI Assistant",
        message: "Opening AI insights for Resource Roles...",
        variant: "info"
      })
    );
    this.dispatchEvent(
      new CustomEvent("navigatetotab", {
        detail: { tab: "AI Assistant" },
        bubbles: true,
        composed: true
      })
    );
  }
}

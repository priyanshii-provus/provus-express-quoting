import { LightningElement, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getAddons from "@salesforce/apex/AddonController.getAddons";
import createAddon from "@salesforce/apex/AddonController.createAddon";
import deleteAddon from "@salesforce/apex/AddonController.deleteAddon";
import updateAddons from "@salesforce/apex/AddonController.updateAddons";
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

export default class AddonsComponent extends LightningElement {
  @track addons = [];
  @track draftValues = [];
  @track isModalOpen = false;
  @track newAddon = {
    name: "",
    price: null,
    cost: null,
    billingUnit: "Each",
    description: ""
  };
  columns = columns;
  wiredAddonsResult;

  get billingUnitOptions() {
    return [{ label: "Each", value: "Each" }];
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

  handleAIAssistant() {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "AI Assistant",
        message:
          "Evaluating add-on attachment rates and cross-sell opportunities...",
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

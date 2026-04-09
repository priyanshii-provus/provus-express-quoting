import { LightningElement, api, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getQuoteLineItems from "@salesforce/apex/QuoteService.getQuoteLineItems";
import addLineItem from "@salesforce/apex/QuoteService.addLineItem";
import removeLineItem from "@salesforce/apex/QuoteService.removeLineItem";
import updateLineItems from "@salesforce/apex/QuoteService.updateLineItems";
import getPricebookEntries from "@salesforce/apex/ProductController.getPricebookEntries";
import getResourceRoles from "@salesforce/apex/ResourceRoleController.getResourceRoles";
import getAddons from "@salesforce/apex/AddonController.getAddons";
import getQuoteById from "@salesforce/apex/QuoteService.getQuoteById";
import { refreshApex } from "@salesforce/apex";

const actions = [
  { label: "Edit", name: "edit" },
  { label: "Delete", name: "delete" }
];

const columns = [
  { label: "Name", fieldName: "Name", type: "text" },
  { label: "Task", fieldName: "Phase__c", type: "text", editable: true },
  {
    label: "Start Date",
    fieldName: "Start_Date__c",
    type: "date-local",
    typeAttributes: {
      month: "short",
      day: "2-digit",
      year: "numeric",
      timeZone: "UTC"
    }
  },
  {
    label: "End Date",
    fieldName: "End_Date__c",
    type: "date-local",
    typeAttributes: {
      month: "short",
      day: "2-digit",
      year: "numeric",
      timeZone: "UTC"
    }
  },
  {
    label: "Quantity (Months/Items)",
    fieldName: "Quantity",
    type: "number",
    typeAttributes: { minimumFractionDigits: 0, maximumFractionDigits: 2 },
    editable: true
  },
  {
    label: "Base Rate",
    fieldName: "BaseRateDisplay",
    type: "currency",
    typeAttributes: { currencyCode: "USD" }
  },
  {
    label: "Unit Price",
    fieldName: "UnitPrice",
    type: "currency",
    editable: true,
    typeAttributes: { currencyCode: "USD" }
  },
  {
    label: "Discount %",
    fieldName: "Discount",
    type: "number",
    editable: true
  },
  {
    label: "Total Price",
    fieldName: "TotalPrice",
    type: "currency",
    typeAttributes: { currencyCode: "USD" }
  },
  {
    type: "action",
    typeAttributes: { rowActions: actions }
  }
];

const PERIOD_HOURS = {
  Weeks: 40,
  Months: 160,
  Quarters: 480,
  Years: 1920
};

export default class QuoteLineItemsComponent extends LightningElement {
  @api recordId;
  @track lineItems = [];
  @track draftValues = [];
  columns = columns;
  wiredLineItemsResult;

  // Modal states
  @track isProductModalOpen = false;
  @track isResourceModalOpen = false;
  @track isAddonModalOpen = false;

  // Quote State
  @track quoteTimePeriod = "Months";
  @track quoteStatus = "Draft";

  get isApproved() {
    return this.quoteStatus === "Approved";
  }

  @wire(getQuoteById, { quoteId: "$recordId" })
  wiredQuote({ error, data }) {
    if (data) {
      this.quoteTimePeriod = data.Quote_Time_Period__c || "Months";
      this.quoteStatus = data.Status;
      this.updateColumns();
    } else if (error) {
      console.error("Error fetching Quote details", error);
    }
  }

  updateColumns() {
    if (this.isApproved) {
      this.columns = columns
        .map((col) => {
          let newCol = { ...col };
          if (newCol.editable) newCol.editable = false;
          return newCol;
        })
        .filter((col) => col.type !== "action");
    } else {
      this.columns = [...columns];
    }
  }

  // Product Modal Props
  @track productOptions = [];
  @track selectedPBEId = "";
  @track productQuantity = 1;
  @track productUnitPrice = 0;
  pricebookMap = new Map();

  // Resource Modal Props
  @track resourceOptions = [];
  @track selectedRoleId = "";
  @track resourceQuantity = 1;
  @track resourceUnitPrice = 0;
  @track resourcePhase = "";
  standardHours = 160;
  rolesMap = new Map();

  // Addon Modal Props
  @track addonOptions = [];
  @track selectedAddonId = "";
  @track addonQuantity = 1;
  @track addonUnitPrice = 0;
  addonsMap = new Map();

  @wire(getQuoteLineItems, { quoteId: "$recordId" })
  wiredLineItems(result) {
    this.wiredLineItemsResult = result;
    if (result.data) {
      this.lineItems = result.data.map((row) => {
        let baseRate = row.UnitPrice || 0;
        if (row.Item_Type__c === "Labor" || row.Item_Type__c === "Resource") {
          // Derives base rate back from the period Unit Price
          const multiplier = PERIOD_HOURS[this.quoteTimePeriod] || 160;
          baseRate = (row.UnitPrice || 0) / multiplier;
        }

        return {
          ...row,
          Name:
            (row.Item_Type__c === "Labor" || row.Item_Type__c === "Resource") &&
            row.Resource_Role__r
              ? row.Resource_Role__r.Name
              : row.Item_Type__c === "Add-on" && row.Add_on__r
                ? row.Add_on__r.Name
                : row.Product2
                  ? row.Product2.Name
                  : "Item",
          BaseRateDisplay: baseRate
        };
      });
    } else if (result.error) {
      console.error(result.error);
    }
  }

  @wire(getPricebookEntries, { pricebookId: null })
  wiredPBEs({ data, error }) {
    if (data) {
      this.productOptions = data.map((pbe) => {
        this.pricebookMap.set(pbe.Id, pbe);
        return { label: pbe.Product2.Name, value: pbe.Id };
      });
    } else if (error) {
      console.error("Error fetching PricebookEntries", error);
    }
  }

  @wire(getResourceRoles, { activeOnly: true })
  wiredRoles({ data, error }) {
    if (data) {
      this.resourceOptions = data.map((r) => {
        this.rolesMap.set(r.Id, r);
        return { label: r.Name, value: r.Id };
      });
    } else if (error) {
      console.error("Error fetching Resource Roles", error);
    }
  }

  @wire(getAddons, { activeOnly: true })
  wiredAddons({ data, error }) {
    if (data) {
      this.addonOptions = data.map((a) => {
        this.addonsMap.set(a.Id, a);
        return { label: a.Name, value: a.Id };
      });
    } else if (error) {
      console.error("Error fetching Add-ons", error);
    }
  }

  get isSaveDisabled() {
    return this.draftValues.length === 0;
  }

  handleAddProduct() {
    this.selectedPBEId = "";
    this.productQuantity = 1;
    this.productUnitPrice = 0;
    this.isProductModalOpen = true;
  }
  closeProductModal() {
    this.isProductModalOpen = false;
  }

  handleProductChange(event) {
    this.selectedPBEId = event.detail.value;
    const pbe = this.pricebookMap.get(this.selectedPBEId);
    if (pbe) {
      this.productUnitPrice = pbe.UnitPrice || 0;
    }
  }
  handleProductQuantityChange(event) {
    this.productQuantity = event.target.value;
  }
  handleProductPriceChange(event) {
    this.productUnitPrice = event.target.value;
  }

  handleSaveProduct() {
    if (!this.selectedPBEId) return;
    const pbe = this.pricebookMap.get(this.selectedPBEId);
    addLineItem({
      quoteId: this.recordId,
      pricebookEntryId: this.selectedPBEId,
      product2Id: pbe.Product2Id,
      quantity: this.productQuantity,
      unitPrice: this.productUnitPrice,
      resourceRoleId: null,
      durationHours: null,
      phase: null,
      itemType: "Product",
      addonId: null
    })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Product added",
            variant: "success"
          })
        );
        this.isProductModalOpen = false;
        return refreshApex(this.wiredLineItemsResult);
      })
      .catch((e) => {
        console.error(e);
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: e.body?.message || "Failed to add product",
            variant: "error"
          })
        );
      });
  }

  handleAddResource() {
    this.selectedRoleId = "";

    let defaultQuantity = 1;
    this.standardHours = PERIOD_HOURS[this.quoteTimePeriod] || 160;
    this.resourceQuantity = defaultQuantity;
    this.resourceUnitPrice = 0;
    this.resourcePhase = "";
    this.isResourceModalOpen = true;
  }
  closeResourceModal() {
    this.isResourceModalOpen = false;
  }

  handleResourceQuantityChange(event) {
    this.resourceQuantity = parseFloat(event.target.value);
  }

  handleResourceChange(event) {
    this.selectedRoleId = event.detail.value;
    const role = this.rolesMap.get(this.selectedRoleId);
    if (role) {
      this.resourceUnitPrice = (role.Price__c || 0) * this.standardHours;
    }
  }
  handleResourcePhaseChange(event) {
    this.resourcePhase = event.target.value;
  }

  handleSaveResource() {
    if (!this.selectedRoleId) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "Please select a resource role",
          variant: "error"
        })
      );
      return;
    }
    if (
      !this.resourceQuantity ||
      isNaN(this.resourceQuantity) ||
      this.resourceQuantity <= 0
    ) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "Please enter a valid duration (months)",
          variant: "error"
        })
      );
      return;
    }
    addLineItem({
      quoteId: this.recordId,
      pricebookEntryId: null,
      product2Id: null,
      quantity: this.resourceQuantity,
      unitPrice: this.resourceUnitPrice,
      resourceRoleId: this.selectedRoleId,
      durationHours: this.standardHours,
      phase: this.resourcePhase,
      itemType: "Labor",
      addonId: null
    })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Resource added",
            variant: "success"
          })
        );
        this.isResourceModalOpen = false;
        return refreshApex(this.wiredLineItemsResult);
      })
      .catch((e) => {
        console.error(e);
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: e.body?.message || "Failed to add resource",
            variant: "error"
          })
        );
      });
  }

  handleAddAddon() {
    this.selectedAddonId = "";
    this.addonQuantity = 1;
    this.addonUnitPrice = 0;
    this.isAddonModalOpen = true;
  }
  closeAddonModal() {
    this.isAddonModalOpen = false;
  }
  handleAddonChange(event) {
    this.selectedAddonId = event.detail.value;
    const addon = this.addonsMap.get(this.selectedAddonId);
    if (addon) {
      this.addonUnitPrice = addon.Price__c || 0;
    }
  }
  handleAddonQuantityChange(event) {
    this.addonQuantity = event.target.value;
  }

  handleSaveAddon() {
    if (!this.selectedAddonId) return;
    addLineItem({
      quoteId: this.recordId,
      pricebookEntryId: null,
      product2Id: null,
      quantity: this.addonQuantity,
      unitPrice: this.addonUnitPrice,
      resourceRoleId: null,
      durationHours: null,
      phase: null,
      itemType: "Add-on",
      addonId: this.selectedAddonId
    })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Add-on added",
            variant: "success"
          })
        );
        this.isAddonModalOpen = false;
        return refreshApex(this.wiredLineItemsResult);
      })
      .catch((e) => {
        console.error(e);
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: e.body?.message || "Failed to add add-on",
            variant: "error"
          })
        );
      });
  }

  handleSave(event) {
    const records = event.detail.draftValues.map((draft) => {
      const updateObj = { Id: draft.Id };
      const originalRow = this.lineItems.find((item) => item.Id === draft.Id);

      if (draft.Quantity !== undefined) {
        if (originalRow && originalRow.Item_Type__c === "Labor") {
          updateObj.Duration_Hours__c = draft.Quantity;
          updateObj.Quantity = draft.Quantity;

          if (originalRow.Start_Date__c && this.quoteTimePeriod) {
            let start = new Date(originalRow.Start_Date__c);
            start = new Date(
              start.getTime() + start.getTimezoneOffset() * 60000
            );
            let amount = Number(draft.Quantity);

            // The quantity always strictly determines the months duration for Resources
            start.setMonth(start.getMonth() + amount);

            const year = start.getFullYear();
            const month = String(start.getMonth() + 1).padStart(2, "0");
            const day = String(start.getDate()).padStart(2, "0");
            updateObj.End_Date__c = `${year}-${month}-${day}`;
          }
        } else {
          updateObj.Quantity = draft.Quantity;
        }
      }
      if (draft.UnitPrice !== undefined) updateObj.UnitPrice = draft.UnitPrice;
      if (draft.Discount !== undefined) updateObj.Discount = draft.Discount;

      return updateObj;
    });

    updateLineItems({ items: records })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Line items updated successfully",
            variant: "success"
          })
        );
        this.draftValues = [];
        return refreshApex(this.wiredLineItemsResult);
      })
      .catch((error) => {
        console.error(error);
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: "Failed to update items",
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
        removeLineItem({ lineItemId: row.Id })
          .then(() => {
            this.dispatchEvent(
              new ShowToastEvent({
                title: "Success",
                message: "Item deleted",
                variant: "success"
              })
            );
            return refreshApex(this.wiredLineItemsResult);
          })
          .catch((e) => console.error(e));
        break;
      default:
    }
  }
}

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
import getCurrentUserRole from "@salesforce/apex/TeamController.getCurrentUserRole";
import { refreshApex } from "@salesforce/apex";

const PERIOD_HOURS = {
  Weeks: 40,
  Months: 160,
  Quarters: 480,
  Years: 1920
};

/**
 * @description Component responsible for displaying and managing Quote Line Items.
 * Handles adding, editing, deleting, and organizing items into phases (Products, Resources, Add-ons).
 */
export default class QuoteLineItemsComponent extends LightningElement {
  @api recordId;
  @track lineItems = [];
  wiredLineItemsResult;

  // Phase states
  @track collapsedPhases = {};
  @track isPhaseModalOpen = false;
  @track newPhaseName = "";
  @track isItemPickerOpen = false;
  @track activePhase = "Default";

  // Modal states
  @track isProductModalOpen = false;
  @track isResourceModalOpen = false;
  @track isAddonModalOpen = false;
  @track isSimulatorModalOpen = false;
  @track isSaving = false;

  handleOpenSimulator() {
    this.isSimulatorModalOpen = true;
  }
  handleCloseSimulator() {
    this.isSimulatorModalOpen = false;
  }

  // Quote State
  @track quoteTimePeriod = "Months";
  @track quoteStatus = "Draft";
  @track userRole = "User";

  @wire(getCurrentUserRole)
  wiredUserRole({ data }) {
    if (data) {
      this.userRole = data;
    }
  }

  get isManagerOrAdmin() {
    return this.userRole === "Admin" || this.userRole === "Manager";
  }

  get isLocked() {
    if (this.quoteStatus === "Approved" || this.quoteStatus === "Rejected") {
      return true;
    }
    if (this.quoteStatus === "Pending Approval" && !this.isManagerOrAdmin) {
      return true;
    }
    return false;
  }

  @wire(getQuoteById, { quoteId: "$recordId" })
  wiredQuote({ error, data }) {
    if (data) {
      this.quoteTimePeriod = data.Quote_Time_Period__c || "Months";
      this.quoteStatus = data.Status;
    } else if (error) {
      console.error("Error fetching Quote details", error);
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
      let rowCounter = 1;
      this.lineItems = result.data.map((row) => {
        let baseRate = row.UnitPrice || 0;
        if (row.Item_Type__c === "Labor" || row.Item_Type__c === "Resource") {
          const multiplier = PERIOD_HOURS[this.quoteTimePeriod] || 160;
          baseRate = (row.UnitPrice || 0) / multiplier;
        }

        const startDate = row.Start_Date__c
          ? new Date(row.Start_Date__c + "T00:00:00").toLocaleDateString(
              "en-US",
              {
                day: "2-digit",
                month: "short",
                year: "numeric"
              }
            )
          : "";
        const endDate = row.End_Date__c
          ? new Date(row.End_Date__c + "T00:00:00").toLocaleDateString(
              "en-US",
              {
                day: "2-digit",
                month: "short",
                year: "numeric"
              }
            )
          : "";

        const isResource =
          row.Item_Type__c === "Labor" || row.Item_Type__c === "Resource";
        return {
          ...row,
          rowNum: rowCounter++,
          isResource: isResource,
          Name:
            isResource && row.Resource_Role__r
              ? row.Resource_Role__r.Name
              : row.Item_Type__c === "Add-on" && row.Add_on__r
                ? row.Add_on__r.Name
                : row.Product2
                  ? row.Product2.Name
                  : "Item",
          BaseRateDisplay: baseRate,
          formattedStartDate: startDate,
          formattedEndDate: endDate,
          displayQuantity: row.Quantity != null ? row.Quantity : 0,
          quantityLabel: isResource ? "month(s)" : "item(s)",
          unitPriceLabel: isResource ? "/month" : "",
          calculationLogic: isResource
            ? `Calculated as: Base Rate × ${PERIOD_HOURS[this.quoteTimePeriod] || 160} hours`
            : "Calculated as: Base Rate (1:1)",
          rawDiscount: row.Discount != null ? row.Discount : 0,
          displayDiscount: row.Discount != null ? `${row.Discount}%` : ""
        };
      });
    } else if (result.error) {
      console.error(result.error);
    }
  }

  /* ── Phase Grouping ── */
  get phaseGroups() {
    const groups = {};
    const orderedPhases = [];

    this.lineItems.forEach((item) => {
      const phase = item.Phase__c || "Default";
      if (!groups[phase]) {
        groups[phase] = { phase, items: [], key: `phase-${phase}` };
        orderedPhases.push(phase);
      }
      groups[phase].items.push(item);
    });

    return orderedPhases.map((p) => ({
      ...groups[p],
      isExpanded: !this.collapsedPhases[p]
    }));
  }

  get grandTotal() {
    return this.lineItems.reduce(
      (sum, item) => sum + (item.TotalPrice || 0),
      0
    );
  }

  handleTogglePhase(event) {
    event.stopPropagation();
    const phase = event.currentTarget.dataset.phase;
    this.collapsedPhases = {
      ...this.collapsedPhases,
      [phase]: !this.collapsedPhases[phase]
    };
  }

  handleCollapseAll() {
    const allCollapsed = {};
    this.phaseGroups.forEach((g) => {
      allCollapsed[g.phase] = true;
    });
    // If already all collapsed, expand all
    const allAreCollapsed = this.phaseGroups.every(
      (g) => this.collapsedPhases[g.phase]
    );
    if (allAreCollapsed) {
      this.collapsedPhases = {};
    } else {
      this.collapsedPhases = allCollapsed;
    }
  }

  /* ── Add Phase ── */
  handleAddPhase() {
    this.newPhaseName = "";
    this.isPhaseModalOpen = true;
  }

  closePhaseModal() {
    this.isPhaseModalOpen = false;
  }

  handlePhaseNameChange(event) {
    this.newPhaseName = event.target.value;
  }

  handleCreatePhase() {
    if (!this.newPhaseName || this.newPhaseName.trim().length === 0) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "Please enter a phase name",
          variant: "error"
        })
      );
      return;
    }
    // Phase is created when the first item is added to it
    this.activePhase = this.newPhaseName.trim();
    this.isPhaseModalOpen = false;
    // Show the item picker to add an item to this new phase
    this.isItemPickerOpen = true;
  }

  /* ── Add Item to Phase ── */
  handleAddItemToPhase(event) {
    event.stopPropagation();
    this.activePhase = event.currentTarget.dataset.phase;
    this.isItemPickerOpen = true;
  }

  handleAddItemGlobal() {
    this.activePhase = "Default";
    this.isItemPickerOpen = true;
  }

  closeItemPicker() {
    this.isItemPickerOpen = false;
  }

  handlePickProduct() {
    this.isItemPickerOpen = false;
    this.handleAddProduct();
  }
  handlePickResource() {
    this.isItemPickerOpen = false;
    this.handleAddResource();
  }
  handlePickAddon() {
    this.isItemPickerOpen = false;
    this.handleAddAddon();
  }

  /* ── Delete ── */
  handleDeleteItem(event) {
    const itemId = event.currentTarget.dataset.id;
    removeLineItem({ lineItemId: itemId })
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
  }

  handleItemAction() {
    // Handled by individual menu item clicks
  }

  /* ── Inline Editing ── */
  handleInlineChange(event) {
    const itemId = event.target.dataset.id;
    const field = event.target.dataset.field;
    let value = parseFloat(event.target.value);

    if (isNaN(value)) {
      return;
    }

    const updateObj = { Id: itemId };

    if (field === "BaseRate") {
      // Find the item to check if it's a resource and get multiplier
      const item = this.lineItems.find((i) => i.Id === itemId);
      const isResource =
        item &&
        (item.Item_Type__c === "Labor" || item.Item_Type__c === "Resource");
      const multiplier = isResource
        ? PERIOD_HOURS[this.quoteTimePeriod] || 160
        : 1;

      updateObj.UnitPrice = value * multiplier;
    } else {
      updateObj[field] = value;
    }

    updateLineItems({ items: [updateObj] })
      .then(() => {
        const displayField = field === "BaseRate" ? "Base Rate" : field;
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Updated",
            message: `${displayField} updated successfully`,
            variant: "success"
          })
        );
        return refreshApex(this.wiredLineItemsResult);
      })
      .catch((error) => {
        console.error(error);
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: error.body?.message || "Failed to update",
            variant: "error"
          })
        );
      });
  }

  /* ── Wire data sources ── */
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

  /* ── Product Modal ── */
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

  handleSaveProduct() {
    if (!this.selectedPBEId || this.isSaving) return;
    this.isSaving = true;

    const pbe = this.pricebookMap.get(this.selectedPBEId);
    addLineItem({
      quoteId: this.recordId,
      pricebookEntryId: this.selectedPBEId,
      product2Id: pbe.Product2Id,
      quantity: this.productQuantity,
      unitPrice: this.productUnitPrice,
      resourceRoleId: null,
      durationHours: null,
      phase: this.activePhase,
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
      })
      .finally(() => {
        this.isSaving = false;
      });
  }

  /* ── Resource Modal ── */
  handleAddResource() {
    this.selectedRoleId = "";
    this.standardHours = PERIOD_HOURS[this.quoteTimePeriod] || 160;
    this.resourceQuantity = 1;
    this.resourceUnitPrice = 0;
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

  handleSaveResource() {
    if (!this.selectedRoleId || this.isSaving) {
      if (!this.selectedRoleId) {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: "Please select a resource role",
            variant: "error"
          })
        );
      }
      return;
    }

    this.isSaving = true;
    addLineItem({
      quoteId: this.recordId,
      pricebookEntryId: null,
      product2Id: null,
      quantity: this.resourceQuantity,
      unitPrice: this.resourceUnitPrice,
      resourceRoleId: this.selectedRoleId,
      durationHours: this.standardHours,
      phase: this.activePhase,
      itemType: "Labor",
      addonId: null
    })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Resource Role added",
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
      })
      .finally(() => {
        this.isSaving = false;
      });
  }

  /* ── Add-on Modal ── */
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
    if (!this.selectedAddonId || this.isSaving) return;

    this.isSaving = true;
    addLineItem({
      quoteId: this.recordId,
      pricebookEntryId: null,
      product2Id: null,
      quantity: this.addonQuantity,
      unitPrice: this.addonUnitPrice,
      resourceRoleId: null,
      durationHours: null,
      phase: this.activePhase,
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
      })
      .finally(() => {
        this.isSaving = false;
      });
  }
}

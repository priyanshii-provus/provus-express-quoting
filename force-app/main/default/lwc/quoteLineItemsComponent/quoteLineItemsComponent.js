import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQuoteLineItems from '@salesforce/apex/QuoteService.getQuoteLineItems';
import addLineItem from '@salesforce/apex/QuoteService.addLineItem';
import removeLineItem from '@salesforce/apex/QuoteService.removeLineItem';
import updateLineItems from '@salesforce/apex/QuoteService.updateLineItems';
import getPricebookEntries from '@salesforce/apex/ProductController.getPricebookEntries';
import getResourceRoles from '@salesforce/apex/ResourceRoleController.getResourceRoles';
import getQuoteById from '@salesforce/apex/QuoteService.getQuoteById';
import { refreshApex } from '@salesforce/apex';

const actions = [
    { label: 'Edit', name: 'edit' },
    { label: 'Delete', name: 'delete' },
];

const columns = [
    { label: 'Name', fieldName: 'Name', type: 'text' },
    { label: 'Task', fieldName: 'Phase__c', type: 'text', editable: true },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date-local', typeAttributes: { month: "short", day: "2-digit", year: "numeric", timeZone: "UTC" } },
    { label: 'End Date', fieldName: 'End_Date__c', type: 'date-local', typeAttributes: { month: "short", day: "2-digit", year: "numeric", timeZone: "UTC" } },
    { label: 'Quantity (Months/Items)', fieldName: 'Quantity', type: 'number', typeAttributes: { minimumFractionDigits: 0, maximumFractionDigits: 2 }, editable: true },
    { label: 'Base Rate', fieldName: 'BaseRateDisplay', type: 'currency' },
    { label: 'Unit Price', fieldName: 'UnitPrice', type: 'currency', editable: true },
    { label: 'Discount %', fieldName: 'Discount', type: 'number', editable: true },
    { label: 'Total Price', fieldName: 'TotalPrice', type: 'currency' },
    {
        type: 'action',
        typeAttributes: { rowActions: actions },
    },
];

export default class QuoteLineItemsComponent extends LightningElement {
    @api recordId;
    @track lineItems = [];
    @track draftValues = [];
    columns = columns;
    wiredLineItemsResult;

    // Modal states
    @track isProductModalOpen = false;
    @track isResourceModalOpen = false;
    
    // Quote State
    @track quoteTimePeriod = 'Months';

    @wire(getQuoteById, { quoteId: '$recordId' })
    wiredQuote({ error, data }) {
        if (data) {
            this.quoteTimePeriod = data.Quote_Time_Period__c || 'Months';
        } else if (error) {
            console.error('Error fetching Quote details', error);
        }
    }

    // Product Modal Props
    @track productOptions = [];
    @track selectedPBEId = '';
    @track productQuantity = 1;
    @track productUnitPrice = 0;
    pricebookMap = new Map();

    // Resource Modal Props
    @track resourceOptions = [];
    @track selectedRoleId = '';
    @track resourceQuantity = 1;
    @track resourceUnitPrice = 0;
    @track resourcePhase = '';
    standardHours = 160;
    rolesMap = new Map();

    @wire(getQuoteLineItems, { quoteId: '$recordId' })
    wiredLineItems(result) {
        this.wiredLineItemsResult = result;
        if (result.data) {
            this.lineItems = result.data.map(row => {
                let baseRate = row.UnitPrice || 0;
                if (row.Item_Type__c === 'Labor' || row.Item_Type__c === 'Resource') {
                    // Strictly derive base rate back from the monthly Unit Price (160h)
                    baseRate = (row.UnitPrice || 0) / 160;
                }

                return {
                    ...row,
                    Name: (row.Item_Type__c === 'Labor' || row.Item_Type__c === 'Resource') && row.Resource_Role__r ? row.Resource_Role__r.Name : (row.Product2 ? row.Product2.Name : 'Item'),
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
            this.productOptions = data.map(pbe => {
                this.pricebookMap.set(pbe.Id, pbe);
                return { label: pbe.Product2.Name, value: pbe.Id };
            });
        } else if (error) {
            console.error('Error fetching PricebookEntries', error);
        }
    }

    @wire(getResourceRoles, { activeOnly: true })
    wiredRoles({ data, error }) {
        if (data) {
            this.resourceOptions = data.map(r => {
                this.rolesMap.set(r.Id, r);
                return { label: r.Name, value: r.Id };
            });
        } else if (error) {
            console.error('Error fetching Resource Roles', error);
        }
    }

    get isSaveDisabled() {
        return this.draftValues.length === 0;
    }

    handleAddProduct() {
        this.selectedPBEId = '';
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
    handleProductQuantityChange(event) { this.productQuantity = event.target.value; }
    handleProductPriceChange(event) { this.productUnitPrice = event.target.value; }

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
            itemType: 'Product'
        }).then(() => {
            this.dispatchEvent(new ShowToastEvent({title: 'Success', message: 'Product added', variant: 'success'}));
            this.isProductModalOpen = false;
            return refreshApex(this.wiredLineItemsResult);
        }).catch(e => {
            console.error(e);
            this.dispatchEvent(new ShowToastEvent({title: 'Error', message: e.body?.message || 'Failed to add product', variant: 'error'}));
        });
    }

    handleAddResource() {
        this.selectedRoleId = '';
        
        // Since we are strictly using Months for labor logic (1 month = 160h)
        // Default the quantity (in Months) based on the quote's Time Period
        let defaultQuantity = 1;
        if (this.quoteTimePeriod === 'Quarters') defaultQuantity = 3;
        else if (this.quoteTimePeriod === 'Years') defaultQuantity = 12;
        else if (this.quoteTimePeriod === 'Weeks') defaultQuantity = 0.25;
        
        this.resourceQuantity = defaultQuantity;
        this.standardHours = 160; 
        this.resourceUnitPrice = 0;
        this.resourcePhase = '';
        this.isResourceModalOpen = true;
    }
    closeResourceModal() {
        this.isResourceModalOpen = false;
    }

    handleResourceQuantityChange(event) { this.resourceQuantity = parseFloat(event.target.value); }

    handleResourceChange(event) {
        this.selectedRoleId = event.detail.value;
        const role = this.rolesMap.get(this.selectedRoleId);
        if (role) {
            this.resourceUnitPrice = (role.Price__c || 0) * this.standardHours;
        }
    }
    handleResourcePhaseChange(event) { this.resourcePhase = event.target.value; }

    handleSaveResource() {
        if (!this.selectedRoleId) {
            this.dispatchEvent(new ShowToastEvent({title: 'Error', message: 'Please select a resource role', variant: 'error'}));
            return;
        }
        if (!this.resourceQuantity || isNaN(this.resourceQuantity) || this.resourceQuantity <= 0) {
            this.dispatchEvent(new ShowToastEvent({title: 'Error', message: 'Please enter a valid duration (months)', variant: 'error'}));
            return;
        }
        addLineItem({
            quoteId: this.recordId,
            pricebookEntryId: null,
            product2Id: null,
            quantity: this.resourceQuantity,
            unitPrice: this.resourceUnitPrice,
            resourceRoleId: this.selectedRoleId,
            durationHours: 160,
            phase: this.resourcePhase,
            itemType: 'Labor'
        }).then(() => {
            this.dispatchEvent(new ShowToastEvent({title: 'Success', message: 'Resource added', variant: 'success'}));
            this.isResourceModalOpen = false;
            return refreshApex(this.wiredLineItemsResult);
        }).catch(e => {
            console.error(e);
            this.dispatchEvent(new ShowToastEvent({title: 'Error', message: e.body?.message || 'Failed to add resource', variant: 'error'}));
        });
    }

    handleSave(event) {
        const records = event.detail.draftValues.map(draft => {
            const updateObj = { Id: draft.Id };
            const originalRow = this.lineItems.find(item => item.Id === draft.Id);
            
            if (draft.Quantity !== undefined) {
                if (originalRow && originalRow.Item_Type__c === 'Labor') {
                    updateObj.Duration_Hours__c = draft.Quantity;
                    updateObj.Quantity = draft.Quantity;
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
                this.dispatchEvent(new ShowToastEvent({title: 'Success', message: 'Line items updated successfully', variant: 'success'}));
                this.draftValues = [];
                return refreshApex(this.wiredLineItemsResult);
            })
            .catch(error => {
                console.error(error);
                this.dispatchEvent(new ShowToastEvent({title: 'Error', message: 'Failed to update items', variant: 'error'}));
            });
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        switch (actionName) {
            case 'edit':
                break;
            case 'delete':
                removeLineItem({ lineItemId: row.Id })
                    .then(() => {
                        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Item deleted', variant: 'success' }));
                        return refreshApex(this.wiredLineItemsResult);
                    })
                    .catch(e => console.error(e));
                break;
            default:
        }
    }
}

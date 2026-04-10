import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import TOTAL_COST_FIELD from '@salesforce/schema/Quote.Total_Cost__c';
import SUBTOTAL_FIELD from '@salesforce/schema/Quote.Subtotal';
import DISCOUNT_FIELD from '@salesforce/schema/Quote.Discount';

const FIELDS = [TOTAL_COST_FIELD, SUBTOTAL_FIELD, DISCOUNT_FIELD];

export default class ProfitSimulator extends LightningElement {
    @api recordId;
    
    @track discount = 0;
    quoteData;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredQuote({ error, data }) {
        if (data) {
            this.quoteData = data;
            // If discount is currently 0 (initial state), sync it with the quote's real discount
            if (this.discount === 0) {
                const initialDisc = getFieldValue(data, DISCOUNT_FIELD) || 0;
                this.discount = Math.round(initialDisc);
            }
        } else if (error) {
            console.error('Error loading quote data', error);
        }
    }

    _currentDiscount = 0;
    @api
    get currentDiscount() { return this._currentDiscount; }
    set currentDiscount(val) {
        this._currentDiscount = parseFloat(val) || 0;
        this.discount = Math.round(this._currentDiscount);
    }

    handleDiscountChange(event) {
        this.discount = parseFloat(event.target.value) || 0;
    }

    get costValue() {
        return getFieldValue(this.quoteData, TOTAL_COST_FIELD) || 0;
    }

    get revenueValue() {
        return getFieldValue(this.quoteData, SUBTOTAL_FIELD) || 0;
    }

    get finalRevenue() {
        return this.revenueValue * (1 - (this.discount / 100));
    }

    get netProfit() {
        return this.finalRevenue - this.costValue;
    }

    get marginPercent() {
        if (this.finalRevenue === 0) return 0;
        return ((this.netProfit / this.finalRevenue) * 100);
    }

    get displayMargin() {
        return this.marginPercent.toFixed(1);
    }

    get formattedFinalRevenue() {
        return this.formatCurrency(this.finalRevenue);
    }

    get formattedTotalCost() {
        return this.formatCurrency(this.costValue);
    }

    get formattedNetProfit() {
        return this.formatCurrency(this.netProfit);
    }

    formatCurrency(value) {
        return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(value);
    }

    get gaugeValue() {
        const visualMargin = Math.max(0, Math.min(100, this.marginPercent));
        return `${visualMargin}, 100`;
    }

    get isWarning() {
        return this.marginPercent < 25 && this.marginPercent >= 10;
    }

    get isCritical() {
        return this.marginPercent < 10;
    }

    get isGood() {
        return this.marginPercent >= 25;
    }

    get gaugeColor() {
        if (this.isGood) return '#02C173'; // Green
        if (this.isWarning) return '#FFB75D'; // Yellow
        return '#F56954'; // Red
    }

    get badgeText() {
        if (this.isGood) return 'HEALTHY';
        if (this.isWarning) return 'WARNING';
        return 'CRITICAL';
    }

    get badgeClass() {
        if (this.isGood) return 'g-badge badge-good';
        if (this.isWarning) return 'g-badge badge-warning';
        return 'g-badge badge-critical';
    }
}

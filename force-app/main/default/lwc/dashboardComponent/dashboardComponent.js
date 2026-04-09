import { LightningElement, wire, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getQuoteInsights from "@salesforce/apex/DashboardController.getQuoteInsights";
import getRecentQuotes from "@salesforce/apex/DashboardController.getRecentQuotes";
import Id from "@salesforce/user/Id";
import { getRecord } from "lightning/uiRecordApi";
import NAME_FIELD from "@salesforce/schema/User.Name";

const COLUMNS = [
  { label: "Quote Number", fieldName: "QuoteNumber", type: "text" },
  { label: "Name", fieldName: "Name", type: "text" },
  { label: "Status", fieldName: "Status", type: "text" },
  {
    label: "Total Amount",
    fieldName: "TotalPrice",
    type: "currency",
    typeAttributes: { currencyCode: "USD" }
  },
  {
    label: "Created Date",
    fieldName: "CreatedDate",
    type: "date",
    typeAttributes: {
      year: "numeric",
      month: "short",
      day: "2-digit"
    }
  }
];

export default class DashboardComponent extends NavigationMixin(
  LightningElement
) {
  @track isQuoteModalOpen = false;
  @track insights = {
    awaitingApproval: { count: 0, amount: 0 },
    lowMargin: { count: 0, amount: 0 },
    draftPipeline: { count: 0, amount: 0 },
    highMargin: { count: 0, amount: 0 },
    wonThisMonth: { count: 0, amount: 0 }
  };

  @track recentQuotes = [];
  columns = COLUMNS;
  userId = Id;
  userName = "";

  @track quoteStartDate = null;
  @track quoteEndDate = null;
  @track quoteTimePeriod = "Months";

  get timePeriodOptions() {
    return [
      { label: "Days", value: "Days" },
      { label: "Weeks", value: "Weeks" },
      { label: "Months", value: "Months" },
      { label: "Quarters", value: "Quarters" },
      { label: "Years", value: "Years" }
    ];
  }

  @wire(getRecord, { recordId: "$userId", fields: [NAME_FIELD] })
  wiredUser({ error, data }) {
    if (data) {
      this.userName = data.fields.Name.value;
    } else if (error) {
      console.error(error);
    }
  }

  @wire(getQuoteInsights)
  wiredInsights({ error, data }) {
    if (data) {
      this.insights = data;
    } else if (error) {
      console.error("Error loading insights:", error);
    }
  }

  @wire(getRecentQuotes)
  wiredQuotes({ error, data }) {
    if (data) {
      this.recentQuotes = data;
    } else if (error) {
      console.error("Error loading recent quotes:", error);
    }
  }

  handleCreateQuote() {
    this.isQuoteModalOpen = true;
  }

  handleDateCalcChange(event) {
    const fieldName = event.target.fieldName || event.target.name;
    if (fieldName === "Start_Date__c") {
      this.quoteStartDate = event.target.value;
    } else if (fieldName === "Quote_Time_Period__c") {
      this.quoteTimePeriod = event.target.value;
    }

    if (this.quoteStartDate && this.quoteTimePeriod) {
      let start = new Date(this.quoteStartDate);
      // JS dates parsing can have timezone offset issues, add offset to ensure correct day
      start = new Date(start.getTime() + start.getTimezoneOffset() * 60000);

      if (!isNaN(start.getTime())) {
        let end = new Date(start);
        const period = this.quoteTimePeriod.toLowerCase();
        if (period === "months" || period === "month") {
          end.setMonth(start.getMonth() + 1);
        } else if (period === "quarters" || period === "quarter") {
          end.setMonth(start.getMonth() + 3);
        } else if (period === "years" || period === "year") {
          end.setFullYear(start.getFullYear() + 1);
        } else if (period === "weeks" || period === "week") {
          end.setDate(start.getDate() + 7);
        }

        // Format correctly to YYYY-MM-DD local time
        const year = end.getFullYear();
        const month = String(end.getMonth() + 1).padStart(2, "0");
        const day = String(end.getDate()).padStart(2, "0");
        this.quoteEndDate = `${year}-${month}-${day}`;
      }
    }
  }

  handleQuoteSubmit(event) {
    event.preventDefault();
    const fields = event.detail.fields;
    fields.Quote_Time_Period__c = this.quoteTimePeriod;
    this.template.querySelector("lightning-record-edit-form").submit(fields);
  }

  handleQuoteCreated(event) {
    this.isQuoteModalOpen = false;

    const evt = new ShowToastEvent({
      title: "Success",
      message: "Quote created successfully",
      variant: "success"
    });
    this.dispatchEvent(evt);

    const newQuoteId = event.detail.id;
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: newQuoteId,
        objectApiName: "Quote",
        actionName: "view"
      }
    });
  }

  handleReviewNow() {
    this.navigateToQuotes("Pending Approval");
  }

  handleReviewMargins() {
    this.navigateToQuotes("Draft");
  }

  handleViewDrafts() {
    this.navigateToQuotes("Draft");
  }

  handleViewOpportunities() {
    this.navigateToQuotes(null);
  }

  handleViewWins() {
    this.navigateToQuotes("Approved");
  }

  navigateToQuotes(status) {
    this[NavigationMixin.Navigate]({
      type: "standard__objectPage",
      attributes: {
        objectApiName: "Quote",
        actionName: "list"
      },
      state: {
        filterName: status ? `${status.replace(/\s+/g, "_")}_Quotes` : "Recent"
      }
    });
  }
}

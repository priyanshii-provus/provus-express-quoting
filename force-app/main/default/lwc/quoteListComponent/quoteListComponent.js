import { LightningElement, track, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getQuotes from "@salesforce/apex/QuoteService.getQuotes";
import deleteQuote from "@salesforce/apex/QuoteService.deleteQuote";
import cloneQuote from "@salesforce/apex/QuoteService.cloneQuote";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";

const actions = [
  { label: "View", name: "view" },
  { label: "Edit", name: "edit" },
  { label: "Delete", name: "delete" },
  { label: "Clone", name: "clone" }
];

const columns = [
  {
    label: "Quote Number",
    fieldName: "quoteLink",
    type: "url",
    typeAttributes: { label: { fieldName: "QuoteNumber" }, target: "_blank" }
  },
  { label: "Name", fieldName: "Name" },
  { label: "Status", fieldName: "Status" },
  {
    label: "Total Amount",
    fieldName: "TotalPrice",
    type: "currency",
    typeAttributes: { currencyCode: "INR" }
  },
  {
    type: "action",
    typeAttributes: { rowActions: actions }
  }
];

export default class QuoteListComponent extends NavigationMixin(
  LightningElement
) {
  @track allQuotes = [];
  @track filteredQuotes = [];
  columns = columns;
  searchKey = "";
  statusFilter = "";
  wiredQuotesResult;

  get statusOptions() {
    return [
      { label: "All", value: "" },
      { label: "Draft", value: "Draft" },
      { label: "Pending Approval", value: "Pending Approval" },
      { label: "Approved", value: "Approved" }
    ];
  }

  @wire(getQuotes, { status: "$statusFilter", accountId: null })
  wiredQuotes(result) {
    this.wiredQuotesResult = result;
    if (result.data) {
      // Add navigation URL for each quote
      this.allQuotes = result.data.map((q) => ({
        ...q,
        quoteLink: `/lightning/r/Quote/${q.Id}/view`
      }));
      this.filterQuotes();
    } else if (result.error) {
      console.error("Error fetching quotes: ", result.error);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error Fetching Quotes",
          message: result.error.body
            ? result.error.body.message
            : "Unknown permission error",
          variant: "error"
        })
      );
    }
  }

  handleSearch(event) {
    this.searchKey = event.target.value.toLowerCase();
    this.filterQuotes();
  }

  handleFilterChange(event) {
    this.statusFilter = event.detail.value;
  }

  filterQuotes() {
    if (!this.allQuotes) return;

    let filtered = [...this.allQuotes];

    if (this.searchKey) {
      filtered = filtered.filter(
        (quote) =>
          (quote.Name && quote.Name.toLowerCase().includes(this.searchKey)) ||
          (quote.QuoteNumber &&
            quote.QuoteNumber.toLowerCase().includes(this.searchKey))
      );
    }

    this.filteredQuotes = filtered;
  }

  handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;
    switch (actionName) {
      case "view":
        this[NavigationMixin.Navigate]({
          type: "standard__recordPage",
          attributes: {
            recordId: row.Id,
            objectApiName: "Quote",
            actionName: "view"
          }
        });
        break;
      case "edit":
        this.editRecord(row);
        break;
      case "delete":
        this.deleteRecord(row);
        break;
      case "clone":
        this.cloneRecord(row);
        break;
      default:
    }
  }

  editRecord(row) {
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: row.Id,
        objectApiName: "Quote",
        actionName: "edit"
      }
    });
  }

  deleteRecord(row) {
    deleteQuote({ quoteId: row.Id })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Quote deleted successfully",
            variant: "success"
          })
        );
        return refreshApex(this.wiredQuotesResult);
      })
      .catch((error) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error deleting quote",
            message: error.body.message,
            variant: "error"
          })
        );
      });
  }

  cloneRecord(row) {
    cloneQuote({ quoteId: row.Id })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Quote cloned successfully",
            variant: "success"
          })
        );
        return refreshApex(this.wiredQuotesResult);
      })
      .catch((error) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error cloning quote",
            message: error.body.message,
            variant: "error"
          })
        );
      });
  }


  handleCreateQuote() {
    this.dispatchEvent(
      new CustomEvent("createquote", {
        bubbles: true,
        composed: true
      })
    );
  }
}

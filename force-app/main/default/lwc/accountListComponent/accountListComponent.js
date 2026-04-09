import { LightningElement, track, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getAccounts from "@salesforce/apex/AccountController.getAccounts";
import deleteAccount from "@salesforce/apex/AccountController.deleteAccount";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";

const actions = [
  { label: "Edit", name: "edit" },
  { label: "Delete", name: "delete" }
];

const columns = [
  { label: "Account Name", fieldName: "Name" },
  { label: "Industry", fieldName: "Industry" },
  { label: "Phone", fieldName: "Phone", type: "phone" },
  {
    type: "action",
    typeAttributes: { rowActions: actions }
  }
];

export default class AccountListComponent extends NavigationMixin(
  LightningElement
) {
  @track allAccounts = [];
  @track filteredAccounts = [];
  columns = columns;
  searchKey = "";
  industryFilter = "";
  wiredAccountsResult;

  get industryOptions() {
    return [
      { label: "All", value: "" },
      { label: "Technology", value: "Technology" },
      { label: "Healthcare", value: "Healthcare" },
      { label: "Finance", value: "Finance" }
    ];
  }

  @wire(getAccounts)
  wiredAccounts(result) {
    this.wiredAccountsResult = result;
    if (result.data) {
      this.allAccounts = result.data;
      this.filterAccounts();
    } else if (result.error) {
      console.error("Error fetching accounts: ", result.error);
    }
  }

  handleSearch(event) {
    this.searchKey = event.target.value.toLowerCase();
    this.filterAccounts();
  }

  handleFilterChange(event) {
    this.industryFilter = event.detail.value;
    this.filterAccounts();
  }

  filterAccounts() {
    if (!this.allAccounts) return;

    let filtered = [...this.allAccounts];

    if (this.searchKey) {
      filtered = filtered.filter(
        (acc) => acc.Name && acc.Name.toLowerCase().includes(this.searchKey)
      );
    }

    if (this.industryFilter) {
      filtered = filtered.filter((acc) => acc.Industry === this.industryFilter);
    }

    this.filteredAccounts = filtered;
  }

  handleNewAccount() {
    this[NavigationMixin.Navigate]({
      type: "standard__objectPage",
      attributes: {
        objectApiName: "Account",
        actionName: "new"
      }
    });
  }

  handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;
    switch (actionName) {
      case "edit":
        this[NavigationMixin.Navigate]({
          type: "standard__recordPage",
          attributes: {
            recordId: row.Id,
            objectApiName: "Account",
            actionName: "edit"
          }
        });
        break;
      case "delete":
        deleteAccount({ accountId: row.Id })
          .then(() => {
            this.dispatchEvent(
              new ShowToastEvent({
                title: "Success",
                message: "Account deleted",
                variant: "success"
              })
            );
            return refreshApex(this.wiredAccountsResult);
          })
          .catch((e) => console.error(e));
        break;
      default:
    }
  }

  handleAIAssistant() {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "AI Assistant",
        message: "Opening AI insights for Accounts...",
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

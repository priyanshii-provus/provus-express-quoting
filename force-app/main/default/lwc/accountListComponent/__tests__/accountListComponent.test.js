import { createElement } from "lwc";
import AccountListComponent from "c/accountListComponent";
import getAccounts from "@salesforce/apex/AccountController.getAccounts";
import deleteAccount from "@salesforce/apex/AccountController.deleteAccount";

// Mock Apex wires
jest.mock(
  "@salesforce/apex/AccountController.getAccounts",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

// Mock imperative Apex
jest.mock(
  "@salesforce/apex/AccountController.deleteAccount",
  () => {
    return { default: jest.fn(() => Promise.resolve()) };
  },
  { virtual: true }
);

describe("c-account-list-component", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders account records in a datatable", async () => {
    const element = createElement("c-account-list-component", {
      is: AccountListComponent
    });
    document.body.appendChild(element);

    // Emit mock data
    const mockAccounts = [
      { Id: "1", Name: "Acme Corp", Industry: "Technology", Phone: "123-456" }
    ];
    getAccounts.emit(mockAccounts);

    await Promise.resolve();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).not.toBeNull();
    expect(datatable.data.length).toBe(1);
    expect(datatable.data[0].Name).toBe("Acme Corp");
  });

  it("filters accounts by industry", async () => {
    const element = createElement("c-account-list-component", {
      is: AccountListComponent
    });
    document.body.appendChild(element);

    const mockAccounts = [
      { Id: "1", Name: "Tech Corp", Industry: "Technology" },
      { Id: "2", Name: "Health Corp", Industry: "Healthcare" }
    ];
    getAccounts.emit(mockAccounts);

    await Promise.resolve();

    const combobox = element.shadowRoot.querySelector("lightning-combobox");
    combobox.value = "Healthcare";
    combobox.dispatchEvent(
      new CustomEvent("change", { detail: { value: "Healthcare" } })
    );

    await Promise.resolve();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable.data.length).toBe(1);
    expect(datatable.data[0].Name).toBe("Health Corp");
  });

  it("handles account deletion", async () => {
    const element = createElement("c-account-list-component", {
      is: AccountListComponent
    });
    document.body.appendChild(element);

    const mockAccounts = [{ Id: "1", Name: "Delete Me" }];
    getAccounts.emit(mockAccounts);

    await Promise.resolve();

    // Simulate row action for delete
    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    const row = mockAccounts[0];
    datatable.dispatchEvent(
      new CustomEvent("rowaction", {
        detail: {
          action: { name: "delete" },
          row: row
        }
      })
    );

    await Promise.resolve();

    expect(deleteAccount).toHaveBeenCalledWith({ accountId: "1" });
  });
});

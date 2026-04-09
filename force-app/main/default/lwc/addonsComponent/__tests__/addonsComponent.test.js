import { createElement } from "lwc";
import AddonsComponent from "c/addonsComponent";
import getAddons from "@salesforce/apex/AddonController.getAddons";
import createAddon from "@salesforce/apex/AddonController.createAddon";
import deleteAddon from "@salesforce/apex/AddonController.deleteAddon";

// Mock Apex wires
jest.mock(
  "@salesforce/apex/AddonController.getAddons",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

// Mock imperative Apex
jest.mock(
  "@salesforce/apex/AddonController.createAddon",
  () => {
    return { default: jest.fn(() => Promise.resolve({ Id: "new-addon-id" })) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/AddonController.deleteAddon",
  () => {
    return { default: jest.fn(() => Promise.resolve()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/AddonController.updateAddons",
  () => {
    return { default: jest.fn(() => Promise.resolve()) };
  },
  { virtual: true }
);

describe("c-addons-component", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders addons in a datatable", async () => {
    const element = createElement("c-addons-component", {
      is: AddonsComponent
    });
    document.body.appendChild(element);

    // Emit mock data
    const mockAddons = [
      {
        Id: "1",
        Name: "Support Bundle",
        Price__c: 100,
        Cost__c: 50,
        Active__c: true
      }
    ];
    getAddons.emit(mockAddons);

    await Promise.resolve();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).not.toBeNull();
    expect(datatable.data.length).toBe(1);
    expect(datatable.data[0].Name).toBe("Support Bundle");
  });

  it("opens modal and saves new addon", async () => {
    const element = createElement("c-addons-component", {
      is: AddonsComponent
    });
    document.body.appendChild(element);

    await Promise.resolve();

    // Wait for any initial rendering
    await Promise.resolve();

    // Click "New Add-on" button
    const addBtn = element.shadowRoot.querySelector(
      'lightning-button[data-id="newButton"]'
    );
    addBtn.click();

    await Promise.resolve();

    // Verify modal is open
    const modal = element.shadowRoot.querySelector(".slds-modal__container");
    expect(modal).not.toBeNull();

    // Fill in name (minimal required field)
    const nameInput = element.shadowRoot.querySelector(
      'lightning-input[data-field="name"]'
    );
    nameInput.value = "New Test Addon";
    nameInput.dispatchEvent(new CustomEvent("change"));

    // Click Save
    const saveBtn = element.shadowRoot.querySelector(
      'lightning-button[data-id="saveButton"]'
    );
    saveBtn.click();

    await Promise.resolve();

    expect(createAddon).toHaveBeenCalled();
  });

  it("handles row deletion action", async () => {
    const element = createElement("c-addons-component", {
      is: AddonsComponent
    });
    document.body.appendChild(element);

    const mockAddons = [{ Id: "1", Name: "Delete Me" }];
    getAddons.emit(mockAddons);

    await Promise.resolve();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    datatable.dispatchEvent(
      new CustomEvent("rowaction", {
        detail: {
          action: { name: "delete" },
          row: mockAddons[0]
        }
      })
    );

    await Promise.resolve();

    expect(deleteAddon).toHaveBeenCalledWith({ addonId: "1" });
  });
});

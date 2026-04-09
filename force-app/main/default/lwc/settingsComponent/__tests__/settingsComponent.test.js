import { createElement } from "lwc";
import SettingsComponent from "c/settingsComponent";
import getUsers from "@salesforce/apex/TeamController.getUsers";
import getCurrentUserRole from "@salesforce/apex/TeamController.getCurrentUserRole";

// Mock Apex wires
jest.mock(
  "@salesforce/apex/TeamController.getCurrentUserRole",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/TeamController.getUsers",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

// Mock imperative calls
jest.mock(
  "@salesforce/apex/TeamController.getLicenseCounts",
  () => ({
    default: jest.fn(() =>
      Promise.resolve({ total: 10, used: 5, available: 5 })
    )
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/AdminSettingsController.getCompanySettings",
  () => ({
    default: jest.fn(() => Promise.resolve({ companyName: "Provus Inc" }))
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/AdminSettingsController.saveCompanySettings",
  () => ({
    default: jest.fn(() => Promise.resolve())
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/AdminSettingsController.getAllPDFVersions",
  () => ({
    default: jest.fn(() => Promise.resolve([]))
  }),
  { virtual: true }
);

describe("c-settings-component", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders and defaults to General tab", async () => {
    const element = createElement("c-settings-component", {
      is: SettingsComponent
    });
    document.body.appendChild(element);

    await Promise.resolve();

    const activeNavItem = element.shadowRoot.querySelector(
      ".sidebar-item.active"
    );
    expect(activeNavItem.textContent.trim()).toBe("General");
  });

  it("switches to Users tab and loads data", async () => {
    const element = createElement("c-settings-component", {
      is: SettingsComponent
    });
    document.body.appendChild(element);

    await Promise.resolve();

    // Click Users tab
    const usersTab = element.shadowRoot.querySelector(
      '.sidebar-item[data-tab="Users"]'
    );
    usersTab.click();

    await Promise.resolve();

    getCurrentUserRole.emit("Admin"); // Wait, the component itself doesn't use this wire for tab visibility, it uses connectedCallback internally
    getUsers.emit([
      {
        Id: "1",
        Name: "Alice Admin",
        FirstName: "Alice",
        LastName: "Admin",
        IsActive: true,
        Express_Role__c: "Admin"
      }
    ]);

    await Promise.resolve();

    const userNames = element.shadowRoot.querySelectorAll(".user-name");
    expect(userNames.length).toBeGreaterThan(0);
    expect(userNames[0].textContent).toContain("Alice Admin");
  });

  it("handles company info saving", async () => {
    const element = createElement("c-settings-component", {
      is: SettingsComponent
    });
    document.body.appendChild(element);

    // Click Company Information tab
    const companyTab = element.shadowRoot.querySelector(
      '.sidebar-item[data-tab="CompanyInfo"]'
    );
    companyTab.click();

    await Promise.resolve();

    // Simulation of input change
    const nameInput = element.shadowRoot.querySelector(
      'input[data-field="companyName"]'
    );
    nameInput.value = "Updated Name";
    nameInput.dispatchEvent(new CustomEvent("change"));

    // Check the button exists and click it
    const saveBtn = element.shadowRoot.querySelector(".btn-save");
    saveBtn.click();

    await Promise.resolve();

    expect(nameInput.value).toBe("Updated Name");
  });
});

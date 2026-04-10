import { createElement } from "@lwc/engine-dom";
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
    const usersTab = element.shadowRoot.querySelector('li[data-tab="Users"]');
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

  it("switches to PDF tab", async () => {
    const element = createElement("c-settings-component", {
      is: SettingsComponent
    });
    document.body.appendChild(element);

    await Promise.resolve();

    // Click PDF tab
    const pdfTab = element.shadowRoot.querySelector('li[data-tab="PDF"]');
    pdfTab.click();

    await Promise.resolve();

    // Verify the PDF tab is now active
    const activeTab = element.shadowRoot.querySelector(".sidebar-item.active");
    expect(activeTab).not.toBeNull();
    expect(activeTab.textContent).toContain("PDF");
  });
});

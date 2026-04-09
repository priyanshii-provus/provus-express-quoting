import { createElement } from "lwc";
import AdminSettingsComponent from "c/adminSettingsComponent";
import getUsers from "@salesforce/apex/TeamController.getUsers";

// Mock Apex wires
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
    default: jest.fn(() => Promise.resolve({ companyName: "Provus Global" }))
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

describe("c-admin-settings-component", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders and defaults to Company Info tab", async () => {
    const element = createElement("c-admin-settings-component", {
      is: AdminSettingsComponent
    });
    document.body.appendChild(element);

    await Promise.resolve();

    const activeNavItem = element.shadowRoot.querySelector(
      ".sidebar-item.active"
    );
    expect(activeNavItem.textContent.trim()).toBe("Company Information");
  });

  it("displays company name from settings", async () => {
    const element = createElement("c-admin-settings-component", {
      is: AdminSettingsComponent
    });
    document.body.appendChild(element);

    // Wait for loadCompanySettings in connectedCallback
    await Promise.resolve();
    await Promise.resolve();

    const companyInput = element.shadowRoot.querySelector(
      'input[data-field="companyName"]'
    );
    expect(companyInput).not.toBeNull();
    expect(companyInput.value).toBe("Provus Global");
  });

  it("switches to Team tab and renders users", async () => {
    const element = createElement("c-admin-settings-component", {
      is: AdminSettingsComponent
    });
    document.body.appendChild(element);

    await Promise.resolve();

    // Click Team tab
    const teamTab = element.shadowRoot.querySelector(
      '.sidebar-item[data-tab="Team"]'
    );
    teamTab.click();

    await Promise.resolve();

    // Emit users
    getUsers.emit([
      {
        Id: "1",
        Name: "John Smith",
        FirstName: "John",
        LastName: "Smith",
        IsActive: true,
        Express_Role__c: "User"
      }
    ]);

    await Promise.resolve();

    const userName = element.shadowRoot.querySelector(".user-name");
    expect(userName.textContent).toContain("John Smith");
  });
});

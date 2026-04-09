import { createElement } from "lwc";
import ExpressHomeLayout from "c/expressHomeLayout";
import getOpportunities from "@salesforce/apex/QuoteService.getOpportunities";
import getCurrentUserRole from "@salesforce/apex/TeamController.getCurrentUserRole";

// Mock Apex wires
jest.mock(
  "@salesforce/apex/QuoteService.getOpportunities",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/TeamController.getCurrentUserRole",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

describe("c-express-home-layout", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders sidebar and default dashboard tab", async () => {
    const element = createElement("c-express-home-layout", {
      is: ExpressHomeLayout
    });
    document.body.appendChild(element);

    // Emit roles and opportunities
    getCurrentUserRole.emit("User");
    getOpportunities.emit([{ Id: "1", Name: "Test Opp" }]);

    await Promise.resolve();

    // Verify sidebar exists
    const sidebar = element.shadowRoot.querySelector(".sidebar");
    expect(sidebar).not.toBeNull();

    // Default tab should be Dashboard
    const dashboardComponent = element.shadowRoot.querySelector(
      "c-dashboard-component"
    );
    expect(dashboardComponent).not.toBeNull();
  });

  it("switches tabs when sidebar items are clicked", async () => {
    const element = createElement("c-express-home-layout", {
      is: ExpressHomeLayout
    });
    document.body.appendChild(element);

    getCurrentUserRole.emit("User");
    getOpportunities.emit([]);

    await Promise.resolve();

    // Click on Quotes nav item
    const quotesNavItem = element.shadowRoot.querySelector(
      'a[data-target="Quotes"]'
    );
    quotesNavItem.click();

    await Promise.resolve();

    // Verify Quotes component is rendered
    const quoteListComponent = element.shadowRoot.querySelector(
      "c-quote-list-component"
    );
    expect(quoteListComponent).not.toBeNull();

    // Verify Dashboard component is NOT rendered
    const dashboardComponent = element.shadowRoot.querySelector(
      "c-dashboard-component"
    );
    expect(dashboardComponent).toBeNull();
  });

  it("shows settings tab only for admin users", async () => {
    const element = createElement("c-express-home-layout", {
      is: ExpressHomeLayout
    });
    document.body.appendChild(element);

    // Emit non-admin role
    getCurrentUserRole.emit("User");

    await Promise.resolve();

    // Settings nav item should NOT exist
    let settingsNavItem = element.shadowRoot.querySelector(
      'a[data-target="Settings"]'
    );
    expect(settingsNavItem).toBeNull();

    // Emit admin role
    getCurrentUserRole.emit("Admin");

    await Promise.resolve();

    // Settings nav item SHOULD exist
    settingsNavItem = element.shadowRoot.querySelector(
      'a[data-target="Settings"]'
    );
    expect(settingsNavItem).not.toBeNull();
  });
});

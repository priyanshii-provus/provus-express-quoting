import { createElement } from "lwc";
import DashboardComponent from "c/dashboardComponent";
import getQuoteInsights from "@salesforce/apex/DashboardController.getQuoteInsights";
import getRecentQuotes from "@salesforce/apex/DashboardController.getRecentQuotes";

// Mock Apex wires
jest.mock(
  "@salesforce/apex/DashboardController.getQuoteInsights",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/DashboardController.getRecentQuotes",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

// Mock getRecord wire
jest.mock(
  "lightning/uiRecordApi",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { getRecord: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

describe("c-dashboard-component", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders dashboard with insights and recent quotes", async () => {
    const element = createElement("c-dashboard-component", {
      is: DashboardComponent
    });
    document.body.appendChild(element);

    // Emit mock insights
    getQuoteInsights.emit({
      awaitingApproval: { count: 5, amount: 50000 },
      lowMargin: { count: 2, amount: 10000 },
      draftPipeline: { count: 10, amount: 100000 },
      highMargin: { count: 3, amount: 75000 },
      wonThisMonth: { count: 4, amount: 40000 }
    });

    // Emit mock recent quotes
    getRecentQuotes.emit([
      {
        Id: "1",
        QuoteNumber: "Q-001",
        Name: "Test Quote",
        Status: "Draft",
        TotalPrice: 1000
      }
    ]);

    await Promise.resolve();

    // Check for insight card rendering
    const insightTitles = element.shadowRoot.querySelectorAll(".insight-card");
    expect(insightTitles.length).toBeGreaterThan(0);

    // Check for datatable rendering
    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).not.toBeNull();
  });

  it("calculates end date correctly when start date and period change", async () => {
    const element = createElement("c-dashboard-component", {
      is: DashboardComponent
    });
    document.body.appendChild(element);

    await Promise.resolve();

    // Manually trigger the modal open to access the form
    element.shadowRoot.querySelector(".create-quote-btn").click();

    await Promise.resolve();

    // Simulate start date change
    const startDateInput = element.shadowRoot.querySelector(
      'lightning-input-field[data-id="startDate"]'
    );
    startDateInput.value = "2026-01-01";
    startDateInput.dispatchEvent(
      new CustomEvent("change", { detail: { value: "2026-01-01" } })
    );

    // Simulate period change to 'Months'
    const periodInput = element.shadowRoot.querySelector(
      'lightning-combobox[data-id="timePeriod"]'
    );
    periodInput.value = "Months";
    periodInput.dispatchEvent(
      new CustomEvent("change", { detail: { value: "Months" } })
    );

    await Promise.resolve();

    const endDateInput = element.shadowRoot.querySelector(
      'lightning-input-field[data-id="endDate"]'
    );
    expect(endDateInput.value).toBe("2026-02-01");
  });
});

import { createElement } from "@lwc/engine-dom";
import QuoteDetailComponent from "c/quoteDetailComponent";
import getQuoteById from "@salesforce/apex/QuoteService.getQuoteById";

jest.mock(
  "@salesforce/apex/QuoteService.getQuoteById",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return {
      default: createApexTestWireAdapter(jest.fn())
    };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/QuotePDFController.getPDFVersions",
  () => {
    return { default: jest.fn(() => Promise.resolve([])) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/QuoteApprovalController.getApprovalHistory",
  () => {
    return { default: jest.fn(() => Promise.resolve([])) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/QuoteService.getQuoteLineItems",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return {
      default: createApexTestWireAdapter(jest.fn())
    };
  },
  { virtual: true }
);

describe("c-quote-detail-component", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders quote details upon receiving wired data", async () => {
    const element = createElement("c-quote-detail-component", {
      is: QuoteDetailComponent
    });
    element.recordId = "0Q01234567890abcde";
    document.body.appendChild(element);

    // Emit mock Quote
    getQuoteById.emit({
      Id: "0Q01234567890abcde",
      QuoteNumber: "Q-00001",
      Name: "Test Detail Quote",
      Status: "Draft",
      TotalPrice: 5000,
      Subtotal: 5000,
      Margin_Percentage__c: 10,
      Discount_Amount__c: 0,
      Opportunity: { Name: "Test Opp" },
      CreatedBy: { Name: "Test User" }
    });

    await Promise.resolve();

    // Verify elements rendered
    const breadcrumbCurrent = element.shadowRoot.querySelector(
      ".breadcrumb-current"
    );
    expect(breadcrumbCurrent).not.toBeNull();
    expect(breadcrumbCurrent.textContent).toBe("Q-00001");

    const statusBadge = element.shadowRoot.querySelector(".status-Draft");
    expect(statusBadge).not.toBeNull();
    expect(statusBadge.textContent).toBe("Draft");
  });

  it("handles tab switches correctly", async () => {
    const element = createElement("c-quote-detail-component", {
      is: QuoteDetailComponent
    });
    element.recordId = "0Q01234567890abcde";
    document.body.appendChild(element);

    getQuoteById.emit({
      Id: "0Q01234567890abcde",
      QuoteNumber: "Q-00001"
    });

    await Promise.resolve();

    // Should start on Summary tab
    let activeTabBtn = element.shadowRoot.querySelector(
      ".tab-nav button.active"
    );
    expect(activeTabBtn.dataset.id).toBe("summary");

    // Click Line Items tab
    const lineItemsBtn = element.shadowRoot.querySelector(
      'button[data-id="line-items"]'
    );
    lineItemsBtn.click();

    await Promise.resolve();

    activeTabBtn = element.shadowRoot.querySelector(".tab-nav button.active");
    expect(activeTabBtn.dataset.id).toBe("line-items");

    // Assert c-quote-line-items-component is rendered
    const lineItemsComponent = element.shadowRoot.querySelector(
      "c-quote-line-items-component"
    );
    expect(lineItemsComponent).not.toBeNull();
  });
});

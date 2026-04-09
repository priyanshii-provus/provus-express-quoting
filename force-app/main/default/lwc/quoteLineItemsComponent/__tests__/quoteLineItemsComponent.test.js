import { createElement } from "lwc";
import QuoteLineItemsComponent from "c/quoteLineItemsComponent";
import getQuoteById from "@salesforce/apex/QuoteService.getQuoteById";
import getQuoteLineItems from "@salesforce/apex/QuoteService.getQuoteLineItems";

// Mock apex wires
jest.mock(
  "@salesforce/apex/QuoteService.getQuoteById",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/QuoteService.getQuoteLineItems",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

describe("c-quote-line-items-component", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders line items in datatable", async () => {
    const element = createElement("c-quote-line-items-component", {
      is: QuoteLineItemsComponent
    });
    document.body.appendChild(element);

    // Emit line item data
    getQuoteLineItems.emit([
      {
        Id: "1",
        Item_Type__c: "Product",
        Product2: { Name: "Test Product" },
        Quantity: 1,
        UnitPrice: 100,
        TotalPrice: 100
      }
    ]);

    await Promise.resolve();

    const itemRows = element.shadowRoot.querySelectorAll(".item-row");
    expect(itemRows.length).toBe(1);

    const nameCell = element.shadowRoot.querySelector(".item-name");
    expect(nameCell.textContent).toBe("Test Product");
  });

  it("hides edit buttons if quote is approved", async () => {
    const element = createElement("c-quote-line-items-component", {
      is: QuoteLineItemsComponent
    });
    document.body.appendChild(element);

    // Emit approved status
    getQuoteById.emit({ Status: "Approved" });

    await Promise.resolve();

    // The "Add Product", "Add Resource" buttons should NOT be present
    const buttons = element.shadowRoot.querySelectorAll("lightning-button");

    let foundAddButton = false;
    buttons.forEach((btn) => {
      if (btn.label === "Add Product" || btn.label === "Add Resource") {
        foundAddButton = true;
      }
    });

    expect(foundAddButton).toBe(false);
  });
});

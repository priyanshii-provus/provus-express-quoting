import { createElement } from "@lwc/engine-dom";
import QuoteListComponent from "c/quoteListComponent";
import getQuotes from "@salesforce/apex/QuoteService.getQuotes";

// Mocking imperative Apex method call
jest.mock(
  "@salesforce/apex/QuoteService.getQuotes",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return {
      default: createApexTestWireAdapter(jest.fn())
    };
  },
  { virtual: true }
);

describe("c-quote-list-component", () => {
  afterEach(() => {
    // The jsdom instance is shared across test cases in a single file so reset the DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders data table when quotes are returned", async () => {
    const element = createElement("c-quote-list-component", {
      is: QuoteListComponent
    });
    document.body.appendChild(element);

    // Emit mock data
    const mockQuotes = [
      {
        Id: "0Q01234567890abcde",
        QuoteNumber: "00000001",
        Name: "Test Quote 1",
        Status: "Draft",
        TotalPrice: 1000
      }
    ];
    getQuotes.emit(mockQuotes);

    // Wait for any asynchronous DOM updates
    await Promise.resolve();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).not.toBeNull();
    expect(datatable.data.length).toBe(1);
    expect(datatable.data[0].Name).toBe("Test Quote 1");
  });

  it("filters quotes based on search key", async () => {
    const element = createElement("c-quote-list-component", {
      is: QuoteListComponent
    });
    document.body.appendChild(element);

    const mockQuotes = [
      { Id: "1", Name: "Alpha Quote", QuoteNumber: "Q-01" },
      { Id: "2", Name: "Beta Quote", QuoteNumber: "Q-02" }
    ];
    getQuotes.emit(mockQuotes);

    await Promise.resolve();

    const searchInput = element.shadowRoot.querySelector("lightning-input");
    searchInput.value = "alpha";
    searchInput.dispatchEvent(new CustomEvent("change"));

    await Promise.resolve();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable.data.length).toBe(1);
    expect(datatable.data[0].Name).toBe("Alpha Quote");
  });
});

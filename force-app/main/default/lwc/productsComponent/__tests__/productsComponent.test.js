import { createElement } from "lwc";
import ProductsComponent from "c/productsComponent";
import getProducts from "@salesforce/apex/ProductController.getProducts";
import createProduct from "@salesforce/apex/ProductController.createProduct";
import deleteProduct from "@salesforce/apex/ProductController.deleteProduct";

// Mock Apex wires
jest.mock(
  "@salesforce/apex/ProductController.getProducts",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

// Mock imperative Apex
jest.mock(
  "@salesforce/apex/ProductController.createProduct",
  () => {
    return { default: jest.fn(() => Promise.resolve({ Id: "new-prod-id" })) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/ProductController.deleteProduct",
  () => {
    return { default: jest.fn(() => Promise.resolve()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/ProductController.updateProducts",
  () => {
    return { default: jest.fn(() => Promise.resolve()) };
  },
  { virtual: true }
);

describe("c-products-component", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders products in a datatable", async () => {
    const element = createElement("c-products-component", {
      is: ProductsComponent
    });
    document.body.appendChild(element);

    // Emit mock data
    const mockProducts = [
      {
        Id: "1",
        Name: "Product Alpha",
        ProductCode: "PA-001",
        Family: "Software",
        IsActive: true
      }
    ];
    getProducts.emit(mockProducts);

    await Promise.resolve();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).not.toBeNull();
    expect(datatable.data.length).toBe(1);
    expect(datatable.data[0].Name).toBe("Product Alpha");
  });

  it("handles product creation flow", async () => {
    const element = createElement("c-products-component", {
      is: ProductsComponent
    });
    document.body.appendChild(element);

    await Promise.resolve();

    // Wait for any initial rendering
    await Promise.resolve();

    // Click "New Product" button
    const addBtn = element.shadowRoot.querySelector(
      'lightning-button[data-id="newButton"]'
    );
    addBtn.click();

    await Promise.resolve();

    // Check modal
    const modal = element.shadowRoot.querySelector(".slds-modal__container");
    expect(modal).not.toBeNull();

    // Simulate name input
    const nameInput = element.shadowRoot.querySelector(
      'lightning-input[data-field="name"]'
    );
    nameInput.value = "New Test Product";
    nameInput.dispatchEvent(new CustomEvent("change"));

    // Click save
    const saveBtn = element.shadowRoot.querySelector(
      'lightning-button[data-id="saveButton"]'
    );
    saveBtn.click();

    await Promise.resolve();

    expect(createProduct).toHaveBeenCalled();
  });

  it("handles row action - delete", async () => {
    const element = createElement("c-products-component", {
      is: ProductsComponent
    });
    document.body.appendChild(element);

    const mockProducts = [{ Id: "1", Name: "Trash Product" }];
    getProducts.emit(mockProducts);

    await Promise.resolve();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    datatable.dispatchEvent(
      new CustomEvent("rowaction", {
        detail: {
          action: { name: "delete" },
          row: mockProducts[0]
        }
      })
    );

    await Promise.resolve();

    expect(deleteProduct).toHaveBeenCalledWith({ productId: "1" });
  });
});

import { createElement } from "@lwc/engine-dom";
import ResourceRolesComponent from "c/resourceRolesComponent";
import getResourceRoles from "@salesforce/apex/ResourceRoleController.getResourceRoles";
import createResourceRole from "@salesforce/apex/ResourceRoleController.createResourceRole";
import deleteResourceRole from "@salesforce/apex/ResourceRoleController.deleteResourceRole";

// Mock Apex wires
jest.mock(
  "@salesforce/apex/ResourceRoleController.getResourceRoles",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

// Mock imperative Apex
jest.mock(
  "@salesforce/apex/ResourceRoleController.createResourceRole",
  () => {
    return { default: jest.fn(() => Promise.resolve({ Id: "new-role-id" })) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/ResourceRoleController.deleteResourceRole",
  () => {
    return { default: jest.fn(() => Promise.resolve()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/ResourceRoleController.updateResourceRoles",
  () => {
    return { default: jest.fn(() => Promise.resolve()) };
  },
  { virtual: true }
);

describe("c-resource-roles-component", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders resource roles in a datatable", async () => {
    const element = createElement("c-resource-roles-component", {
      is: ResourceRolesComponent
    });
    document.body.appendChild(element);

    // Emit mock data
    const mockRoles = [
      {
        Id: "1",
        Name: "Architect",
        Price__c: 250,
        Cost__c: 150,
        Active__c: true,
        Location__c: "Remote"
      }
    ];
    getResourceRoles.emit(mockRoles);

    await Promise.resolve();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).not.toBeNull();
    expect(datatable.data.length).toBe(1);
    expect(datatable.data[0].Name).toBe("Architect");
  });

  it("opens modal and creates new resource role", async () => {
    const element = createElement("c-resource-roles-component", {
      is: ResourceRolesComponent
    });
    document.body.appendChild(element);

    await Promise.resolve();

    // Wait for any initial rendering
    await Promise.resolve();

    // Click "New Resource Role" button (native <button> with class .new-role-btn)
    const addBtn = element.shadowRoot.querySelector("button.new-role-btn");
    addBtn.click();

    await Promise.resolve();

    // Modal should be visible
    const modal = element.shadowRoot.querySelector(".slds-modal__container");
    expect(modal).not.toBeNull();

    // Simulate name input
    const nameInput = element.shadowRoot.querySelector(
      'lightning-input[data-field="name"]'
    );
    nameInput.value = "New Senior Role";
    nameInput.dispatchEvent(new CustomEvent("change"));

    // Click Save
    const saveBtn = element.shadowRoot.querySelector(
      'lightning-button[data-id="saveButton"]'
    );
    saveBtn.click();

    await Promise.resolve();

    expect(createResourceRole).toHaveBeenCalled();
  });

  it("handles delete action on row", async () => {
    const element = createElement("c-resource-roles-component", {
      is: ResourceRolesComponent
    });
    document.body.appendChild(element);

    const mockRoles = [{ Id: "1", Name: "Temp Role" }];
    getResourceRoles.emit(mockRoles);

    await Promise.resolve();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    datatable.dispatchEvent(
      new CustomEvent("rowaction", {
        detail: {
          action: { name: "delete" },
          row: mockRoles[0]
        }
      })
    );

    await Promise.resolve();

    expect(deleteResourceRole).toHaveBeenCalledWith({ roleId: "1" });
  });
});

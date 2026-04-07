import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProducts from '@salesforce/apex/ProductController.getProducts';
import createProduct from '@salesforce/apex/ProductController.createProduct';
import deleteProduct from '@salesforce/apex/ProductController.deleteProduct';
import updateProducts from '@salesforce/apex/ProductController.updateProducts';
import { refreshApex } from '@salesforce/apex';

const actions = [
    { label: 'Edit', name: 'edit' },
    { label: 'Delete', name: 'delete' },
];

const columns = [
    { label: 'Product Name', fieldName: 'Name', editable: true },
    { label: 'Product Code', fieldName: 'ProductCode', editable: true },
    { label: 'Family', fieldName: 'Family', editable: true },
    { label: 'Active', fieldName: 'IsActive', type: 'boolean', editable: true },
    {
        type: 'action',
        typeAttributes: { rowActions: actions },
    },
];

export default class ProductsComponent extends LightningElement {
    @track products = [];
    @track draftValues = [];
    @track isModalOpen = false;
    @track newProduct = { name: '', productCode: '', description: '', family: '' };
    columns = columns;
    wiredProductsResult;

    get familyOptions() {
        return [
            { label: 'None', value: '' },
            { label: 'Software', value: 'Software' },
            { label: 'Hardware', value: 'Hardware' },
            { label: 'Service', value: 'Service' },
        ];
    }

    @wire(getProducts, { activeOnly: false })
    wiredProducts(result) {
        this.wiredProductsResult = result;
        if (result.data) {
            this.products = result.data;
        } else if (result.error) {
            console.error('Error fetching products:', result.error);
        }
    }

    handleNewProduct() {
        this.newProduct = { name: '', productCode: '', description: '', family: '' };
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleModalFieldChange(event) {
        const field = event.target.dataset.field;
        if (field) {
            this.newProduct = { ...this.newProduct, [field]: event.target.value };
        }
    }

    handleModalFamilyChange(event) {
        this.newProduct = { ...this.newProduct, family: event.detail.value };
    }

    handleSaveNewProduct() {
        if (!this.newProduct.name) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Product Name is required', variant: 'error' }));
            return;
        }
        createProduct({
            name: this.newProduct.name,
            productCode: this.newProduct.productCode,
            description: this.newProduct.description,
            family: this.newProduct.family
        })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Product created', variant: 'success' }));
                this.isModalOpen = false;
                return refreshApex(this.wiredProductsResult);
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: error.body?.message || 'Error creating product', variant: 'error' }));
            });
    }

    handleSave(event) {
        this.draftValues = event.detail.draftValues;
        const records = this.draftValues.slice().map(draft => {
            return { ...draft };
        });

        updateProducts({ products: records })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Products updated', variant: 'success' }));
                this.draftValues = [];
                return refreshApex(this.wiredProductsResult);
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: error.body?.message || 'Error updating products', variant: 'error' }));
            });
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        switch (actionName) {
            case 'edit':
                break;
            case 'delete':
                deleteProduct({ productId: row.Id })
                    .then(() => {
                        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Product deleted', variant: 'success' }));
                        return refreshApex(this.wiredProductsResult);
                    })
                    .catch(error => {
                        console.error('Error deleting product', error);
                    });
                break;
            default:
        }
    }
}

import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCurrentUserRole from '@salesforce/apex/TeamController.getCurrentUserRole';

const MAIN_TABS = ['Dashboard', 'Quotes', 'Accounts', 'Resource Roles', 'Products', 'Add-ons', 'Settings'];

export default class ExpressHomeLayout extends NavigationMixin(LightningElement) {
    @track selectedTab = 'Dashboard';
    @track isQuoteModalOpen = false;
    @track isCreateQuoteModalOpen = false;
    @track currentUserRole = 'User';

    @wire(getCurrentUserRole)
    wiredRole({ data }) {
        if (data) {
            this.currentUserRole = data;
        }
    }

    get isAdmin() { return this.currentUserRole === 'Admin'; }

    /* ── Content visibility getters ─── */
    get isDashboard()     { return this.selectedTab === 'Dashboard'; }
    get isQuotes()        { return this.selectedTab === 'Quotes'; }
    get isAccounts()      { return this.selectedTab === 'Accounts'; }
    get isResourceRoles() { return this.selectedTab === 'Resource Roles'; }
    get isProducts()      { return this.selectedTab === 'Products'; }
    get isAddons()        { return this.selectedTab === 'Add-ons'; }
    get isAIAssistant()   { return this.selectedTab === 'AI Assistant'; }
    get isSettings()      { return this.selectedTab === 'Settings'; }

    /** True when the selected tab has no built component to render */
    get isPlaceholder() {
        return !MAIN_TABS.includes(this.selectedTab);
    }

    /* ── Navigation handler ─────────── */
    handleNavSelection(event) {
        event.preventDefault();
        const navItem = event.currentTarget.dataset.target;
        if (navItem) {
            this.selectedTab = navItem;
        }
    }

    /* ── Create Quote ───────────────── */
    handleCreateQuote() {
        this.isCreateQuoteModalOpen = true;
    }

    closeCreateQuoteModal() {
        this.isCreateQuoteModalOpen = false;
    }

    handleQuoteCreated(event) {
        this.isCreateQuoteModalOpen = false;
        
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Quote created successfully',
                variant: 'success'
            })
        );
        
        // Navigate to the newly created Quote record page
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.detail.id,
                objectApiName: 'Quote',
                actionName: 'view'
            }
        });
    }

    /* ── Active-class getters ───────── */
    get dashboardClass()     { return this._cls('Dashboard'); }
    get quotesClass()        { return this._cls('Quotes'); }
    get accountsClass()      { return this._cls('Accounts'); }
    get resourceRolesClass() { return this._cls('Resource Roles'); }
    get productsClass()      { return this._cls('Products'); }
    get addonsClass()        { return this._cls('Add-ons'); }
    get aiAssistantClass()   { return this._cls('AI Assistant'); }
    get settingsClass()      { return this._cls('Settings'); }

    /* ── Icon Variant getters ───────── */
    get dashboardVariant()     { return this._var('Dashboard'); }
    get quotesVariant()        { return this._var('Quotes'); }
    get accountsVariant()      { return this._var('Accounts'); }
    get resourceRolesVariant() { return this._var('Resource Roles'); }
    get productsVariant()      { return this._var('Products'); }
    get addonsVariant()        { return this._var('Add-ons'); }
    get aiAssistantVariant()   { return this._var('AI Assistant'); }
    get settingsVariant()      { return this._var('Settings'); }

    _cls(tab) {
        return this.selectedTab === tab ? 'nav-item active' : 'nav-item';
    }

    _var(tab) {
        // 'inverse' renders utility icons as white
        return this.selectedTab === tab ? 'inverse' : '';
    }
}

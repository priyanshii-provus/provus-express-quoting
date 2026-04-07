import { LightningElement, track, wire } from 'lwc';
import getUsers from '@salesforce/apex/TeamController.getUsers';
import updateUserDetails from '@salesforce/apex/TeamController.updateUserDetails';
import createUserDetails from '@salesforce/apex/TeamController.createUserDetails';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

const ACTIONS = [
    { label: 'Edit', name: 'edit' },
    { label: 'Remove Access', name: 'remove_access', disabled: true },
    { label: 'Deactivate', name: 'deactivate', disabled: true }
];

const COLUMNS = [
    { label: 'Name', fieldName: 'Name', type: 'text' },
    { label: 'Email', fieldName: 'Email', type: 'email' },
    {
        label: 'Role',
        fieldName: 'Express_Role__c',
        type: 'text',
        cellAttributes: {
            class: { fieldName: 'roleColorClass' }
        }
    },
    { label: 'Status', fieldName: 'StatusLabel', type: 'text' },
    {
        label: 'Last Active',
        fieldName: 'LastLoginDate',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }
    },
    {
        type: 'action',
        typeAttributes: { rowActions: ACTIONS }
    }
];

export default class SettingsComponent extends LightningElement {
    @track users = [];
    @track error;
    columns = COLUMNS;

    @track totalSeats = 20;
    @track usedSeats = 0;
    @track availableSeats = 20;

    wiredUsersResult;

    @track isEditModalOpen = false;
    @track selectedUser = {};
    @track selectedRole = 'User';

    @wire(getUsers)
    wiredUsers(result) {
        this.wiredUsersResult = result;
        if (result.data) {
            this.users = result.data.map((user) => {
                const role = user.Express_Role__c || 'User';
                return {
                    ...user,
                    Express_Role__c: role,
                    roleColorClass:
                        role === 'Admin'
                            ? 'slds-text-color_error'
                            : role === 'Manager'
                              ? 'slds-text-color_weak'
                              : 'slds-text-color_success',
                    StatusLabel: user.IsActive ? '● Active' : '○ Inactive'
                };
            });
            this.usedSeats = this.users.length;
            this.availableSeats = Math.max(0, this.totalSeats - this.usedSeats);
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error.body
                ? result.error.body.message
                : result.error.message;
            this.users = [];
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'edit') {
            this.selectedUser = { ...row };
            this.selectedRole = this.selectedUser.Express_Role__c || 'User';
            this.isEditModalOpen = true;
        }
    }

    handleAddMember() {
        this.selectedUser = { FirstName: '', LastName: '', Email: '', Username: '' };
        this.selectedRole = 'User';
        this.isEditModalOpen = true;
    }

    closeEditModal() {
        this.isEditModalOpen = false;
        this.selectedUser = {};
        this.selectedRole = 'User';
    }
    
    get isUpdatingUser() {
        return !!this.selectedUser?.Id;
    }

    get modalTitle() {
        return this.isUpdatingUser ? 'Edit Team Member' : 'Add Team Member';
    }

    get modalButtonLabel() {
        return this.isUpdatingUser ? 'Update' : 'Create';
    }

    handleInputChange(event) {
        const fieldName = event.target.name;
        this.selectedUser[fieldName] = event.target.value;
    }

    get isRoleAdmin() {
        return this.selectedRole === 'Admin';
    }
    get isRoleManager() {
        return this.selectedRole === 'Manager';
    }
    get isRoleUser() {
        return this.selectedRole === 'User';
    }

    get adminOptionClass() {
        return `role-option slds-box slds-m-bottom_small slds-grid slds-grid_vertical-align-center${this.isRoleAdmin ? ' role-option_selected' : ''}`;
    }
    get managerOptionClass() {
        return `role-option slds-box slds-m-bottom_small slds-grid slds-grid_vertical-align-center${this.isRoleManager ? ' role-option_selected' : ''}`;
    }
    get userOptionClass() {
        return `role-option slds-box slds-m-bottom_small slds-grid slds-grid_vertical-align-center${this.isRoleUser ? ' role-option_selected' : ''}`;
    }

    selectAdminRole() {
        this.selectedRole = 'Admin';
    }
    selectManagerRole() {
        this.selectedRole = 'Manager';
    }
    selectUserRole() {
        this.selectedRole = 'User';
    }

    handleUpdateRole() {
        if (!this.selectedUser) {
            return;
        }

        if (this.isUpdatingUser) {
            updateUserDetails({
                userId: this.selectedUser.Id,
                newRole: this.selectedRole,
                firstName: this.selectedUser.FirstName,
                lastName: this.selectedUser.LastName,
                email: this.selectedUser.Email
            })
                .then(() => {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: `Updated team member successfully`,
                            variant: 'success'
                        })
                    );
                    this.closeEditModal();
                    return refreshApex(this.wiredUsersResult);
                })
                .catch((error) => {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error updating member',
                            message: error.body ? error.body.message : error.message,
                            variant: 'error'
                        })
                    );
                });
        } else {
            createUserDetails({
                newRole: this.selectedRole,
                firstName: this.selectedUser.FirstName,
                lastName: this.selectedUser.LastName,
                email: this.selectedUser.Email,
                username: this.selectedUser.Username
            })
                .then(() => {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: `Created team member successfully`,
                            variant: 'success'
                        })
                    );
                    this.closeEditModal();
                    return refreshApex(this.wiredUsersResult);
                })
                .catch((error) => {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error creating member',
                            message: error.body ? error.body.message : error.message,
                            variant: 'error'
                        })
                    );
                });
        }
    }
}

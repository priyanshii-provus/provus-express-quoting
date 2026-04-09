import { LightningElement, track, wire } from "lwc";
import getUsers from "@salesforce/apex/TeamController.getUsers";
import getLicenseCounts from "@salesforce/apex/TeamController.getLicenseCounts";
import updateUserDetails from "@salesforce/apex/TeamController.updateUserDetails";
import createUserDetails from "@salesforce/apex/TeamController.createUserDetails";
import deactivateUser from "@salesforce/apex/TeamController.deactivateUser";
import resendSetupEmail from "@salesforce/apex/TeamController.resendSetupEmail";
import getCompanySettings from "@salesforce/apex/AdminSettingsController.getCompanySettings";
import saveCompanySettings from "@salesforce/apex/AdminSettingsController.saveCompanySettings";
import getAllPDFVersions from "@salesforce/apex/AdminSettingsController.getAllPDFVersions";
import deletePDFVersion from "@salesforce/apex/QuotePDFController.deletePDFVersion";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";

const AVATAR_COLORS = [
  "#1B74E4",
  "#E44D26",
  "#9C27B0",
  "#009688",
  "#FF5722",
  "#607D8B",
  "#795548",
  "#F44336",
  "#2196F3",
  "#4CAF50",
  "#FF9800",
  "#00BCD4"
];

function getRelativeTime(dateStr) {
  if (!dateStr) return "Never";
  const diffMs = new Date() - new Date(dateStr);
  const diffMin = Math.floor(diffMs / 60000);
  if (diffMin < 1) return "Just now";
  if (diffMin < 60) return `${diffMin} minute${diffMin !== 1 ? "s" : ""} ago`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `${diffHr} hour${diffHr !== 1 ? "s" : ""} ago`;
  const diffDay = Math.floor(diffHr / 24);
  return `${diffDay} day${diffDay !== 1 ? "s" : ""} ago`;
}

function hashStr(str) {
  let h = 0;
  for (let i = 0; i < str.length; i++) {
    h = str.charCodeAt(i) + ((h << 5) - h);
  }
  return Math.abs(h);
}

function getAvatarColor(name) {
  return AVATAR_COLORS[hashStr(name || "") % AVATAR_COLORS.length];
}

function getInitials(firstName, lastName) {
  return (
    ((firstName || "").charAt(0) + (lastName || "").charAt(0)).toUpperCase() ||
    "?"
  );
}

export default class SettingsComponent extends LightningElement {
  @track activeTab = "General";

  // Company Info
  @track companySettings = {};
  @track isSavingCompany = false;

  // PDF
  @track pdfVersions = [];
  @track isPdfLoading = false;

  // Team
  @track users = [];
  @track totalSeats = 0;
  @track usedSeats = 0;
  @track availableSeats = 0;
  @track error;
  wiredUsersResult;

  // Panel
  @track isEditModalOpen = false;
  @track selectedUser = {};
  @track selectedRole = "User";
  @track isLoading = false;

  // ── Lifecycle ──────────────────────────
  connectedCallback() {
    this.loadLicenseCounts();
    this.loadCompanySettings();
  }

  async loadLicenseCounts() {
    try {
      const r = await getLicenseCounts();
      this.totalSeats = r.total || 0;
      this.usedSeats = r.used || 0;
      this.availableSeats = r.available || 0;
    } catch (e) {
      console.error("License count error", e);
    }
  }

  async loadCompanySettings() {
    try {
      const r = await getCompanySettings();
      this.companySettings = r || {};
    } catch (e) {
      console.error("Company settings error", e);
    }
  }

  async loadPdfVersions() {
    this.isPdfLoading = true;
    try {
      const r = await getAllPDFVersions();
      this.pdfVersions = (r || []).map((v) => ({
        ...v,
        fileSizeKB: v.fileSize ? `${Math.round(v.fileSize / 1024)} KB` : "—",
        formattedDate: v.generatedDate
          ? new Date(v.generatedDate).toLocaleDateString("en-US", {
              year: "numeric",
              month: "short",
              day: "2-digit"
            })
          : "—",
        downloadUrl: v.contentDocumentId
          ? `/sfc/servlet.shepherd/document/download/${v.contentDocumentId}`
          : null
      }));
    } catch (e) {
      console.error("PDF load error", e);
    } finally {
      this.isPdfLoading = false;
    }
  }

  // ── Wire: Users ────────────────────────
  @wire(getUsers)
  wiredUsers(result) {
    this.wiredUsersResult = result;
    if (result.data) {
      this.users = result.data.map((u) => {
        const role = u.Express_Role__c || "User";
        const color = getAvatarColor(u.Name || "");
        const isSystem =
          (u.Name || "").toLowerCase().includes("integration") ||
          (u.Name || "").toLowerCase().includes("security") ||
          ["Integration User", "Security User"].includes(u.Name) ||
          (u.LicenseName || "").includes("Integration");

        return {
          ...u,
          Express_Role__c: role,
          initials: getInitials(u.FirstName, u.LastName),
          avatarStyle: `background-color:${color};`,
          roleBadgeClass: `role-badge role-${role.toLowerCase()}`,
          statusDotClass: `status-dot ${u.IsActive ? "dot-active" : "dot-inactive"}`,
          statusLabel: u.IsActive ? "Active" : "Inactive",
          relativeLastActive: getRelativeTime(u.LastLoginDate),
          isSystemUser: isSystem,
          menuItems: [
            { label: "Edit", value: "edit", disabled: isSystem },
            {
              label: "Resend Setup Email",
              value: "resend_email",
              disabled: isSystem
            },
            { label: "Deactivate", value: "deactivate", disabled: isSystem }
          ]
        };
      });
      this.error = undefined;
    } else if (result.error) {
      this.error = result.error.body
        ? result.error.body.message
        : result.error.message;
      this.users = [];
    }
  }

  // ── Tab Switching ──────────────────────
  handleTabClick(event) {
    const tab = event.currentTarget.dataset.tab;
    if (tab) {
      this.activeTab = tab;
      if (tab === "PDF") this.loadPdfVersions();
      if (tab === "Users") this.loadLicenseCounts();
    }
  }

  // ── Tab Getters ────────────────────────
  get isGeneralTab() {
    return this.activeTab === "General";
  }
  get isCompanyInfoTab() {
    return this.activeTab === "CompanyInfo";
  }
  get isPdfTab() {
    return this.activeTab === "PDF";
  }
  get isIntegrationsTab() {
    return this.activeTab === "Integrations";
  }
  get isUsersTab() {
    return this.activeTab === "Users";
  }

  get generalTabClass() {
    return `sidebar-item${this.activeTab === "General" ? " active" : ""}`;
  }
  get companyInfoTabClass() {
    return `sidebar-item${this.activeTab === "CompanyInfo" ? " active" : ""}`;
  }
  get pdfTabClass() {
    return `sidebar-item${this.activeTab === "PDF" ? " active" : ""}`;
  }
  get integrationsTabClass() {
    return `sidebar-item${this.activeTab === "Integrations" ? " active" : ""}`;
  }
  get teamTabClass() {
    return `sidebar-item${this.activeTab === "Users" ? " active" : ""}`;
  }

  get generalIconVariant() {
    return this.activeTab === "General" ? "brand" : "";
  }
  get companyInfoIconVariant() {
    return this.activeTab === "CompanyInfo" ? "brand" : "";
  }
  get pdfIconVariant() {
    return this.activeTab === "PDF" ? "brand" : "";
  }
  get integrationsIconVariant() {
    return this.activeTab === "Integrations" ? "brand" : "";
  }
  get teamIconVariant() {
    return this.activeTab === "Users" ? "brand" : "";
  }

  get hasUsers() {
    return this.users && this.users.length > 0;
  }
  get hasPdfVersions() {
    return this.pdfVersions && this.pdfVersions.length > 0;
  }

  // ── Modal Getters ──────────────────────
  get isUpdatingUser() {
    return !!this.selectedUser?.Id;
  }
  get modalTitle() {
    return this.isUpdatingUser ? "Edit Team Member" : "Create Team Member";
  }
  get modalSubtitle() {
    return this.isUpdatingUser
      ? "Update user details and role assignments."
      : "Add a team member and select a role before submitting.";
  }
  get modalButtonLabel() {
    return this.isUpdatingUser ? "Update" : "Create";
  }

  get isRoleAdmin() {
    return this.selectedRole === "Admin";
  }
  get isRoleManager() {
    return this.selectedRole === "Manager";
  }
  get isRoleUser() {
    return this.selectedRole === "User";
  }

  get adminOptionClass() {
    return `role-option${this.isRoleAdmin ? " selected" : ""}`;
  }
  get managerOptionClass() {
    return `role-option${this.isRoleManager ? " selected" : ""}`;
  }
  get userOptionClass() {
    return `role-option${this.isRoleUser ? " selected" : ""}`;
  }

  // ── Company Info Handlers ──────────────
  handleCompanyFieldChange(event) {
    const field = event.target.dataset.field;
    this.companySettings = {
      ...this.companySettings,
      [field]: event.target.value
    };
  }

  async handleSaveCompanyInfo() {
    this.isSavingCompany = true;
    try {
      await saveCompanySettings({
        companyName: this.companySettings.companyName || "",
        phone: this.companySettings.phone || "",
        website: this.companySettings.website || "",
        industry: this.companySettings.industry || "",
        addressLine1: this.companySettings.addressLine1 || "",
        city: this.companySettings.city || "",
        state: this.companySettings.state || "",
        country: this.companySettings.country || "",
        timezone: this.companySettings.timezone || "",
        currencyCode: this.companySettings.currencyCode || ""
      });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Saved",
          message: "Company settings updated.",
          variant: "success"
        })
      );
    } catch (e) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: e.body?.message || e.message,
          variant: "error"
        })
      );
    } finally {
      this.isSavingCompany = false;
    }
  }

  // ── Team Member Handlers ───────────────
  handleAddMember() {
    this.selectedUser = {
      FirstName: "",
      LastName: "",
      Email: "",
      Username: ""
    };
    this.selectedRole = "User";
    this.isEditModalOpen = true;
  }

  closeEditModal() {
    this.isEditModalOpen = false;
    this.selectedUser = {};
    this.selectedRole = "User";
  }

  handleBackdropClick(event) {
    if (event.target === event.currentTarget) this.closeEditModal();
  }

  handleInputChange(event) {
    const field = event.target.dataset.field;
    const value = event.target.value;
    this.selectedUser = { ...this.selectedUser, [field]: value };
    if (field === "Email" && !this.isUpdatingUser) {
      this.selectedUser = { ...this.selectedUser, Username: value };
    }
  }

  selectAdminRole() {
    this.selectedRole = "Admin";
  }
  selectManagerRole() {
    this.selectedRole = "Manager";
  }
  selectUserRole() {
    this.selectedRole = "User";
  }

  handleMenuAction(event) {
    const action = event.detail.value;
    const userId = event.currentTarget.dataset.userId;
    const user = this.users.find((u) => u.Id === userId);

    if (user?.isSystemUser) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Restricted",
          message: "System users cannot be modified.",
          variant: "warning"
        })
      );
      return;
    }

    if (action === "edit" && user) {
      this.selectedUser = { ...user };
      this.selectedRole = user.Express_Role__c || "User";
      this.isEditModalOpen = true;
    } else if (action === "remove_access" && user) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Feature Coming Soon",
          message: "Removing access is not yet implemented.",
          variant: "info"
        })
      );
    } else if (action === "deactivate") {
      // eslint-disable-next-line no-alert
      if (window.confirm("Are you sure you want to deactivate this user?")) {
        this.runDeactivateUser(userId);
      }
    } else if (action === "resend_email") {
      this.runResendEmail(userId);
    }
  }

  async runResendEmail(userId) {
    this.isLoading = true;
    try {
      await resendSetupEmail({ userId });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Sent",
          message: "Setup email resent successfully.",
          variant: "success"
        })
      );
    } catch (e) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: e.body?.message || e.message,
          variant: "error"
        })
      );
    } finally {
      this.isLoading = false;
    }
  }

  async runDeactivateUser(userId) {
    try {
      await deactivateUser({ userId });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Deactivated",
          message: "User deactivated.",
          variant: "success"
        })
      );
      await refreshApex(this.wiredUsersResult);
    } catch (e) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: e.body?.message || e.message,
          variant: "error"
        })
      );
    }
  }

  async handleUpdateRole() {
    if (!this.selectedUser) return;
    this.isLoading = true;
    try {
      if (this.isUpdatingUser) {
        await updateUserDetails({
          userId: this.selectedUser.Id,
          newRole: this.selectedRole,
          firstName: this.selectedUser.FirstName,
          lastName: this.selectedUser.LastName,
          email: this.selectedUser.Email
        });
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Updated",
            message: "Team member updated.",
            variant: "success"
          })
        );
      } else {
        await createUserDetails({
          newRole: this.selectedRole,
          firstName: this.selectedUser.FirstName,
          lastName: this.selectedUser.LastName,
          email: this.selectedUser.Email,
          username: this.selectedUser.Username || this.selectedUser.Email
        });
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Created",
            message:
              "Team member created. A password setup email has been sent to " +
              this.selectedUser.Email +
              ".",
            variant: "success"
          })
        );
      }
      this.closeEditModal();
      await refreshApex(this.wiredUsersResult);
    } catch (e) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: e.body?.message || e.message,
          variant: "error"
        })
      );
    } finally {
      this.isLoading = false;
    }
  }

  // ── PDF Handlers ───────────────────────
  async handleDeletePdf(event) {
    const versionId = event.currentTarget.dataset.id;
    if (!versionId) return;
    // eslint-disable-next-line no-alert
    if (!window.confirm("Delete this PDF version? This cannot be undone."))
      return;
    try {
      await deletePDFVersion({ versionId });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Deleted",
          message: "PDF version deleted.",
          variant: "success"
        })
      );
      this.loadPdfVersions();
    } catch (e) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: e.body?.message || e.message,
          variant: "error"
        })
      );
    }
  }

  handleAIAssistant() {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "AI Assistant",
        message:
          "Preparing organizational health report and settings optimization tips...",
        variant: "info"
      })
    );
    this.dispatchEvent(
      new CustomEvent("navigatetotab", {
        detail: { tab: "AI Assistant" },
        bubbles: true,
        composed: true
      })
    );
  }
}

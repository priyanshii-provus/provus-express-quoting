import { LightningElement, api, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import getQuoteById from "@salesforce/apex/QuoteService.getQuoteById";
import getQuoteLineItems from "@salesforce/apex/QuoteService.getQuoteLineItems";
import generatePDF from "@salesforce/apex/QuotePDFController.generatePDF";
import getPDFVersions from "@salesforce/apex/QuotePDFController.getPDFVersions";
import deletePDFVersion from "@salesforce/apex/QuotePDFController.deletePDFVersion";
import submitForApproval from "@salesforce/apex/QuoteApprovalController.submitForApproval";
import processApprovalAction from "@salesforce/apex/QuoteApprovalController.processApprovalAction";
import getApprovalHistory from "@salesforce/apex/QuoteApprovalController.getApprovalHistory";
import getCurrentUserRole from "@salesforce/apex/TeamController.getCurrentUserRole";
import updateQuoteFields from "@salesforce/apex/QuoteService.updateQuoteFields";
import evaluateQuoteHealth from "@salesforce/apex/QuoteHealthAdvisor.evaluateQuoteHealth";
import Id from "@salesforce/user/Id";

export default class QuoteDetailComponent extends NavigationMixin(
  LightningElement
) {
  @api recordId;

  @track quote = {};
  @track lineItems = [];
  @track activeTab = "summary";
  @track pdfVersions = [];
  @track isGenerating = false;
  @track approvalHistory = [];
  @track showApprovalModal = false;
  @track approvalComment = "";
  @track approvalAction = ""; // 'Submit', 'Approve', 'Reject'
  @track isApprovalSubmitting = false;
  @track currentUserRole = "User";

  // Smart Margin Advisor State
  @track healthScore = null;
  @track isHealthLoading = false;
  @track showHealthAdvisor = false;

  currentUserId = Id;

  wiredQuoteResult;
  wiredLineItemsResult;

  /* ───── Tab Getters ───── */
  get isSummaryActive() {
    return this.activeTab === "summary";
  }
  get isLineItemsActive() {
    return this.activeTab === "line-items";
  }
  get isTimelineActive() {
    return this.activeTab === "timeline";
  }
  get isGeneratedPDFsActive() {
    return this.activeTab === "generated-pdfs";
  }

  get summaryTabClass() {
    return this._tabCls("summary");
  }
  get lineItemsTabClass() {
    return this._tabCls("line-items");
  }
  get timelineTabClass() {
    return this._tabCls("timeline");
  }
  get generatedPDFsTabClass() {
    return this._tabCls("generated-pdfs");
  }

  _tabCls(id) {
    return this.activeTab === id ? "tab-btn active" : "tab-btn";
  }

  handleTabClick(event) {
    this.activeTab = event.currentTarget.dataset.id;
    if (this.activeTab === "generated-pdfs") this.loadPDFVersions();
  }

  /* ───── Wire: Quote ───── */
  @wire(getQuoteById, { quoteId: "$recordId" })
  wiredQuote(result) {
    this.wiredQuoteResult = result;
    if (result.data) {
      const d = result.data;
      this.quote = {
        Id: d.Id,
        Name: d.Name,
        QuoteNumber: d.QuoteNumber,
        Status: d.Status,
        Description: d.Description || "",
        TotalPrice: d.TotalPrice || 0,
        Subtotal: d.Subtotal || 0,
        MarginPct: d.Margin_Percentage__c || 0,
        TotalMargin: d.Total_Margin__c || 0,
        TotalCost: d.Total_Cost__c || 0,
        Discount: d.Discount || 0,
        DiscountAmount: d.Discount_Amount__c || 0,
        TimePeriod: d.Quote_Time_Period__c || "",
        ValidUntil: d.Valid_Until__c || "",
        StartDate: d.Start_Date__c || "",
        EndDate: d.End_Date__c || "",
        LaborRevenue: d.Labor_Revenue__c || 0,
        ProductsRevenue: d.Products_Revenue__c || 0,
        AddonsRevenue: d.Addons_Revenue__c || 0,
        OpportunityName: d.Opportunity?.Name || "N/A",
        AccountName: d.Opportunity?.Account?.Name || "N/A",
        CreatedDate: d.CreatedDate,
        CreatedByName: d.CreatedBy?.Name || "",
        LastModifiedByName: d.LastModifiedBy?.Name || ""
      };
    }
  }

  /* ───── Wire: Line Items ───── */
  @wire(getQuoteLineItems, { quoteId: "$recordId" })
  wiredItems(result) {
    this.wiredLineItemsResult = result;
    if (result.data) {
      this.lineItems = result.data;
    }
  }

  @wire(getCurrentUserRole)
  wiredRole({ data }) {
    if (data) {
      this.currentUserRole = data;
    }
  }

  /* ───── Financial Strip Getters ───── */
  get formattedStartDate() {
    return this.quote.StartDate
      ? new Date(this.quote.StartDate + "T00:00:00").toLocaleDateString(
          "en-US",
          { month: "short", day: "numeric", year: "numeric" }
        )
      : "—";
  }
  get formattedEndDate() {
    return this.quote.EndDate
      ? new Date(this.quote.EndDate + "T00:00:00").toLocaleDateString("en-US", {
          month: "short",
          day: "numeric",
          year: "numeric"
        })
      : "—";
  }
  get formattedMargin() {
    return `₹${this.fmtNum(this.quote.TotalMargin)} (${this.fmtNum(this.quote.MarginPct)}%)`;
  }
  get formattedDiscount() {
    return `₹${this.fmtNum(this.quote.DiscountAmount)} (${this.fmtNum(this.quote.Discount)}%)`;
  }
  get formattedCreatedDate() {
    return this.quote.CreatedDate
      ? new Date(this.quote.CreatedDate).toLocaleDateString("en-US", {
          month: "short",
          day: "numeric",
          year: "numeric"
        })
      : "";
  }
  get statusBadgeClass() {
    if (!this.quote.Status) return "status-badge";
    return `status-badge status-${this.quote.Status.replace(/\s+/g, "")}`;
  }

  /* ───── Approval Getters ───── */
  get isDraft() {
    return this.quote.Status === "Draft";
  }
  get isPendingApproval() {
    return this.quote.Status === "Pending Approval";
  }
  get isLocked() {
    if (this.quote.Status === "Approved" || this.quote.Status === "Rejected") {
      return true;
    }
    if (
      this.quote.Status === "Pending Approval" &&
      this.currentUserRole !== "Admin" &&
      this.currentUserRole !== "Manager"
    ) {
      return true;
    }
    return false;
  }

  get canApproveReject() {
    return (
      this.isPendingApproval &&
      (this.currentUserRole === "Admin" || this.currentUserRole === "Manager")
    );
  }
  get canRecall() {
    return this.isPendingApproval;
  }

  get hasApprovalHistory() {
    return this.approvalHistory && this.approvalHistory.length > 0;
  }

  get modalTitle() {
    if (this.approvalAction === "Submit") return "Submit Quote for Approval";
    if (this.approvalAction === "Approve") return "Approve Quote";
    if (this.approvalAction === "Reject") return "Reject Quote";
    return "";
  }

  get modalDescription() {
    if (this.approvalAction === "Submit")
      return (
        'Submit quote "' +
        this.quote.QuoteNumber +
        '" for approval by Provus Express Quoting Users.'
      );
    if (this.approvalAction === "Approve")
      return "Are you sure you want to approve this quote?";
    if (this.approvalAction === "Reject")
      return "Please provide a reason for rejecting this quote.";
    return "";
  }

  get modalButtonLabel() {
    if (this.approvalAction === "Submit") return "Submit for Approval";
    return this.approvalAction;
  }

  get isRejectAction() {
    return this.approvalAction === "Reject";
  }

  /* ───── Revenue Card Computations ───── */
  get laborItems() {
    return this.lineItems.filter((i) => i.Item_Type__c === "Labor");
  }
  get productItems() {
    return this.lineItems.filter((i) => i.Item_Type__c === "Product");
  }
  get addonItems() {
    return this.lineItems.filter((i) => i.Item_Type__c === "Add-on");
  }

  get laborCost() {
    return this.laborItems.reduce((s, i) => s + (i.Cost__c || 0), 0);
  }
  get laborMargin() {
    return this.quote.LaborRevenue - this.laborCost;
  }
  get laborMarginPct() {
    return this.pct(this.laborMargin, this.quote.LaborRevenue);
  }
  get laborCount() {
    return this.laborItems.length;
  }

  get productsCost() {
    return this.productItems.reduce((s, i) => s + (i.Cost__c || 0), 0);
  }
  get productsMargin() {
    return this.quote.ProductsRevenue - this.productsCost;
  }
  get productsMarginPct() {
    return this.pct(this.productsMargin, this.quote.ProductsRevenue);
  }
  get productsCount() {
    return this.productItems.length;
  }

  get addonsCost() {
    return this.addonItems.reduce((s, i) => s + (i.Cost__c || 0), 0);
  }
  get addonsMargin() {
    return this.quote.AddonsRevenue - this.addonsCost;
  }
  get addonsMarginPct() {
    return this.pct(this.addonsMargin, this.quote.AddonsRevenue);
  }
  get addonsCount() {
    return this.addonItems.length;
  }

  /* ───── Chart Data ───── */
  get chartMaxValue() {
    return Math.max(
      this.laborCost,
      this.laborMargin,
      this.productsCost,
      this.productsMargin,
      this.addonsCost,
      this.addonsMargin,
      1
    );
  }
  get laborCostBarPct() {
    return this.barPct(this.laborCost);
  }
  get laborMarginBarPct() {
    return this.barPct(this.laborMargin);
  }
  get productsCostBarPct() {
    return this.barPct(this.productsCost);
  }
  get productsMarginBarPct() {
    return this.barPct(this.productsMargin);
  }
  get addonsCostBarPct() {
    return this.barPct(this.addonsCost);
  }
  get addonsMarginBarPct() {
    return this.barPct(this.addonsMargin);
  }

  barPct(val) {
    return `height: ${Math.max((val / this.chartMaxValue) * 100, 2)}%`;
  }

  /* ───── Phase Summary Table ───── */
  get phaseData() {
    const phases = {};
    this.lineItems.forEach((item) => {
      const phase = item.Phase__c || "Default";
      if (!phases[phase]) {
        phases[phase] = {
          phase,
          labor: 0,
          products: 0,
          addons: 0,
          total: 0,
          items: 0
        };
      }
      const price = item.TotalPrice || 0;
      phases[phase].total += price;
      phases[phase].items += 1;
      if (item.Item_Type__c === "Labor") phases[phase].labor += price;
      else if (item.Item_Type__c === "Product") phases[phase].products += price;
      else if (item.Item_Type__c === "Add-on") phases[phase].addons += price;
    });
    return Object.values(phases);
  }
  get hasPhaseData() {
    return this.phaseData.length > 0;
  }

  /* Phase Breakdown Chart */
  get phaseChartMax() {
    let max = 1;
    this.phaseData.forEach((p) => {
      const cost = this.lineItems
        .filter((i) => (i.Phase__c || "Default") === p.phase)
        .reduce((s, i) => s + (i.Cost__c || 0), 0);
      const margin = this.lineItems
        .filter((i) => (i.Phase__c || "Default") === p.phase)
        .reduce((s, i) => s + (i.Margin__c || 0), 0);
      if (cost > max) max = cost;
      if (margin > max) max = margin;
    });
    return max;
  }

  get phaseChartData() {
    return this.phaseData.map((p) => {
      const cost = this.lineItems
        .filter((i) => (i.Phase__c || "Default") === p.phase)
        .reduce((s, i) => s + (i.Cost__c || 0), 0);
      const margin = this.lineItems
        .filter((i) => (i.Phase__c || "Default") === p.phase)
        .reduce((s, i) => s + (i.Margin__c || 0), 0);
      return {
        phase: p.phase,
        costBarPct: `height: ${Math.max((cost / this.phaseChartMax) * 100, 2)}%`,
        marginBarPct: `height: ${Math.max((margin / this.phaseChartMax) * 100, 2)}%`
      };
    });
  }

  /* ───── Gantt Chart Generation ───── */
  get ganttMonths() {
    if (!this.quote.StartDate || !this.quote.EndDate) return [];
    const start = new Date(this.quote.StartDate + "T00:00:00");
    const end = new Date(this.quote.EndDate + "T00:00:00");
    if (start >= end) return [];

    const months = [];
    let current = new Date(start.getFullYear(), start.getMonth(), 1);
    const endBoundary = new Date(end.getFullYear(), end.getMonth(), 1);

    while (current <= endBoundary) {
      months.push({
        key: `m-${current.getFullYear()}-${current.getMonth()}`,
        label: current.toLocaleDateString("en-US", { month: "short" }),
        year: current.getFullYear()
      });
      current.setMonth(current.getMonth() + 1);
      if (months.length > 60) break; // safety
    }
    return months;
  }

  get ganttYears() {
    const months = this.ganttMonths;
    if (!months.length) return [];
    const years = [];
    let currentYear = null;
    let colSpan = 0;
    months.forEach((m) => {
      if (m.year !== currentYear) {
        if (currentYear !== null)
          years.push({
            year: currentYear,
            colSpan,
            key: `y-${currentYear}`,
            style: `grid-column: span ${colSpan};`
          });
        currentYear = m.year;
        colSpan = 1;
      } else {
        colSpan++;
      }
    });
    if (currentYear !== null)
      years.push({
        year: currentYear,
        colSpan,
        key: `y-${currentYear}`,
        style: `grid-column: span ${colSpan};`
      });
    return years;
  }

  get ganttGridStyle() {
    const cols = this.ganttMonths.length || 1;
    return `display: grid; grid-template-columns: repeat(${cols}, minmax(100px, 1fr));`;
  }

  get ganttPhases() {
    const totalMonths = this.ganttMonths.length || 1;
    const phasesMap = {};

    this.lineItems.forEach((item) => {
      const phase = item.Phase__c || "Default phase";
      if (!phasesMap[phase]) phasesMap[phase] = { phaseName: phase, items: [] };

      // Calculate actual duration and offset based on dates
      let durationMonths = 1;
      let startIndex = 0;
      let durationText = "1 month";

      if (item.Start_Date__c && item.End_Date__c && this.quote.StartDate) {
        const itemStart = new Date(item.Start_Date__c + "T00:00:00");
        const itemEnd = new Date(item.End_Date__c + "T00:00:00");
        const quoteStart = new Date(this.quote.StartDate + "T00:00:00");

        startIndex = (itemStart.getFullYear() - quoteStart.getFullYear()) * 12 + (itemStart.getMonth() - quoteStart.getMonth());
        if (startIndex < 0) startIndex = 0;

        durationMonths = (itemEnd.getFullYear() - itemStart.getFullYear()) * 12 + (itemEnd.getMonth() - itemStart.getMonth()) + 1;
        
        const maxSpan = totalMonths - startIndex;
        if (durationMonths > maxSpan) durationMonths = maxSpan;
        if (durationMonths <= 0) durationMonths = 1;

        const diffTime = Math.abs(itemEnd - itemStart);
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        if (diffDays <= 31) {
            const weeks = Math.round(diffDays / 7);
            if (weeks <= 1 && diffDays <= 7) durationText = `${diffDays} day${diffDays !== 1 ? 's' : ''}`;
            else if (weeks > 0 && weeks < 4) durationText = `${weeks} week${weeks > 1 ? 's' : ''}`;
            else durationText = `1 month`;
        } else {
            durationText = `${durationMonths} months`;
        }
      } else {
        // Fallback for items missing dates
        startIndex = 0;
        durationMonths = Math.min(3, totalMonths);
        durationText = `${durationMonths} months`;
      }

      let displayType = item.Item_Type__c || "Product";
      if (displayType === "Labor") displayType = "Resource Role";

      let pillClass = "gantt-pill pill-product";
      let dotClass = "legend-dot dot-product";
      let iconName = "utility:product";
      if (displayType === "Add-on") {
        pillClass = "gantt-pill pill-addon";
        dotClass = "legend-dot dot-addon";
        iconName = "utility:puzzle";
      } else if (displayType === "Resource Role") {
        pillClass = "gantt-pill pill-resource";
        dotClass = "legend-dot dot-resource";
        iconName = "utility:resource_absence";
      }

      phasesMap[phase].items.push({
        id: item.Id,
        name:
          (item.Item_Type__c === "Labor" || item.Item_Type__c === "Resource") &&
          item.Resource_Role__r
            ? item.Resource_Role__r.Name
            : item.Product2?.Name || item.Name,
        duration: durationText,
        displayType,
        dotClass,
        pillClass,
        pillStyle: `grid-column: ${startIndex + 1} / span ${durationMonths};`,
        iconName
      });
    });
    return Object.values(phasesMap);
  }

  get hasTimeline() {
    return this.ganttMonths.length > 0;
  }

  handleAddMilestone() {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Info",
        message: "Milestone creation coming soon.",
        variant: "info"
      })
    );
  }

  /* ───── Helpers ───── */
  sumField(arr, field) {
    return arr.reduce((s, i) => s + (i[field] || 0), 0);
  }
  pct(margin, revenue) {
    if (!revenue || revenue === 0) return 0;
    return Math.round((margin / revenue) * 1000) / 10;
  }
  fmtNum(n) {
    if (n == null) return "0.00";
    return Number(n).toLocaleString("en-US", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });
  }

  /* ───── Actions ───── */
  handleBackToQuotes() {
    // Fire an event for the parent (expressHomeLayout) to switch to the Quotes tab
    this.dispatchEvent(new CustomEvent("navigateback"));
  }

  handleRefresh() {
    refreshApex(this.wiredQuoteResult);
    refreshApex(this.wiredLineItemsResult);
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Refreshed",
        message: "Quote data refreshed",
        variant: "success"
      })
    );
  }

  async handleSave() {
    try {
      await updateQuoteFields({
        quoteId: this.recordId,
        description: this.quote.Description
      });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Saved",
          message: "Quote saved successfully",
          variant: "success"
        })
      );
      refreshApex(this.wiredQuoteResult);
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: error.body?.message || "Failed to save quote",
          variant: "error"
        })
      );
    }
  }

  handleSubmitForApproval() {
    this.openSubmitModal();
  }

  /* ───── Approval Actions ───── */
  openSubmitModal() {
    this.approvalAction = "Submit";
    this.approvalComment = "";
    this.showApprovalModal = true;
  }

  openApproveModal() {
    this.approvalAction = "Approve";
    this.approvalComment = "";
    this.showApprovalModal = true;
  }

  openRejectModal() {
    this.approvalAction = "Reject";
    this.approvalComment = "";
    this.showApprovalModal = true;
  }

  closeModal() {
    this.showApprovalModal = false;
    this.approvalComment = "";
  }

  handleCommentChange(event) {
    this.approvalComment = event.target.value;
  }

  async handleApprovalAction() {
    if (this.isRejectAction && !this.approvalComment) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "Comments are required for rejection",
          variant: "error"
        })
      );
      return;
    }

    this.isApprovalSubmitting = true;
    try {
      if (this.approvalAction === "Submit") {
        await submitForApproval({
          quoteId: this.recordId,
          comment: this.approvalComment
        });
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Quote submitted for approval",
            variant: "success"
          })
        );
      } else {
        await processApprovalAction({
          quoteId: this.recordId,
          action: this.approvalAction,
          comment: this.approvalComment
        });
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: `Quote ${this.approvalAction.toLowerCase()}d`,
            variant: "success"
          })
        );
      }
      this.closeModal();
      this.handleRefresh();
      this.loadApprovalHistory();
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: error.body?.message || "Action failed",
          variant: "error"
        })
      );
    } finally {
      this.isApprovalSubmitting = false;
    }
  }

  async handleRecall() {
    try {
      await processApprovalAction({
        quoteId: this.recordId,
        action: "Recall",
        comment: ""
      });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Quote approval recalled",
          variant: "success"
        })
      );
      this.handleRefresh();
      this.loadApprovalHistory();
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: error.body?.message || "Recall failed",
          variant: "error"
        })
      );
    }
  }

  loadApprovalHistory() {
    if (!this.recordId) return;
    getApprovalHistory({ quoteId: this.recordId })
      .then((result) => {
        this.approvalHistory = result.map((step) => ({
          ...step,
          formattedDate: this.formatRelativeDate(step.createdDate),
          markerClass: `marker marker-${step.statusLabel.toLowerCase()}`
        }));
      })
      .catch((error) =>
        console.error("Error loading approval history:", error)
      );
  }

  /* ───── PDF Logic ───── */
  connectedCallback() {
    this.loadPDFVersions();
    this.loadApprovalHistory();
  }

  loadPDFVersions() {
    if (!this.recordId) return;
    getPDFVersions({ quoteId: this.recordId })
      .then((result) => {
        this.pdfVersions = result.map((v, index) => ({
          ...v,
          rowNumber: index + 1,
          notesDisplay: v.notes || "—",
          marginDecimal: v.marginPercentage ? v.marginPercentage / 100 : 0,
          formattedDate: this.formatRelativeDate(v.generatedDate)
        }));
      })
      .catch((error) => console.error("Error loading PDF versions:", error));
  }

  get hasPDFVersions() {
    return this.pdfVersions && this.pdfVersions.length > 0;
  }

  formatRelativeDate(dateString) {
    if (!dateString) return "—";
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);
    if (diffMins < 1) return "just now";
    if (diffMins < 60) return `${diffMins} min ago`;
    if (diffHours < 24)
      return `${diffHours} hour${diffHours > 1 ? "s" : ""} ago`;
    if (diffDays < 7) return `${diffDays} day${diffDays > 1 ? "s" : ""} ago`;
    return date.toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric"
    });
  }

  async handleGeneratePDF() {
    this.isGenerating = true;
    try {
      await generatePDF({ quoteId: this.recordId });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "PDF version saved",
          variant: "success"
        })
      );
      this.loadPDFVersions();
      this.activeTab = "generated-pdfs";
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: error.body?.message || "Failed to generate PDF",
          variant: "error"
        })
      );
    } finally {
      this.isGenerating = false;
    }
  }

  /* ───── Smart Margin Advisor ───── */
  async handleAnalyzeHealth() {
    this.activeTab = "line-items"; // Switch to tab where panel lives
    this.showHealthAdvisor = true;
    this.isHealthLoading = true;
    try {
      this.healthScore = await evaluateQuoteHealth({ quoteId: this.recordId });
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: error.body?.message || "Failed to analyze quote health",
          variant: "error"
        })
      );
    } finally {
      this.isHealthLoading = false;
    }
  }

  handleCloseHealth() {
    this.showHealthAdvisor = false;
  }

  get healthRingVariant() {
    if (!this.healthScore) return "base";
    if (this.healthScore.status === "Healthy") return "base-autocomplete";
    if (this.healthScore.status === "Warning") return "warning";
    return "expired";
  }

  get healthBadgeClass() {
    if (!this.healthScore) return "slds-badge";
    const base = "slds-badge ";
    if (this.healthScore.status === "Healthy") return base + "slds-theme_success";
    if (this.healthScore.status === "Warning") return base + "slds-theme_warning";
    return base + "slds-theme_error";
  }

  get processedRecommendations() {
    if (!this.healthScore || !this.healthScore.recommendations) return [];
    return this.healthScore.recommendations.map(r => {
      let iconVariant = "";
      let bgColors = "";
      if (r.severity === "success") { 
        iconVariant = "success"; 
        bgColors = "background-color: #f0fdf4; border-color: #bbf7d0;";
      } else if (r.severity === "warning") { 
        iconVariant = "warning"; 
        bgColors = "background-color: #fffbeb; border-color: #fde68a;";
      } else if (r.severity === "error") { 
        iconVariant = "error"; 
        bgColors = "background-color: #fef2f2; border-color: #fecaca;";
      } else { 
        bgColors = "background-color: #f3f4f6; border-color: #e5e7eb;";
      }
      
      const bgStyle = `${bgColors} display: flex; align-items: flex-start; gap: 12px; border-radius: 6px; border-width: 1px; border-style: solid;`;
      return { ...r, iconVariant, bgStyle };
    });
  }

  handleViewVersion(event) {
    const contentDocId = event.currentTarget.dataset.id;
    this[NavigationMixin.Navigate]({
      type: "standard__namedPage",
      attributes: { pageName: "filePreview" },
      state: { selectedRecordId: contentDocId }
    });
  }

  handleDownloadVersion(event) {
    const contentVersionId = event.currentTarget.dataset.id;
    window.open(
      `/sfc/servlet.shepherd/version/download/${contentVersionId}`,
      "_blank"
    );
  }

  async handleDeleteVersion(event) {
    const versionId = event.currentTarget.dataset.id;
    try {
      await deletePDFVersion({ versionId });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "PDF version deleted",
          variant: "success"
        })
      );
      this.loadPDFVersions();
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: error.body?.message || "Failed to delete",
          variant: "error"
        })
      );
    }
  }
}

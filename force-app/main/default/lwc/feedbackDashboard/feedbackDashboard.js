import { LightningElement, track, wire } from "lwc";
import getFeedbacks from "@salesforce/apex/FeedbackController.getFeedbacks";
import saveFeedback from "@salesforce/apex/FeedbackController.saveFeedback";
import deleteFeedback from "@salesforce/apex/FeedbackController.deleteFeedback";
import getCurrentUserName from "@salesforce/apex/FeedbackController.getCurrentUserName";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";

// No shared constants needed currently

export default class FeedbackDashboard extends LightningElement {
  @track feedbacks = [];
  @track isBoxOpen = false;
  @track newFeedbackText = "";
  @track currentUserName = "Loading...";
  @track isLoading = false;
  wiredFeedbacksResult;

  @wire(getCurrentUserName)
  wiredName({ data }) {
    if (data) {
      this.currentUserName = data;
    }
  }

  @wire(getFeedbacks)
  wiredFeedbacks(result) {
    this.wiredFeedbacksResult = result;
    if (result.data) {
      this.feedbacks = result.data.map((fb) => {
        return {
          ...fb,
          formattedDate: new Date(fb.CreatedDate).toLocaleDateString()
        };
      });
    }
  }

  get isSubmitDisabled() {
    return !this.newFeedbackText || this.newFeedbackText.trim().length < 5;
  }

  toggleBox() {
    this.isBoxOpen = !this.isBoxOpen;
    if (!this.isBoxOpen) {
      this.newFeedbackText = "";
    }
  }

  handleTextChange(event) {
    this.newFeedbackText = event.target.value;
  }

  async handleSubmit() {
    this.isLoading = true;
    try {
      await saveFeedback({
        text: this.newFeedbackText,
        color: "" // No longer needed
      });

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Feedback submitted successfully!",
          variant: "success"
        })
      );

      this.newFeedbackText = "";
      this.isBoxOpen = false;
      await refreshApex(this.wiredFeedbacksResult);
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: error.body?.message || "Something went wrong",
          variant: "error"
        })
      );
    } finally {
      this.isLoading = false;
    }
  }

  async handleDelete(event) {
    const feedbackId = event.currentTarget.dataset.id;
    if (!feedbackId) return;

    // eslint-disable-next-line no-alert
    if (!window.confirm("Are you sure you want to delete this feedback?"))
      return;

    this.isLoading = true;
    try {
      await deleteFeedback({ feedbackId });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Deleted",
          message: "Feedback removed successfully",
          variant: "success"
        })
      );
      await refreshApex(this.wiredFeedbacksResult);
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: error.body?.message || "Delete failed",
          variant: "error"
        })
      );
    } finally {
      this.isLoading = false;
    }
  }
}

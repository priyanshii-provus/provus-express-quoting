public with sharing class QuoteApprovalController {
    
    @AuraEnabled
    public static void submitForApproval(Id quoteId, String comment) {
        try {
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setComments(comment);
            req.setObjectId(quoteId);
            
            // Submit the approval request
            Approval.ProcessResult result = Approval.process(req);
            
            if (!result.isSuccess()) {
                throw new AuraHandledException('Failed to submit for approval: ' + result.getErrors()[0].getMessage());
            }
        } catch (System.DmlException e) {
            if (e.getMessage().contains('NO_APPLICABLE_PROCESS')) {
                // FALLBACK: If no process exists, just update status manually
                update new Quote(Id = quoteId, Status = 'Pending Approval');
            } else {
                throw new AuraHandledException(e.getMessage());
            }
        } catch (Exception e) {
            if (e.getMessage().contains('NO_APPLICABLE_PROCESS')) {
                update new Quote(Id = quoteId, Status = 'Pending Approval');
            } else {
                throw new AuraHandledException(e.getMessage());
            }
        }
    }

    @AuraEnabled
    public static void processApprovalAction(Id quoteId, String action, String comment) {
        if (!TeamController.isManagerOrAdmin()) {
            throw new AuraHandledException('Only Managers or Admins can approve or reject quotes.');
        }

        try {
            // Find the pending work item
            List<ProcessInstanceWorkitem> workItems = [
                SELECT Id FROM ProcessInstanceWorkitem 
                WHERE ProcessInstance.TargetObjectId = :quoteId 
                AND ProcessInstance.Status = 'Pending'
                LIMIT 1
            ];
            
            if (workItems.isEmpty() && action != 'Recall') {
                // FALLBACK: If no standard workitems, but status is Pending Approval, allow manual update
                Quote q = [SELECT Status FROM Quote WHERE Id = :quoteId LIMIT 1];
                if (q.Status == 'Pending Approval') {
                    String newStatus = (action == 'Approve') ? 'Approved' : 'Rejected';
                    update new Quote(Id = quoteId, Status = newStatus);
                    return;
                }
                throw new AuraHandledException('No pending approval request found for this quote.');
            }

            if (action == 'Recall') {
                recallQuote(quoteId);
                return;
            }

            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setComments(comment);
            req.setAction(action); // Approve or Reject
            req.setWorkitemId(workItems[0].Id);
            
            Approval.ProcessResult result = Approval.process(req);
            
            if (!result.isSuccess()) {
                throw new AuraHandledException('Failed to ' + action.toLowerCase() + ': ' + result.getErrors()[0].getMessage());
            }

            // Manually update status for UI if the Approval Process doesn't
            String newStatus = (action == 'Approve') ? 'Approved' : 'Rejected';
            update new Quote(Id = quoteId, Status = newStatus);

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void recallQuote(Id quoteId) {
        List<ProcessInstance> instances = [
            SELECT Id FROM ProcessInstance 
            WHERE TargetObjectId = :quoteId AND Status = 'Pending' 
            LIMIT 1
        ];
        
        if (instances.isEmpty()) {
            // If no standard process, just reset status to Draft
            update new Quote(Id = quoteId, Status = 'Draft');
            return;
        }

        // Technically 'Recall' is deleting the record from Workitem or using specific logic
        // But for simplicity in this CPQ app, we reset the status and let the user re-submit.
        update new Quote(Id = quoteId, Status = 'Draft');
    }

    @AuraEnabled(cacheable=true)
    public static List<ApprovalStep> getApprovalHistory(Id quoteId) {
        List<ApprovalStep> history = new List<ApprovalStep>();
        
        // Get ProcessInstance steps
        List<ProcessInstance> instances = [
            SELECT Id, (SELECT Id, StepStatus, Comments, CreatedDate, Actor.Name FROM StepsAndWorkitems ORDER BY CreatedDate DESC)
            FROM ProcessInstance 
            WHERE TargetObjectId = :quoteId 
            ORDER BY CreatedDate DESC
        ];
        
        for (ProcessInstance pi : instances) {
            for (SObject sw : pi.StepsAndWorkitems) {
                ApprovalStep step = new ApprovalStep();
                step.id = (Id)sw.get('Id');
                step.status = (String)sw.get('StepStatus');
                step.comments = (String)sw.get('Comments');
                step.createdDate = (Datetime)sw.get('CreatedDate');
                step.actorName = (String)((SObject)sw.getSObject('Actor')).get('Name');
                
                // Map status to readable labels
                if (step.status == 'Started') step.statusLabel = 'Submitted';
                else if (step.status == 'Pending') step.statusLabel = 'Pending';
                else if (step.status == 'Approved') step.statusLabel = 'Approved';
                else if (step.status == 'Rejected') step.statusLabel = 'Rejected';
                else if (step.status == 'Removed') step.statusLabel = 'Recalled';
                else step.statusLabel = step.status;
                
                history.add(step);
            }
        }
        
        return history;
    }

    public class ApprovalStep {
        @AuraEnabled public Id id;
        @AuraEnabled public String status;
        @AuraEnabled public String statusLabel;
        @AuraEnabled public String comments;
        @AuraEnabled public String actorName;
        @AuraEnabled public Datetime createdDate;
    }
}

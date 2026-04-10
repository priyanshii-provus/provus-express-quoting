@isTest
private class QuoteApprovalControllerTest {
  @testSetup
  static void setup() {
    Account acc = TestDataFactory.createAccount('Test Account', 'Customer', 'Technology');
    Opportunity opp = TestDataFactory.createOpportunity('Test Opp', acc.Id, Date.today().addDays(30));
    Quote quote = TestDataFactory.createQuote('Approval Quote', opp.Id, 'Draft');
    
    // Add value to quote to pass validation
    Map<String, Id> prodData = TestDataFactory.createProduct('Test Product');
    TestDataFactory.createQuoteLineItems(quote.Id, prodData.get('pricebookEntryId'), prodData.get('productId'), 1);
  }

  @isTest
  static void testSubmitForApproval_Fallback() {
    Quote quote = [SELECT Id FROM Quote LIMIT 1];
    
    Test.startTest();
    // This will trigger the NO_APPLICABLE_PROCESS fallback in a default scratch org
    QuoteApprovalController.submitForApproval(quote.Id, 'Please approve');
    Test.stopTest();

    Quote result = [SELECT Status FROM Quote WHERE Id = :quote.Id];
    System.assertEquals('Pending Approval', result.Status, 'Status should be Pending Approval after submission');
  }

  @isTest
  static void testProcessApprovalAction_Approve_Fallback() {
    Quote quote = [SELECT Id FROM Quote LIMIT 1];
    quote.Status = 'Pending Approval';
    update quote;

    Test.startTest();
    // Testing approve action without a real workitem (fallback)
    QuoteApprovalController.processApprovalAction(quote.Id, 'Approve', 'Looks good');
    Test.stopTest();

    Quote result = [SELECT Status FROM Quote WHERE Id = :quote.Id];
    System.assertEquals('Approved', result.Status, 'Status should be Approved');
  }

  @isTest
  static void testProcessApprovalAction_Reject_Fallback() {
    Quote quote = [SELECT Id FROM Quote LIMIT 1];
    quote.Status = 'Pending Approval';
    update quote;

    Test.startTest();
    QuoteApprovalController.processApprovalAction(quote.Id, 'Reject', 'Too expensive');
    Test.stopTest();

    Quote result = [SELECT Status FROM Quote WHERE Id = :quote.Id];
    System.assertEquals('Rejected', result.Status, 'Status should be Rejected');
  }

  @isTest
  static void testProcessApprovalAction_Recall() {
    Quote quote = [SELECT Id FROM Quote LIMIT 1];
    quote.Status = 'Pending Approval';
    update quote;

    Test.startTest();
    QuoteApprovalController.processApprovalAction(quote.Id, 'Recall', 'Need to edit');
    Test.stopTest();

    Quote result = [SELECT Status FROM Quote WHERE Id = :quote.Id];
    System.assertEquals('Draft', result.Status, 'Status should be Draft after recall');
  }

  @isTest
  static void testProcessApprovalAction_NoPendingQuote() {
    // Quote is still Draft — no pending approval, no workitems
    // action != 'Recall', so it should throw
    Quote quote = [SELECT Id FROM Quote LIMIT 1];

    Test.startTest();
    Boolean caught = false;
    try {
      QuoteApprovalController.processApprovalAction(quote.Id, 'Approve', 'Try approve Draft');
    } catch (AuraHandledException e) {
      caught = true;
    }
    Test.stopTest();
    System.assert(caught, 'Should throw when no pending approval and status is not Pending Approval');
  }

  @isTest
  static void testProcessApprovalAction_NonAdmin() {
    Quote quote = [SELECT Id FROM Quote LIMIT 1];
    quote.Status = 'Pending Approval';
    update quote;

    // Create a standard user with 'User' role
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    User stdUser = new User(
      FirstName = 'Std',
      LastName = 'Approver',
      Email = 'stdapprover@testprovus.invalid',
      Username = 'stdapprover' + DateTime.now().getTime() + '@testprovus.invalid',
      Alias = 'stda',
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      ProfileId = p.Id,
      Express_Role__c = 'User'
    );
    insert stdUser;

    System.runAs(stdUser) {
      Test.startTest();
      Boolean caught = false;
      try {
        QuoteApprovalController.processApprovalAction(quote.Id, 'Approve', 'Non-admin trying');
      } catch (AuraHandledException e) {
        caught = true;
      }
      Test.stopTest();
      System.assert(caught, 'Non-admin/non-manager should not be able to approve');
    }
  }

  // ── Approval History Tests ──
  @isTest
  static void testGetApprovalHistory_Approved() {
    Quote quote = [SELECT Id FROM Quote LIMIT 1];
    quote.Status = 'Approved';
    update quote;

    Test.startTest();
    List<QuoteApprovalController.ApprovalStep> history = QuoteApprovalController.getApprovalHistory(quote.Id);
    Test.stopTest();

    System.assert(!history.isEmpty(), 'History should not be empty for an approved quote');
    // Should have an Approved step + a Submitted step
    Boolean foundApproved = false;
    Boolean foundSubmitted = false;
    for (QuoteApprovalController.ApprovalStep step : history) {
      if (step.status == 'Approved') foundApproved = true;
      if (step.status == 'Submitted') foundSubmitted = true;
    }
    System.assert(foundApproved, 'Should have an Approved step');
    System.assert(foundSubmitted, 'Should have a Submitted step');
  }

  @isTest
  static void testGetApprovalHistory_Rejected() {
    Quote quote = [SELECT Id FROM Quote LIMIT 1];
    quote.Status = 'Rejected';
    update quote;

    Test.startTest();
    List<QuoteApprovalController.ApprovalStep> history = QuoteApprovalController.getApprovalHistory(quote.Id);
    Test.stopTest();

    System.assert(!history.isEmpty(), 'History should not be empty for a rejected quote');
    Boolean foundRejected = false;
    for (QuoteApprovalController.ApprovalStep step : history) {
      if (step.status == 'Rejected') foundRejected = true;
    }
    System.assert(foundRejected, 'Should have a Rejected step');
  }

  @isTest
  static void testGetApprovalHistory_PendingApproval() {
    Quote quote = [SELECT Id FROM Quote LIMIT 1];
    quote.Status = 'Pending Approval';
    update quote;

    Test.startTest();
    List<QuoteApprovalController.ApprovalStep> history = QuoteApprovalController.getApprovalHistory(quote.Id);
    Test.stopTest();

    System.assert(!history.isEmpty(), 'History should not be empty for Pending Approval quote');
    Boolean foundPending = false;
    Boolean foundSubmitted = false;
    for (QuoteApprovalController.ApprovalStep step : history) {
      if (step.status == 'Pending') foundPending = true;
      if (step.status == 'Submitted') foundSubmitted = true;
    }
    System.assert(foundPending, 'Should have a Pending step');
    System.assert(foundSubmitted, 'Should have a Submitted step');
  }

  @isTest
  static void testGetApprovalHistory_Draft() {
    // Draft quote — no approval history at all
    Quote quote = [SELECT Id FROM Quote LIMIT 1];

    Test.startTest();
    List<QuoteApprovalController.ApprovalStep> history = QuoteApprovalController.getApprovalHistory(quote.Id);
    Test.stopTest();

    System.assert(history.isEmpty(), 'Draft quote should have empty approval history');
  }

  @isTest
  static void testExceptions() {
    Test.startTest();
    Boolean submitCaught = false;
    try {
      QuoteApprovalController.submitForApproval(null, 'Testing Exception');
    } catch (Exception e) {
      System.debug('submitCaught exception: ' + e.getMessage() + ' type: ' + e.getTypeName());
      submitCaught = true;
    }
    System.assert(submitCaught, 'Submit should throw exception on null id');

    Boolean processCaught = false;
    try {
      QuoteApprovalController.processApprovalAction(null, 'Approve', 'Testing Exception');
    } catch (Exception e) {
      System.debug('processCaught exception: ' + e.getMessage() + ' type: ' + e.getTypeName());
      processCaught = true;
    }
    System.assert(processCaught, 'Process should throw exception on null id');
    Test.stopTest();
  }

}

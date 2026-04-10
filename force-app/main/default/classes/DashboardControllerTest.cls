@isTest
private class DashboardControllerTest {
  @testSetup
  static void setup() {
    Account acc = TestDataFactory.createAccount(
      'Test Account',
      'Customer',
      'Technology'
    );
    Opportunity opp = TestDataFactory.createOpportunity(
      'Test Opp',
      acc.Id,
      Date.today().addDays(30)
    );
    Quote draftQ = TestDataFactory.createQuote('Draft Quote', opp.Id, 'Draft');
    Quote pendingQ = TestDataFactory.createQuote('Pending Quote', opp.Id, 'Draft');
    Quote acceptedQ = TestDataFactory.createQuote('Accepted Quote', opp.Id, 'Draft');

    // Create a product to give the quotes value, bypassing Cannot_Submit_Zero_Value
    Map<String, Id> prodIds = TestDataFactory.createProduct('Test Product');
    
    // Add value to quotes
    TestDataFactory.createQuoteLineItems(pendingQ.Id, prodIds.get('pricebookEntryId'), prodIds.get('productId'), 1);
    TestDataFactory.createQuoteLineItems(acceptedQ.Id, prodIds.get('pricebookEntryId'), prodIds.get('productId'), 1);

    // Update statuses safely
    pendingQ.Status = 'Pending Approval';
    acceptedQ.Status = 'Accepted';
    update new List<Quote>{ pendingQ, acceptedQ };
  }

  @isTest
  static void testGetQuoteInsights() {
    Test.startTest();
    Map<String, Object> insights = DashboardController.getQuoteInsights();
    Test.stopTest();

    System.assertNotEquals(null, insights, 'Insights should not be null');
    System.assertEquals(
      3,
      (Integer) insights.get('totalQuotes'),
      'Should count all 3 quotes'
    );
    System.assertNotEquals(
      null,
      insights.get('awaitingApproval'),
      'awaitingApproval key should exist'
    );
    System.assertNotEquals(
      null,
      insights.get('draftPipeline'),
      'draftPipeline key should exist'
    );
  }

  @isTest
  static void testGetRecentQuotes() {
    Test.startTest();
    List<Quote> recent = DashboardController.getRecentQuotes();
    Test.stopTest();
    System.assertEquals(3, recent.size(), 'Should return 3 recent quotes');
  }

  @isTest
  static void testGetQuotesByStatus() {
    Test.startTest();
    List<Map<String, Object>> byStatus = DashboardController.getQuotesByStatus();
    Test.stopTest();
    System.assert(
      byStatus.size() > 0,
      'Should return at least one status group'
    );
  }

  @isTest
  static void testGetMonthlyRevenue() {
    // Accepted quote was created this month so it should appear
    Test.startTest();
    List<Map<String, Object>> monthly = DashboardController.getMonthlyRevenue();
    Test.stopTest();
    System.assertEquals(
      1,
      monthly.size(),
      'Should have 1 month entry for the Accepted quote'
    );
  }

  @isTest
  static void testInsightsWithNoData() {
    // Delete everything to test empty-state handling
    delete [SELECT Id FROM Quote];
    Test.startTest();
    Map<String, Object> insights = DashboardController.getQuoteInsights();
    Test.stopTest();
    System.assertEquals(
      0,
      (Integer) insights.get('totalQuotes'),
      'Should be zero with no quotes'
    );
  }
}

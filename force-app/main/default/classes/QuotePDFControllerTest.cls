@isTest
private class QuotePDFControllerTest {
  @testSetup
  static void setup() {
    Account acc = TestDataFactory.createAccount(
      'PDF Test Account',
      'Customer',
      'Technology'
    );
    Opportunity opp = TestDataFactory.createOpportunity(
      'PDF Test Opp',
      acc.Id,
      Date.today().addDays(30)
    );
    Quote q = TestDataFactory.createQuote('PDF Test Quote', opp.Id, 'Draft');

    Map<String, Id> productData = TestDataFactory.createProduct(
      'PDF Test Product'
    );
    insert new QuoteLineItem(
      QuoteId = q.Id,
      PricebookEntryId = productData.get('pricebookEntryId'),
      Product2Id = productData.get('productId'),
      Quantity = 5,
      UnitPrice = 200,
      Cost__c = 200,
      Item_Type__c = 'Product'
    );
  }

  @isTest
  static void testGeneratePDF() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'PDF Test Quote' LIMIT 1];

    Test.startTest();
    Quote_PDF_Version__c v = QuotePDFController.generatePDF(q.Id);
    Test.stopTest();

    System.assertNotEquals(null, v.Id, 'PDF Version record should be created');
    System.assertEquals(1, v.Version_Number__c, 'First version should be 1');
    System.assertNotEquals(
      null,
      v.Content_Document_Id__c,
      'Should have a ContentDocumentId'
    );
    System.assertNotEquals(
      null,
      v.Content_Version_Id__c,
      'Should have a ContentVersionId'
    );
  }

  @isTest
  static void testGenerateMultiplePDFs() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'PDF Test Quote' LIMIT 1];

    Test.startTest();
    Quote_PDF_Version__c v1 = QuotePDFController.generatePDF(q.Id);
    Quote_PDF_Version__c v2 = QuotePDFController.generatePDF(q.Id);
    Test.stopTest();

    System.assertEquals(1, v1.Version_Number__c, 'First version should be 1');
    System.assertEquals(2, v2.Version_Number__c, 'Second version should be 2');
  }

  @isTest
  static void testGetPDFVersions() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'PDF Test Quote' LIMIT 1];
    QuotePDFController.generatePDF(q.Id);

    Test.startTest();
    List<Map<String, Object>> versions = QuotePDFController.getPDFVersions(
      q.Id
    );
    Test.stopTest();

    System.assertEquals(1, versions.size(), 'Should return 1 version');
    System.assertEquals(
      true,
      versions[0].get('isLatest'),
      'Single version should be latest'
    );
  }

  @isTest
  static void testDeletePDFVersion() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'PDF Test Quote' LIMIT 1];
    Quote_PDF_Version__c v = QuotePDFController.generatePDF(q.Id);

    Test.startTest();
    QuotePDFController.deletePDFVersion(v.Id);
    Test.stopTest();

    System.assertEquals(
      0,
      [SELECT COUNT() FROM Quote_PDF_Version__c WHERE Id = :v.Id],
      'PDF Version should be deleted'
    );
  }

  @isTest
  static void testVFControllerConstructor() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'PDF Test Quote' LIMIT 1];

    Test.startTest();
    PageReference pageRef = Page.QuotePDFTemplate;
    pageRef.getParameters().put('quoteId', q.Id);
    Test.setCurrentPage(pageRef);

    QuotePDFController controller = new QuotePDFController();
    Test.stopTest();

    System.assertNotEquals(null, controller.quote, 'Quote should be loaded');
    System.assertEquals(
      q.Id,
      controller.quote.Id,
      'Correct quote should be loaded'
    );
    System.assertNotEquals(
      null,
      controller.lineItems,
      'Line items should be loaded'
    );
  }

  @isTest
  static void testConstructorWithEmptyId() {
    Test.startTest();
    Test.setCurrentPage(Page.QuotePDFTemplate); // No ID param
    QuotePDFController controller = new QuotePDFController();
    Test.stopTest();
    System.assertEquals(null, controller.quote, 'Quote should be null for empty ID');
  }

  @isTest
  static void testFinancialComputations() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'PDF Test Quote' LIMIT 1];
    
    // For Valid_Until__c, we can update it
    q.Valid_Until__c = Date.today().addDays(7);
    update q;
    
    // For Total_Cost__c and Discount_Amount__c, we update line items
    QuoteLineItem item = [SELECT Id, Quantity, UnitPrice FROM QuoteLineItem WHERE QuoteId = :q.Id LIMIT 1];
    item.Cost__c = 200; // item.Quantity is 5, so 5 * 200 = 1000 Total Cost
    item.Discount = 10;
    update item;
    
    // Force a fresh context for the query in the controller
    Test.startTest();
    PageReference pageRef = Page.QuotePDFTemplate;
    pageRef.getParameters().put('quoteId', q.Id);
    Test.setCurrentPage(pageRef);
    QuotePDFController controller = new QuotePDFController();
    Test.stopTest();

    // Verify the financial computation code paths executed
    System.assertNotEquals(null, controller.computedTotalCost, 'Total cost should be computed');
    System.assertNotEquals(null, controller.computedDiscount, 'Discount should be computed');
    System.assertNotEquals(null, controller.computedMargin, 'Margin should be computed');
    System.assertNotEquals(null, controller.computedSubtotal, 'Subtotal should be computed');
    System.assertNotEquals('Not Set', controller.validUntilDisplay, 'Valid until should be displayed');
  }
}

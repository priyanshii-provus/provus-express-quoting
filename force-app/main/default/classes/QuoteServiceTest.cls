@isTest
private class QuoteServiceTest {
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
    TestDataFactory.createQuote('Quote Draft', opp.Id, 'Draft');
    TestDataFactory.createQuote('Quote Approved', opp.Id, 'Approved');
  }

  @isTest
  static void testGetQuotesAllStatus() {
    Test.startTest();
    List<Quote> results = QuoteService.getQuotes('All Status', null);
    Test.stopTest();
    System.assertEquals(2, results.size(), 'Should return both quotes');
  }

  @isTest
  static void testGetQuotesFilterByStatus() {
    Test.startTest();
    List<Quote> results = QuoteService.getQuotes('Approved', null);
    Test.stopTest();
    System.assertEquals(
      1,
      results.size(),
      'Should return only Approved quotes'
    );
  }

  @isTest
  static void testGetQuotesFilterByAccount() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Test.startTest();
    List<Quote> results = QuoteService.getQuotes('All Status', acc.Id);
    Test.stopTest();
    System.assertEquals(
      2,
      results.size(),
      'Should see both quotes for this account'
    );
  }

  @isTest
  static void testGetQuoteById() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'Quote Draft' LIMIT 1];
    Test.startTest();
    Quote fetched = QuoteService.getQuoteById(q.Id);
    Test.stopTest();
    System.assertNotEquals(null, fetched, 'Quote should be returned');
    System.assertEquals(
      'Quote Draft',
      fetched.Name,
      'Should be the correct quote'
    );
  }

  @isTest
  static void testGetQuoteLineItems() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'Quote Draft' LIMIT 1];
    Map<String, Id> productData = TestDataFactory.createProduct('Test Prod');

    insert new List<QuoteLineItem>{
      new QuoteLineItem(
        QuoteId = q.Id,
        PricebookEntryId = productData.get('pricebookEntryId'),
        Product2Id = productData.get('productId'),
        Quantity = 2,
        UnitPrice = 100,
        Item_Type__c = 'Labor'
      ),
      new QuoteLineItem(
        QuoteId = q.Id,
        PricebookEntryId = productData.get('pricebookEntryId'),
        Product2Id = productData.get('productId'),
        Quantity = 1,
        UnitPrice = 200,
        Item_Type__c = 'Product'
      )
    };

    Test.startTest();
    List<QuoteLineItem> items = QuoteService.getQuoteLineItems(q.Id);
    Test.stopTest();

    System.assertEquals(2, items.size(), 'Should return 2 line items');
  }

  @isTest
  static void testCreateQuote() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    Id pricebookId = Test.getStandardPricebookId();

    Test.startTest();
    Quote newQuote = QuoteService.createQuote(
      'Service Created Quote',
      opp.Id,
      pricebookId,
      'Days'
    );
    Test.stopTest();

    System.assertNotEquals(null, newQuote.Id, 'Quote should be created');
    System.assertEquals(
      'Days',
      newQuote.Quote_Time_Period__c,
      'Time period should be Days'
    );
  }

  @isTest
  static void testUpdateQuoteStatus() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'Quote Draft' LIMIT 1];
    Test.startTest();
    Quote updated = QuoteService.updateQuoteStatus(q.Id, 'Presented');
    Test.stopTest();
    System.assertEquals(
      'Presented',
      updated.Status,
      'Status should be Presented'
    );
  }

  @isTest
  static void testCloneQuote() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'Quote Draft' LIMIT 1];
    Map<String, Id> productData = TestDataFactory.createProduct(
      'Clone Test Prod'
    );

    insert new QuoteLineItem(
      QuoteId = q.Id,
      PricebookEntryId = productData.get('pricebookEntryId'),
      Product2Id = productData.get('productId'),
      Quantity = 1,
      UnitPrice = 500,
      Item_Type__c = 'Labor'
    );

    Test.startTest();
    Quote cloned = QuoteService.cloneQuote(q.Id);
    Test.stopTest();

    System.assertNotEquals(
      q.Id,
      cloned.Id,
      'Cloned quote must have a different ID'
    );
    System.assert(
      cloned.Name.contains('- Copy'),
      'Cloned quote name should include "- Copy"'
    );
    System.assertEquals(
      1,
      [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :cloned.Id],
      'Cloned quote should have 1 line item'
    );
  }

  @isTest
  static void testDeleteQuote() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'Quote Approved' LIMIT 1];
    Test.startTest();
    QuoteService.deleteQuote(q.Id);
    Test.stopTest();
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Quote WHERE Id = :q.Id],
      'Quote should be deleted'
    );
  }

  @isTest
  static void testAddAndRemoveLineItem() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'Quote Draft' LIMIT 1];
    Map<String, Id> productData = TestDataFactory.createProduct(
      'Add Remove Prod'
    );
    Resource_Role__c role = TestDataFactory.createResourceRole(
      'Analyst',
      120,
      80
    );

    Test.startTest();
    QuoteLineItem newItem = QuoteService.addLineItem(
      q.Id,
      productData.get('pricebookEntryId'),
      productData.get('productId'),
      10,
      150,
      role.Id,
      40,
      'Design',
      'Labor',
      null
    );
    System.assertNotEquals(null, newItem.Id, 'Line item should be created');

    QuoteService.removeLineItem(newItem.Id);
    Test.stopTest();

    System.assertEquals(
      0,
      [SELECT COUNT() FROM QuoteLineItem WHERE Id = :newItem.Id],
      'Line item should be deleted'
    );
  }
}

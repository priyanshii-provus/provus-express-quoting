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
    // 1. Regular add
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

    // 2. Add with NULL start date (covers Date.today() branch)
    QuoteLineItem itemNullDate = QuoteService.addLineItem(
      q.Id, productData.get('pricebookEntryId'), productData.get('productId'), 1, 100, null, 0, 'P', 'Product', null
    );
    System.assertEquals(Date.today(), itemNullDate.ServiceDate, 'Start Date should default to today');

    QuoteService.removeLineItem(newItem.Id);
    Test.stopTest();

    System.assertEquals(
      0,
      [SELECT COUNT() FROM QuoteLineItem WHERE Id = :newItem.Id],
      'Line item should be deleted'
    );
  }

  @isTest
  static void testAddLineItemAddon() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'Quote Draft' LIMIT 1];
    Add_on__c ao = new Add_on__c(Name='Support', Active__c=true, Price__c=500);
    insert ao;
    
    Test.startTest();
    QuoteLineItem item = QuoteService.addLineItem(
      q.Id, null, null, 1, 0, null, 0, 'Phase 1', 'Add-on', ao.Id
    );
    Test.stopTest();
    
    System.assertNotEquals(null, item.Id);
    System.assertEquals(ao.Id, item.Add_on__c);
  }

  @isTest
  static void testUpdateQuoteFields() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'Quote Draft' LIMIT 1];
    Test.startTest();
    Quote updated = QuoteService.updateQuoteFields(q.Id, 'New Description');
    Test.stopTest();
    System.assertEquals('New Description', updated.Description);
  }

  @isTest
  static void testUpdateLineItems() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'Quote Draft' LIMIT 1];
    Map<String, Id> productData = TestDataFactory.createProduct('UpdateLI');
    QuoteLineItem item = new QuoteLineItem(
      QuoteId = q.Id,
      PricebookEntryId = productData.get('pricebookEntryId'),
      Product2Id = productData.get('productId'),
      Quantity = 1,
      UnitPrice = 100
    );
    insert item;
    
    item.Quantity = 5;
    Test.startTest();
    QuoteService.updateLineItems(new List<QuoteLineItem>{item});
    Test.stopTest();
    
    System.assertEquals(5, [SELECT Quantity FROM QuoteLineItem WHERE Id = :item.Id].Quantity);
  }

  @isTest
  static void testGetOpportunities() {
    Test.startTest();
    List<Opportunity> results = QuoteService.getOpportunities();
    Test.stopTest();
    System.assert(results.size() > 0, 'Should return opportunities');
  }

  @isTest
  static void testAddLineItemPricebookFallback() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    // Create quote with NO pricebook
    Quote q = new Quote(Name = 'No PB Quote', OpportunityId = opp.Id);
    insert q;

    Map<String, Id> productData = TestDataFactory.createProduct('Fallback Prod');
    PricebookEntry pbe = [SELECT Id, Pricebook2Id FROM PricebookEntry WHERE Id = :productData.get('pricebookEntryId')];

    Test.startTest();
    // 1. Providing PBE when Quote PB is null should force the Quote to adopt its Pricebook
    QuoteLineItem item1 = QuoteService.addLineItem(
      q.Id, pbe.Id, productData.get('productId'), 1, 100, null, 0, 'Phase', 'Product', null
    );
    
    // 2. Providing null PBE and null Quote PB should trigger standard pricebook fallback
    Quote q2 = new Quote(Name = 'Standard Fallback Quote', OpportunityId = opp.Id);
    insert q2;
    // itemType='Labor' triggers placeholder logic but also PB search
    QuoteLineItem item2 = QuoteService.addLineItem(
      q2.Id, null, null, 1, 100, null, 160, 'Phase', 'Labor', null
    );
    Test.stopTest();

    Quote updated = [SELECT Pricebook2Id FROM Quote WHERE Id = :q.Id];
    System.assertEquals(pbe.Pricebook2Id, updated.Pricebook2Id, 'Quote should have adopted Pricebook from PBE');
    System.assertNotEquals(null, item1.Id);
    
    Quote updated2 = [SELECT Pricebook2Id FROM Quote WHERE Id = :q2.Id];
    System.assertNotEquals(null, updated2.Pricebook2Id, 'Quote should have adopted Standard Pricebook');
  }

  @isTest
  static void testAddLineItemPlaceholderCreation() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'Quote Draft' LIMIT 1];
    
    // Ensure placeholder does not exist
    List<Product2> existing = [SELECT Id FROM Product2 WHERE Name = 'Resource Placeholder'];
    if (!existing.isEmpty()) {
       // We can't delete products easily if they have PBEs, but we can rename them to "hide" them from the query
       for (Product2 p : existing) {
           p.Name = 'Old Placeholder ' + p.Id;
       }
       update existing;
    }

    Test.startTest();
    // This should trigger creation of 'Resource Placeholder' and a PBE in the Standard Pricebook
    QuoteLineItem item = QuoteService.addLineItem(
      q.Id, null, null, 10, 200, null, 160, 'Design', 'Labor', null
    );
    Test.stopTest();

    System.assertNotEquals(null, item.Id);
    Product2 createdProd = [SELECT Id FROM Product2 WHERE Name = 'Resource Placeholder' LIMIT 1];
    System.assertEquals(createdProd.Id, item.Product2Id);
  }
}

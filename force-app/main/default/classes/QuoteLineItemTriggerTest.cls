@isTest
private class QuoteLineItemTriggerTest {
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
    TestDataFactory.createResourceRole('Developer', 150.0, 100.0);
  }

  @isTest
  static void testCostAutoPopulatedFromResourceRole() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    Quote quote = TestDataFactory.createQuote(
      'Cost Test Quote',
      opp.Id,
      'Draft'
    );
    Map<String, Id> productData = TestDataFactory.createProduct('Test Prod');
    Resource_Role__c role = [SELECT Id FROM Resource_Role__c LIMIT 1];

    Test.startTest();
    QuoteLineItem item = new QuoteLineItem(
      QuoteId = quote.Id,
      PricebookEntryId = productData.get('pricebookEntryId'),
      Product2Id = productData.get('productId'),
      Quantity = 5,
      Resource_Role__c = role.Id,
      Item_Type__c = 'Labor',
      Phase__c = 'Development'
      // Deliberately omit UnitPrice so trigger sets it from the role
    );
    insert item;
    Test.stopTest();

    QuoteLineItem result = [
      SELECT Id, Cost__c, UnitPrice
      FROM QuoteLineItem
      WHERE Id = :item.Id
    ];
    System.assertEquals(
      100.0,
      result.Cost__c,
      'Cost__c should be set from the Resource Role'
    );
    System.assertEquals(
      150.0,
      result.UnitPrice,
      'UnitPrice should be set from the Resource Role price'
    );
  }

  @isTest
  static void testCostNotOverriddenWhenUnitPriceExists() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    Quote quote = TestDataFactory.createQuote(
      'Override Test Quote',
      opp.Id,
      'Draft'
    );
    Map<String, Id> productData = TestDataFactory.createProduct('Test Prod 2');
    Resource_Role__c role = [SELECT Id FROM Resource_Role__c LIMIT 1];

    Test.startTest();
    QuoteLineItem item = new QuoteLineItem(
      QuoteId = quote.Id,
      PricebookEntryId = productData.get('pricebookEntryId'),
      Product2Id = productData.get('productId'),
      Quantity = 1,
      UnitPrice = 200.0, // explicitly set — should NOT be replaced
      Resource_Role__c = role.Id,
      Item_Type__c = 'Labor'
    );
    insert item;
    Test.stopTest();

    QuoteLineItem result = [
      SELECT UnitPrice
      FROM QuoteLineItem
      WHERE Id = :item.Id
    ];
    System.assertEquals(
      200.0,
      result.UnitPrice,
      'UnitPrice should NOT be overwritten if already set'
    );
  }

  @isTest
  static void testRollupToQuote() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    Quote quote = TestDataFactory.createQuote(
      'Rollup Test Quote',
      opp.Id,
      'Draft'
    );
    Map<String, Id> productData = TestDataFactory.createProduct('Rollup Prod');
    Id pbeId = productData.get('pricebookEntryId');
    Id prod2Id = productData.get('productId');

    Test.startTest();
    insert new List<QuoteLineItem>{
      new QuoteLineItem(
        QuoteId = quote.Id,
        PricebookEntryId = pbeId,
        Product2Id = prod2Id,
        Quantity = 2,
        UnitPrice = 100,
        Cost__c = 50,
        Item_Type__c = 'Labor'
      ),
      new QuoteLineItem(
        QuoteId = quote.Id,
        PricebookEntryId = pbeId,
        Product2Id = prod2Id,
        Quantity = 1,
        UnitPrice = 500,
        Cost__c = 300,
        Item_Type__c = 'Product'
      ),
      new QuoteLineItem(
        QuoteId = quote.Id,
        PricebookEntryId = pbeId,
        Product2Id = prod2Id,
        Quantity = 3,
        UnitPrice = 50,
        Cost__c = 20,
        Item_Type__c = 'Add-on'
      )
    };
    Test.stopTest();

    Quote updatedQuote = [
      SELECT
        Labor_Revenue__c,
        Products_Revenue__c,
        Addons_Revenue__c,
        Total_Cost__c
      FROM Quote
      WHERE Id = :quote.Id
    ];
    System.assertEquals(
      200.0,
      updatedQuote.Labor_Revenue__c,
      'Labor Revenue should be 200'
    );
    System.assertEquals(
      500.0,
      updatedQuote.Products_Revenue__c,
      'Products Revenue should be 500'
    );
    System.assertEquals(
      150.0,
      updatedQuote.Addons_Revenue__c,
      'Addons Revenue should be 150'
    );
    // Total cost = (2*50) + (1*300) + (3*20) = 100 + 300 + 60 = 460
    System.assertEquals(
      460.0,
      updatedQuote.Total_Cost__c,
      'Total Cost should be 460'
    );
  }

  @isTest
  static void testLineItemUpdate() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    Quote quote = TestDataFactory.createQuote(
      'Update Test Quote',
      opp.Id,
      'Draft'
    );
    Map<String, Id> productData = TestDataFactory.createProduct('Update Prod');
    Resource_Role__c role = [SELECT Id FROM Resource_Role__c LIMIT 1];

    QuoteLineItem item = new QuoteLineItem(
      QuoteId = quote.Id,
      PricebookEntryId = productData.get('pricebookEntryId'),
      Product2Id = productData.get('productId'),
      Quantity = 1,
      UnitPrice = 200,
      Item_Type__c = 'Product'
    );
    insert item;

    Test.startTest();
    item.Resource_Role__c = role.Id;
    item.UnitPrice = 200; // Keep existing price
    update item;
    Test.stopTest();

    QuoteLineItem result = [
      SELECT Cost__c
      FROM QuoteLineItem
      WHERE Id = :item.Id
    ];
    System.assertEquals(
      100.0,
      result.Cost__c,
      'Cost should be from Resource Role on update'
    );
  }

  @isTest
  static void testBulkInsert200LineItems() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    Quote quote = TestDataFactory.createQuote('Bulk LI Quote', opp.Id, 'Draft');
    Map<String, Id> productData = TestDataFactory.createProduct('Bulk Prod');
    Id pbeId = productData.get('pricebookEntryId');
    Id prod2Id = productData.get('productId');

    List<QuoteLineItem> items = new List<QuoteLineItem>();
    for (Integer i = 0; i < 200; i++) {
      items.add(
        new QuoteLineItem(
          QuoteId = quote.Id,
          PricebookEntryId = pbeId,
          Product2Id = prod2Id,
          Quantity = 1,
          UnitPrice = 100,
          Cost__c = 80,
          Item_Type__c = (Math.mod(i, 2) == 0) ? 'Labor' : 'Product'
        )
      );
    }

    Test.startTest();
    insert items;
    Test.stopTest();

    System.assertEquals(
      200,
      [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :quote.Id],
      '200 line items should be inserted'
    );
    Quote q = [SELECT Total_Cost__c FROM Quote WHERE Id = :quote.Id];
    System.assertEquals(
      16000.0,
      q.Total_Cost__c,
      'Total Cost should be 200 * 80 = 16000'
    );
  }
}

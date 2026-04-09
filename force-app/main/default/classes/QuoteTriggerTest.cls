@isTest
private class QuoteTriggerTest {
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
    // Store the opp so tests can query it
  }

  @isTest
  static void testQuoteInsertDefaults() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

    Test.startTest();
    Quote quote = TestDataFactory.createQuote('Test Quote', opp.Id, 'Draft');
    Test.stopTest();

    Quote result = [
      SELECT Id, Quote_Time_Period__c, Valid_Until__c
      FROM Quote
      WHERE Id = :quote.Id
    ];
    System.assertEquals(
      'Months',
      result.Quote_Time_Period__c,
      'Default time period should be Months'
    );
    System.assertNotEquals(
      null,
      result.Valid_Until__c,
      'Valid Until should be auto-set on insert'
    );
  }

  @isTest
  static void testQuoteMarginCalculation() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    Quote quote = TestDataFactory.createQuote('Test Quote', opp.Id, 'Draft');

    // Create a product + pricebook entry using the factory (uses Test.getStandardPricebookId)
    Map<String, Id> productData = TestDataFactory.createProduct('Test Prod');

    // Insert a line item to give TotalPrice = 10000
    QuoteLineItem item = new QuoteLineItem(
      QuoteId = quote.Id,
      PricebookEntryId = productData.get('pricebookEntryId'),
      Product2Id = productData.get('productId'),
      Quantity = 1,
      UnitPrice = 10000,
      Item_Type__c = 'Labor'
    );
    insert item;

    // Reload quote to get the TotalPrice set by Salesforce
    quote = [
      SELECT Id, TotalPrice, Pricebook2Id
      FROM Quote
      WHERE Id = :quote.Id
    ];

    Test.startTest();
    // Now update Total_Cost__c to kick the trigger's margin calculation
    quote.Total_Cost__c = 6000;
    update quote;
    Test.stopTest();

    Quote result = [
      SELECT Id, Margin_Percentage__c
      FROM Quote
      WHERE Id = :quote.Id
    ];
    System.assertEquals(
      40.0,
      result.Margin_Percentage__c,
      'Margin should be 40%'
    );
  }

  @isTest
  static void testBulkQuoteInsert() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    Id pricebookId = Test.getStandardPricebookId();

    List<Quote> quotes = new List<Quote>();
    for (Integer i = 0; i < 200; i++) {
      quotes.add(
        new Quote(
          Name = 'Bulk Quote ' + i,
          OpportunityId = opp.Id,
          Pricebook2Id = pricebookId,
          Status = 'Draft'
        )
      );
    }

    Test.startTest();
    insert quotes;
    Test.stopTest();

    Integer count = [SELECT COUNT() FROM Quote];
    System.assertEquals(200, count, 'Should insert 200 quotes');
  }

  @isTest
  static void testQuoteDefaultsNotOverwritten() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    Id pricebookId = Test.getStandardPricebookId();
    Date customDate = Date.today().addMonths(3);

    Test.startTest();
    Quote quote = new Quote(
      Name = 'Custom Defaults',
      OpportunityId = opp.Id,
      Pricebook2Id = pricebookId,
      Status = 'Draft',
      Quote_Time_Period__c = 'Days',
      Valid_Until__c = customDate
    );
    insert quote;
    Test.stopTest();

    Quote result = [
      SELECT Quote_Time_Period__c, Valid_Until__c
      FROM Quote
      WHERE Id = :quote.Id
    ];
    System.assertEquals(
      'Days',
      result.Quote_Time_Period__c,
      'Custom time period should not be overwritten'
    );
    System.assertEquals(
      customDate,
      result.Valid_Until__c,
      'Custom Valid Until should not be overwritten'
    );
  }

  @isTest
  static void testQuoteMarginCalculationZeroTotal() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    Quote quote = TestDataFactory.createQuote(
      'Test Zero Price',
      opp.Id,
      'Draft'
    );

    Map<String, Id> productData = TestDataFactory.createProduct(
      'Test Free Prod'
    );

    QuoteLineItem item = new QuoteLineItem(
      QuoteId = quote.Id,
      PricebookEntryId = productData.get('pricebookEntryId'),
      Product2Id = productData.get('productId'),
      Quantity = 1,
      UnitPrice = 0,
      Item_Type__c = 'Labor'
    );
    insert item;

    quote = [
      SELECT Id, TotalPrice, Pricebook2Id
      FROM Quote
      WHERE Id = :quote.Id
    ];

    Test.startTest();
    quote.Total_Cost__c = 5000;
    update quote;
    Test.stopTest();

    Quote result = [
      SELECT Id, Margin_Percentage__c
      FROM Quote
      WHERE Id = :quote.Id
    ];
    System.assertEquals(
      0,
      result.Margin_Percentage__c,
      'Margin should be 0 when total price is 0'
    );
  }
}

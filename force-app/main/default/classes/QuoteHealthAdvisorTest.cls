@isTest
private class QuoteHealthAdvisorTest {
  @testSetup
  static void setup() {
    Account acc = TestDataFactory.createAccount('Test Account', 'Customer', 'Technology');
    Opportunity opp = TestDataFactory.createOpportunity('Test Opp', acc.Id, Date.today().addDays(30));
    
    Map<String, Id> prodData = TestDataFactory.createProduct('Test Product');
    Resource_Role__c role = TestDataFactory.createResourceRole('Developer', 200, 100);
    
    // ── Quote 1: Healthy ──
    // High margin (50%), good labor ratio, has start date
    Quote q1 = TestDataFactory.createQuote('Healthy Quote', opp.Id, 'Draft');
    q1.Start_Date__c = Date.today();
    update q1;

    QuoteLineItem labor = new QuoteLineItem(
      QuoteId = q1.Id,
      PricebookEntryId = prodData.get('pricebookEntryId'),
      Product2Id = prodData.get('productId'),
      Quantity = 1,
      UnitPrice = 32000,
      Cost__c = 16000,
      Resource_Role__c = role.Id,
      Item_Type__c = 'Labor',
      Phase__c = 'Implementation'
    );
    insert labor;

    // ── Quote 2: Critical (Empty) ──
    Quote q2 = TestDataFactory.createQuote('Critical Quote', opp.Id, 'Draft');

    // ── Quote 3: Warning (margin between 10-25%, moderate discount) ──
    Map<String, Id> prodData2 = TestDataFactory.createProduct('Product W');
    Quote q3 = TestDataFactory.createQuote('Warning Quote', opp.Id, 'Draft');
    q3.Start_Date__c = Date.today();
    update q3;

    // Margin = 15% (between MIN_MARGIN 10 and TARGET_MARGIN 25)
    QuoteLineItem warnItem = new QuoteLineItem(
      QuoteId = q3.Id,
      PricebookEntryId = prodData2.get('pricebookEntryId'),
      Product2Id = prodData2.get('productId'),
      Quantity = 1,
      UnitPrice = 1000,
      Cost__c = 850,
      Item_Type__c = 'Product',
      Phase__c = 'Design'
    );
    insert warnItem;
    // Apply a small discount (within safe limits < 20%) to trigger "Discount OK"
    warnItem.Discount = 5;
    update warnItem;

    // ── Quote 4: Low labor ratio (mostly products) ──
    Map<String, Id> prodData3 = TestDataFactory.createProduct('Product LR');
    Quote q4 = TestDataFactory.createQuote('Low Labor Quote', opp.Id, 'Draft');
    q4.Start_Date__c = Date.today();
    update q4;

    // ── Quote 5: Warning Range Quote (Margin 15%, Discount 25%) ──
    // Covers: Rule 1 "Margin Below Target" and Rule 2 "High Discounts" and Status "Warning"
    Map<String, Id> prodData5 = TestDataFactory.createProduct('Product WR');
    // The QuoteLineItemTriggerHandler copies Product2.Cost__c to QuoteLineItem.Cost__c
    update new Product2(Id = prodData5.get('productId'), Cost__c = 637.5);
    
    Quote q5 = TestDataFactory.createQuote('Warning Range Quote', opp.Id, 'Draft');
    q5.Start_Date__c = Date.today();
    update q5;
    QuoteLineItem warnRangeItem = new QuoteLineItem(
      QuoteId = q5.Id,
      PricebookEntryId = prodData5.get('pricebookEntryId'),
      Product2Id = prodData5.get('productId'),
      Quantity = 1,
      UnitPrice = 1000,
      Cost__c = 637.5, // TotalPrice will be 750. Cost is 637.5. Margin is 112.5 (15% of 750)
      Item_Type__c = 'Product',
      Phase__c = 'Design'
    );
    insert warnRangeItem;
    // Discount > MAX_DISCOUNT (20) limits
    warnRangeItem.Discount = 25;
    update warnRangeItem;

    // Insert mostly product revenue with small labor revenue
    // This ensures laborRatio < MIN_LABOR_RATIO (0.30) but laborRevenue > 0
    QuoteLineItem prodItem = new QuoteLineItem(
      QuoteId = q4.Id,
      PricebookEntryId = prodData3.get('pricebookEntryId'),
      Product2Id = prodData3.get('productId'),
      Quantity = 1,
      UnitPrice = 10000,
      Cost__c = 5000,
      Item_Type__c = 'Product',
      Phase__c = 'Phase1'
    );
    insert prodItem;

    // Small labor item (10% of total revenue => < 30% ratio)
    QuoteLineItem smallLabor = new QuoteLineItem(
      QuoteId = q4.Id,
      PricebookEntryId = prodData3.get('pricebookEntryId'),
      Product2Id = prodData3.get('productId'),
      Quantity = 1,
      UnitPrice = 500,
      Cost__c = 250,
      Resource_Role__c = role.Id,
      Item_Type__c = 'Labor',
      Phase__c = 'Phase1'
    );
    insert smallLabor;

    // ── Quote 6: Zero-cost items + single phase + many items ──
    Map<String, Id> prodData4 = TestDataFactory.createProduct('Product ZC');
    Quote q6 = TestDataFactory.createQuote('Zero Cost Quote', opp.Id, 'Draft');
    q6.Start_Date__c = Date.today();
    update q6;

    List<QuoteLineItem> zeroCostItems = new List<QuoteLineItem>();
    for (Integer i = 0; i < 4; i++) {
      zeroCostItems.add(new QuoteLineItem(
        QuoteId = q6.Id,
        PricebookEntryId = prodData4.get('pricebookEntryId'),
        Product2Id = prodData4.get('productId'),
        Quantity = 1,
        UnitPrice = 100,
        Cost__c = (i == 0) ? 50 : 0, // 3 items with zero cost
        Item_Type__c = 'Product',
        Phase__c = 'Same Phase'  // All same phase, >3 items = single phase penalty
      ));
    }
    insert zeroCostItems;
  }

  // ── Test 1: Healthy quote ──
  @isTest
  static void testEvaluateHealthyQuote() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'Healthy Quote' LIMIT 1];
    
    Test.startTest();
    QuoteHealthAdvisor.HealthScore score = QuoteHealthAdvisor.evaluateQuoteHealth(q.Id);
    Test.stopTest();

    System.assert(score.score >= 80, 'Score should be >= 80 for healthy quote. Actual: ' + score.score);
    System.assertEquals('Healthy', score.status, 'Status should be Healthy');
    System.assertEquals('utility:like', score.statusIcon);
    System.assert(score.totalItems > 0, 'Should have line items');

    // Should have "Strong Margin" recommendation
    Boolean foundStrongMargin = false;
    for (QuoteHealthAdvisor.Recommendation r : score.recommendations) {
      if (r.title == 'Strong Margin') foundStrongMargin = true;
    }
    System.assert(foundStrongMargin, 'Should have Strong Margin recommendation');
  }

  // ── Test 2: Critical (empty) quote ──
  @isTest
  static void testEvaluateCriticalQuote() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'Critical Quote' LIMIT 1];
    
    Test.startTest();
    QuoteHealthAdvisor.HealthScore score = QuoteHealthAdvisor.evaluateQuoteHealth(q.Id);
    Test.stopTest();

    System.assert(score.score < 50, 'Score should be < 50 for empty critical quote. Actual: ' + score.score);
    System.assertEquals('Critical', score.status, 'Status should be Critical');
    System.assertEquals('utility:error', score.statusIcon);
    
    Boolean foundEmptyRule = false;
    Boolean foundMissingDate = false;
    for (QuoteHealthAdvisor.Recommendation r : score.recommendations) {
      if (r.title == 'No Line Items') foundEmptyRule = true;
      if (r.title == 'Missing Start Date') foundMissingDate = true;
    }
    System.assert(foundEmptyRule, 'Should have No Line Items recommendation');
    System.assert(foundMissingDate, 'Should have Missing Start Date recommendation');
  }

  // ── Test 3: Warning quote (margin 10-25%, low discount) ──
  // Covers: Rule 1 "Margin Below Target", Rule 2 "Discount OK"
  @isTest
  static void testEvaluateWarningQuote() {
    Quote q = [SELECT Id, Margin_Percentage__c FROM Quote WHERE Name = 'Warning Quote' LIMIT 1];
    System.debug('Warning Quote margin: ' + q.Margin_Percentage__c);

    Test.startTest();
    QuoteHealthAdvisor.HealthScore score = QuoteHealthAdvisor.evaluateQuoteHealth(q.Id);
    Test.stopTest();

    System.assertNotEquals(null, score.score);
    
    // Verify that at least one margin-related recommendation was generated
    Boolean foundMarginRec = false;
    Boolean foundDiscountOk = false;
    for (QuoteHealthAdvisor.Recommendation r : score.recommendations) {
      if (r.title.contains('Margin')) foundMarginRec = true;
      if (r.title == 'Discount OK') foundDiscountOk = true;
    }
    System.assert(foundMarginRec, 'Should have a Margin-related recommendation. MarginPct: ' + score.marginPct);
    System.assert(foundDiscountOk, 'Should have Discount OK recommendation. DiscountPct: ' + score.discountPct);
  }

  @isTest
  static void testEvaluateWarningRange() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'Warning Range Quote' LIMIT 1];

    Test.startTest();
    QuoteHealthAdvisor.HealthScore score = QuoteHealthAdvisor.evaluateQuoteHealth(q.Id);
    Test.stopTest();

    // Verify Warning status (score between 50 and 79)
    System.assertEquals('Warning', score.status, 'Expected Score: 50-79. Actual Score: ' + score.score + ' | MarginPct: ' + score.marginPct + ' | Discount: ' + score.discountPct);
    System.assertEquals('utility:warning', score.statusIcon);

    Boolean foundMarginBelowTarget = false;
    Boolean foundHighDiscount = false;
    for (QuoteHealthAdvisor.Recommendation r : score.recommendations) {
      if (r.title == 'Margin Below Target') foundMarginBelowTarget = true;
      if (r.title == 'High Discounts') foundHighDiscount = true;
    }
    System.assert(foundMarginBelowTarget, 'Should have Margin Below Target recommendation');
    System.assert(foundHighDiscount, 'Should have High Discounts recommendation');
  }

  // ── Test 4: Low labor ratio quote ──
  // Covers: Rule 3 "Need More Services" branch
  @isTest
  static void testEvaluateLowLaborRatio() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'Low Labor Quote' LIMIT 1];

    Test.startTest();
    QuoteHealthAdvisor.HealthScore score = QuoteHealthAdvisor.evaluateQuoteHealth(q.Id);
    Test.stopTest();

    Boolean foundNeedServices = false;
    for (QuoteHealthAdvisor.Recommendation r : score.recommendations) {
      if (r.title == 'Need More Services') foundNeedServices = true;
    }
    System.assert(foundNeedServices, 'Should have Need More Services recommendation. LaborRatio: ' + score.laborRatio);
  }

  // ── Test 5: Zero-cost items + single phase ──
  // Covers: Rule 5 "Missing Costs", Rule 6 "Single Phase"
  @isTest
  static void testEvaluateZeroCostAndSinglePhase() {
    Quote q = [SELECT Id FROM Quote WHERE Name = 'Zero Cost Quote' LIMIT 1];

    Test.startTest();
    QuoteHealthAdvisor.HealthScore score = QuoteHealthAdvisor.evaluateQuoteHealth(q.Id);
    Test.stopTest();

    Boolean foundMissingCosts = false;
    Boolean foundSinglePhase = false;
    for (QuoteHealthAdvisor.Recommendation r : score.recommendations) {
      if (r.title == 'Missing Costs') foundMissingCosts = true;
      if (r.title == 'Single Phase') foundSinglePhase = true;
    }
    System.assert(foundMissingCosts, 'Should have Missing Costs recommendation');
    System.assert(foundSinglePhase, 'Should have Single Phase recommendation (4 items, 1 phase)');
    System.assertEquals(4, score.totalItems, 'Should have 4 line items');
  }

  // ── Test 6: Good services mix (high labor ratio) ──
  // Covers: Rule 3 "Good Services Mix" branch
  @isTest
  static void testEvaluateGoodServicesMix() {
    // The "Healthy Quote" has 100% labor (1 labor item, 0 product items)
    // laborRatio = 1.0 >= IDEAL_LABOR_RATIO (0.60)
    Quote q = [SELECT Id FROM Quote WHERE Name = 'Healthy Quote' LIMIT 1];

    Test.startTest();
    QuoteHealthAdvisor.HealthScore score = QuoteHealthAdvisor.evaluateQuoteHealth(q.Id);
    Test.stopTest();

    Boolean foundGoodMix = false;
    for (QuoteHealthAdvisor.Recommendation r : score.recommendations) {
      if (r.title == 'Good Services Mix') foundGoodMix = true;
    }
    System.assert(foundGoodMix, 'Should have Good Services Mix recommendation. LaborRatio: ' + score.laborRatio);
  }
}

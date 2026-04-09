@isTest
private class ControllersTest {
  @TestSetup
  static void setupTestData() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    Opportunity opp = new Opportunity(
      Name = 'Test Opp',
      AccountId = acc.Id,
      StageName = 'Prospecting',
      CloseDate = Date.today().addMonths(3)
    );
    insert opp;

    // MUST use Test.getStandardPricebookId() — SOQL on Pricebook2 returns no rows in test context
    Id stdPbId = Test.getStandardPricebookId();

    Product2 prod = new Product2(
      Name = 'Test Product',
      IsActive = true,
      ProductCode = 'TP001'
    );
    insert prod;

    PricebookEntry pbe = new PricebookEntry(
      Product2Id = prod.Id,
      Pricebook2Id = stdPbId,
      UnitPrice = 100,
      IsActive = true
    );
    insert pbe;

    Resource_Role__c role = new Resource_Role__c(
      Name = 'Developer',
      Price__c = 150,
      Cost__c = 90,
      Billing_Unit__c = 'Hour',
      Active__c = true,
      Location__c = 'Remote'
    );
    insert role;

    Add_on__c addon = new Add_on__c(
      Name = 'Support Plan',
      Price__c = 500,
      Cost__c = 200,
      Billing_Unit__c = 'Month',
      Active__c = true,
      Description__c = 'Monthly support plan'
    );
    insert addon;

    Quote q = new Quote(
      Name = 'Test Quote',
      OpportunityId = opp.Id,
      Pricebook2Id = stdPbId,
      Status = 'Draft'
    );
    insert q;

    QuoteLineItem item = new QuoteLineItem(
      QuoteId = q.Id,
      PricebookEntryId = pbe.Id,
      Quantity = 5,
      UnitPrice = 150,
      Cost__c = 90,
      Item_Type__c = 'Labor',
      Phase__c = 'Development'
    );
    insert item;
  }

  // ===== QuoteService Tests =====

  @isTest
  static void testGetQuotes() {
    Test.startTest();
    List<Quote> quotes = QuoteService.getQuotes('Draft', null);
    Test.stopTest();
    System.assert(!quotes.isEmpty(), 'Should return quotes');
  }

  @isTest
  static void testGetQuotes_allStatus() {
    Test.startTest();
    List<Quote> quotes = QuoteService.getQuotes('All Status', null);
    Test.stopTest();
    System.assert(!quotes.isEmpty(), 'Should return all quotes');
  }

  @isTest
  static void testGetQuoteById() {
    Quote q = [SELECT Id FROM Quote LIMIT 1];
    Test.startTest();
    Quote result = QuoteService.getQuoteById(q.Id);
    Test.stopTest();
    System.assertEquals(q.Id, result.Id);
  }

  @isTest
  static void testGetQuoteLineItems() {
    Quote q = [SELECT Id FROM Quote LIMIT 1];
    Test.startTest();
    List<QuoteLineItem> items = QuoteService.getQuoteLineItems(q.Id);
    Test.stopTest();
    System.assert(!items.isEmpty(), 'Should return line items');
  }

  @isTest
  static void testCloneQuote() {
    Quote q = [SELECT Id FROM Quote LIMIT 1];
    Test.startTest();
    Quote cloned = QuoteService.cloneQuote(q.Id);
    Test.stopTest();
    System.assertNotEquals(
      q.Id,
      cloned.Id,
      'Cloned quote should have different Id'
    );
  }

  @isTest
  static void testDeleteQuote() {
    Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
    Id stdPbId = Test.getStandardPricebookId();
    Quote q = new Quote(
      Name = 'Delete Me',
      OpportunityId = opp.Id,
      Pricebook2Id = stdPbId,
      Status = 'Draft'
    );
    insert q;

    Test.startTest();
    QuoteService.deleteQuote(q.Id);
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM Quote WHERE Id = :q.Id]);
  }

  @isTest
  static void testRemoveLineItem() {
    QuoteLineItem item = [SELECT Id FROM QuoteLineItem LIMIT 1];
    Test.startTest();
    QuoteService.removeLineItem(item.Id);
    Test.stopTest();
    System.assertEquals(
      0,
      [SELECT COUNT() FROM QuoteLineItem WHERE Id = :item.Id]
    );
  }

  // ===== DashboardController Tests =====

  @isTest
  static void testGetQuoteInsights() {
    Test.startTest();
    Map<String, Object> insights = DashboardController.getQuoteInsights();
    Test.stopTest();
    System.assertNotEquals(null, insights, 'Insights should not be null');
    System.assert(insights.containsKey('draftPipeline'));
    System.assert(insights.containsKey('totalQuotes'));
  }

  @isTest
  static void testGetRecentQuotes() {
    Test.startTest();
    List<Quote> recent = DashboardController.getRecentQuotes();
    Test.stopTest();
    System.assert(!recent.isEmpty(), 'Should return recent quotes');
  }

  @isTest
  static void testGetQuotesByStatus() {
    Test.startTest();
    List<Map<String, Object>> result = DashboardController.getQuotesByStatus();
    Test.stopTest();
    System.assert(!result.isEmpty(), 'Should return status groups');
  }

  @isTest
  static void testGetMonthlyRevenue() {
    Test.startTest();
    List<Map<String, Object>> result = DashboardController.getMonthlyRevenue();
    Test.stopTest();
    // May be empty if no Accepted quotes, but should not throw
    System.assertNotEquals(null, result);
  }

  // ===== ResourceRoleController Tests =====

  @isTest
  static void testGetResourceRoles() {
    Test.startTest();
    List<Resource_Role__c> roles = ResourceRoleController.getResourceRoles(
      true
    );
    Test.stopTest();
    System.assert(!roles.isEmpty(), 'Should return active roles');
  }

  @isTest
  static void testGetResourceRoles_all() {
    Test.startTest();
    List<Resource_Role__c> roles = ResourceRoleController.getResourceRoles(
      false
    );
    Test.stopTest();
    System.assert(!roles.isEmpty());
  }

  @isTest
  static void testCreateResourceRole() {
    Test.startTest();
    Resource_Role__c role = ResourceRoleController.createResourceRole(
      'Architect',
      'Day',
      2000,
      1200,
      'Onsite'
    );
    Test.stopTest();
    System.assertNotEquals(null, role.Id);
  }

  @isTest
  static void testUpdateResourceRole() {
    Resource_Role__c role = [SELECT Id FROM Resource_Role__c LIMIT 1];
    Test.startTest();
    Resource_Role__c updated = ResourceRoleController.updateResourceRole(
      role.Id,
      'Senior Dev',
      'Hour',
      250,
      150,
      'Remote',
      true
    );
    Test.stopTest();
    System.assertEquals('Senior Dev', updated.Name);
  }

  @isTest
  static void testDeleteResourceRole() {
    Resource_Role__c role = ResourceRoleController.createResourceRole(
      'Temp Role',
      'Hour',
      100,
      50,
      'Office'
    );
    Test.startTest();
    ResourceRoleController.deleteResourceRole(role.Id);
    Test.stopTest();
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Resource_Role__c WHERE Id = :role.Id]
    );
  }

  @isTest
  static void testGetMargin() {
    Resource_Role__c role = [SELECT Id FROM Resource_Role__c LIMIT 1];
    Test.startTest();
    Decimal margin = ResourceRoleController.getMargin(role.Id);
    Test.stopTest();
    System.assert(margin > 0, 'Margin should be positive');
  }

  // ===== ProductController Tests =====

  @isTest
  static void testGetProducts() {
    Test.startTest();
    List<Product2> products = ProductController.getProducts(true);
    Test.stopTest();
    System.assert(!products.isEmpty());
  }

  @isTest
  static void testCreateProduct() {
    Test.startTest();
    Product2 prod = ProductController.createProduct(
      'New Prod',
      'NP001',
      'Desc',
      'Hardware',
      0,
      100
    );
    Test.stopTest();
    System.assertNotEquals(null, prod.Id);
  }

  @isTest
  static void testUpdateProduct() {
    Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
    Test.startTest();
    Product2 updated = ProductController.updateProduct(
      prod.Id,
      'Updated Prod',
      'UP001',
      'Updated desc',
      'Software',
      true
    );
    Test.stopTest();
    System.assertEquals('Updated Prod', updated.Name);
  }

  @isTest
  static void testGetPricebookEntries() {
    Test.startTest();
    List<PricebookEntry> entries = ProductController.getPricebookEntries(null);
    Test.stopTest();
    System.assert(!entries.isEmpty());
  }

  // ===== AddonController Tests =====

  @isTest
  static void testGetAddons() {
    Test.startTest();
    List<Add_on__c> addons = AddonController.getAddons(true);
    Test.stopTest();
    System.assert(!addons.isEmpty());
  }

  @isTest
  static void testCreateAddon() {
    Test.startTest();
    Add_on__c addon = AddonController.createAddon(
      'Premium Support',
      1000,
      400,
      'Year',
      'Annual premium support'
    );
    Test.stopTest();
    System.assertNotEquals(null, addon.Id);
  }

  @isTest
  static void testUpdateAddon() {
    Add_on__c addon = [SELECT Id FROM Add_on__c LIMIT 1];
    Test.startTest();
    Add_on__c updated = AddonController.updateAddon(
      addon.Id,
      'Updated Plan',
      600,
      250,
      'Month',
      'Updated desc',
      true
    );
    Test.stopTest();
    System.assertEquals('Updated Plan', updated.Name);
  }

  @isTest
  static void testDeleteAddon() {
    Add_on__c addon = AddonController.createAddon(
      'Temp',
      100,
      50,
      'Each',
      'Temp'
    );
    Test.startTest();
    AddonController.deleteAddon(addon.Id);
    Test.stopTest();
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Add_on__c WHERE Id = :addon.Id]
    );
  }

  @isTest
  static void testGetAddonMargin() {
    Add_on__c addon = [SELECT Id FROM Add_on__c LIMIT 1];
    Test.startTest();
    Decimal margin = AddonController.getAddonMargin(addon.Id);
    Test.stopTest();
    System.assert(margin > 0, 'Margin should be positive');
  }
}

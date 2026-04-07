@isTest
private class QuoteLineItemTriggerHandlerTest {
    
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
        
        // MUST use Test.getStandardPricebookId() — SOQL returns no rows in test context
        Id stdPbId = Test.getStandardPricebookId();
        
        Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
        insert prod;
        
        PricebookEntry pbe = new PricebookEntry(
            Product2Id = prod.Id,
            Pricebook2Id = stdPbId,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;
        
        Resource_Role__c role = new Resource_Role__c(
            Name = 'Senior Developer',
            Price__c = 200,
            Cost__c = 120,
            Billing_Unit__c = 'Hour',
            Active__c = true
        );
        insert role;
        
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = stdPbId
        );
        insert q;
    }
    
    @isTest
    static void testBeforeInsert_populatesCostFromResourceRole() {
        Quote q = [SELECT Id, Pricebook2Id FROM Quote LIMIT 1];
        Resource_Role__c role = [SELECT Id, Cost__c, Price__c FROM Resource_Role__c LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];
        
        QuoteLineItem item = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 10,
            UnitPrice = 200,
            Resource_Role__c = role.Id,
            Item_Type__c = 'Labor'
        );
        
        Test.startTest();
        insert item;
        Test.stopTest();
        
        QuoteLineItem inserted = [SELECT Cost__c FROM QuoteLineItem WHERE Id = :item.Id];
        System.assertEquals(role.Cost__c, inserted.Cost__c, 'Cost should be populated from Resource Role');
    }
    
    @isTest
    static void testAfterInsert_rollsUpToQuote() {
        Quote q = [SELECT Id, Pricebook2Id FROM Quote LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];
        
        QuoteLineItem item = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 100,
            Cost__c = 60,
            Item_Type__c = 'Labor'
        );
        
        Test.startTest();
        insert item;
        Test.stopTest();
        
        Quote updated = [SELECT Labor_Revenue__c, Total_Cost__c FROM Quote WHERE Id = :q.Id];
        System.assertNotEquals(null, updated.Labor_Revenue__c, 'Labor revenue should be rolled up');
        System.assertNotEquals(null, updated.Total_Cost__c, 'Total cost should be rolled up');
    }
    
    @isTest
    static void testAfterDelete_rollsUpToQuote() {
        Quote q = [SELECT Id, Pricebook2Id FROM Quote LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];
        
        QuoteLineItem item = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 100,
            Cost__c = 60,
            Item_Type__c = 'Product'
        );
        insert item;
        
        Test.startTest();
        delete item;
        Test.stopTest();
        
        Quote updated = [SELECT Products_Revenue__c, Total_Cost__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals(0, updated.Total_Cost__c, 'Total cost should be 0 after delete');
    }
}

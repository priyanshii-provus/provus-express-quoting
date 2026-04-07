@isTest
private class QuoteTriggerHandlerTest {
    
    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addMonths(3)
        );
        insert opp;
    }
    
    @isTest
    static void testBeforeInsert_setsDefaults() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id
        );
        
        Test.startTest();
        insert q;
        Test.stopTest();
        
        Quote inserted = [SELECT Quote_Time_Period__c, Valid_Until__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('Months', inserted.Quote_Time_Period__c, 'Default time period should be Months');
        System.assertNotEquals(null, inserted.Valid_Until__c, 'Valid Until should be set');
    }
    
    @isTest
    static void testBeforeInsert_respectsExistingValues() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Date customDate = Date.today().addMonths(6);
        Quote q = new Quote(
            Name = 'Custom Quote',
            OpportunityId = opp.Id,
            Quote_Time_Period__c = 'Years',
            Valid_Until__c = customDate
        );
        
        Test.startTest();
        insert q;
        Test.stopTest();
        
        Quote inserted = [SELECT Quote_Time_Period__c, Valid_Until__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('Years', inserted.Quote_Time_Period__c, 'Should keep custom time period');
        System.assertEquals(customDate, inserted.Valid_Until__c, 'Should keep custom date');
    }
    
    @isTest
    static void testBeforeUpdate_calculatesMargins() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Quote q = new Quote(
            Name = 'Margin Test Quote',
            OpportunityId = opp.Id,
            Total_Cost__c = 5000
        );
        insert q;
        
        Test.startTest();
        q.Total_Cost__c = 7000;
        update q;
        Test.stopTest();
        
        Quote updated = [SELECT Margin_Percentage__c FROM Quote WHERE Id = :q.Id];
        // Margin percentage should be calculated
        System.assertNotEquals(null, updated.Margin_Percentage__c);
    }
    
    @isTest
    static void testDirectHandlerCallForNullTimePeriod() {
        // Create an in-memory quote to bypass platform default assignment during INSERT
        Quote q = new Quote(Name = 'Memory Quote');
        System.assertEquals(null, q.Quote_Time_Period__c, 'Initially null');
        
        QuoteTriggerHandler handler = new QuoteTriggerHandler();
        handler.beforeInsert(new List<Quote>{q});
        
        System.assertEquals('Months', q.Quote_Time_Period__c, 'Time period should be defaulted by Trigger logic');
    }
}

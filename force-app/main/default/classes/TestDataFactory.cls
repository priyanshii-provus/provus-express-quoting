@isTest
public class TestDataFactory {
    
    public static Account createAccount(String name, String type, String industry) {
        Account acc = new Account(
            Name = name,
            Type = type,
            Industry = industry
        );
        insert acc;
        return acc;
    }
    
    public static Opportunity createOpportunity(String name, Id accountId, Date closeDate) {
        Opportunity opp = new Opportunity(
            Name = name,
            AccountId = accountId,
            CloseDate = closeDate,
            StageName = 'Qualification'
        );
        insert opp;
        return opp;
    }
    
    /**
     * Creates a Quote using the correct test-context pricebook ID.
     * IMPORTANT: In Apex tests you MUST use Test.getStandardPricebookId()
     * to retrieve the standard pricebook — SOQL on Pricebook2 returns no rows.
     */
    public static Quote createQuote(String name, Id opportunityId, String status) {
        Id pricebookId = Test.getStandardPricebookId();
        
        Quote quote = new Quote(
            Name = name,
            OpportunityId = opportunityId,
            Pricebook2Id = pricebookId,
            Status = status
        );
        insert quote;
        return quote;
    }
    
    /**
     * Creates a standard Product2 + PricebookEntry in the test pricebook.
     * Returns both objects wrapped in a simple container map.
     */
    public static Map<String, Id> createProduct(String productName) {
        Id pricebookId = Test.getStandardPricebookId();
        
        Product2 prod = new Product2(Name = productName, IsActive = true);
        insert prod;
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;
        
        return new Map<String, Id>{
            'productId' => prod.Id,
            'pricebookEntryId' => pbe.Id,
            'pricebookId' => pricebookId
        };
    }
    
    public static Resource_Role__c createResourceRole(String name, Decimal price, Decimal cost) {
        Resource_Role__c role = new Resource_Role__c(
            Name = name,
            Price__c = price,
            Cost__c = cost,
            Billing_Unit__c = 'Hour',
            Active__c = true
        );
        insert role;
        return role;
    }
    
    /**
     * Creates QuoteLineItems. Requires a valid PricebookEntry created via createProduct().
     */
    public static List<QuoteLineItem> createQuoteLineItems(Id quoteId, Id pricebookEntryId, Id product2Id, Integer count) {
        List<QuoteLineItem> items = new List<QuoteLineItem>();
        for (Integer i = 0; i < count; i++) {
            items.add(new QuoteLineItem(
                QuoteId = quoteId,
                PricebookEntryId = pricebookEntryId,
                Product2Id = product2Id,
                Quantity = 10,
                UnitPrice = 100 + i,
                Item_Type__c = 'Labor',
                Phase__c = 'Development'
            ));
        }
        insert items;
        return items;
    }
}

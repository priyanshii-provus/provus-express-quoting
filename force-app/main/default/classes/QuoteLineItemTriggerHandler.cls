public with sharing class QuoteLineItemTriggerHandler {
    
    public void beforeInsert(List<QuoteLineItem> newItems) {
        calculateCosts(newItems);
    }
    
    public void beforeUpdate(List<QuoteLineItem> newItems, Map<Id, QuoteLineItem> oldMap) {
        calculateCosts(newItems);
    }
    
    public void rollupToQuote(Set<Id> quoteIds) {
        Map<Id, Decimal> laborRevenueMap = new Map<Id, Decimal>();
        Map<Id, Decimal> productRevenueMap = new Map<Id, Decimal>();
        Map<Id, Decimal> addonRevenueMap = new Map<Id, Decimal>();
        Map<Id, Decimal> totalCostMap = new Map<Id, Decimal>();
        
        // Initialize all maps with zero for every quoteId
        for (Id qId : quoteIds) {
            laborRevenueMap.put(qId, 0);
            productRevenueMap.put(qId, 0);
            addonRevenueMap.put(qId, 0);
            totalCostMap.put(qId, 0);
        }
        
        for (QuoteLineItem item : [SELECT QuoteId, Item_Type__c, TotalPrice, 
                                    Cost__c, Quantity 
                                    FROM QuoteLineItem 
                                    WHERE QuoteId IN :quoteIds]) {
            
            Decimal lineCost = (item.Cost__c != null ? item.Cost__c : 0) * 
                               (item.Quantity != null ? item.Quantity : 0);
            Decimal lineRevenue = item.TotalPrice != null ? item.TotalPrice : 0;
            
            totalCostMap.put(item.QuoteId, totalCostMap.get(item.QuoteId) + lineCost);
            
            if (item.Item_Type__c == 'Labor') {
                laborRevenueMap.put(item.QuoteId, 
                    laborRevenueMap.get(item.QuoteId) + lineRevenue);
            } else if (item.Item_Type__c == 'Product') {
                productRevenueMap.put(item.QuoteId, 
                    productRevenueMap.get(item.QuoteId) + lineRevenue);
            } else if (item.Item_Type__c == 'Add-on') {
                addonRevenueMap.put(item.QuoteId, 
                    addonRevenueMap.get(item.QuoteId) + lineRevenue);
            }
        }
        
        List<Quote> quotesToUpdate = new List<Quote>();
        for (Id quoteId : quoteIds) {
            Quote q = new Quote(Id = quoteId);
            q.Labor_Revenue__c = laborRevenueMap.get(quoteId);
            q.Products_Revenue__c = productRevenueMap.get(quoteId);
            q.Addons_Revenue__c = addonRevenueMap.get(quoteId);
            q.Total_Cost__c = totalCostMap.get(quoteId);
            quotesToUpdate.add(q);
        }
        
        if (!quotesToUpdate.isEmpty()) {
            update quotesToUpdate;
        }
    }
    
    private void calculateCosts(List<QuoteLineItem> items) {
        Set<Id> resourceRoleIds = new Set<Id>();
        
        for (QuoteLineItem item : items) {
            if (item.Resource_Role__c != null) {
                resourceRoleIds.add(item.Resource_Role__c);
            }
        }
        
        if (resourceRoleIds.isEmpty()) {
            return;
        }
        
        Map<Id, Resource_Role__c> resourceMap = new Map<Id, Resource_Role__c>(
            [SELECT Id, Cost__c, Price__c FROM Resource_Role__c 
             WHERE Id IN :resourceRoleIds]
        );
        
        for (QuoteLineItem item : items) {
            if (item.Resource_Role__c != null && resourceMap.containsKey(item.Resource_Role__c)) {
                Resource_Role__c resource = resourceMap.get(item.Resource_Role__c);
                item.Cost__c = resource.Cost__c;
                if (item.UnitPrice == null || item.UnitPrice == 0) {
                    item.UnitPrice = resource.Price__c;
                }
            }
        }
    }
}

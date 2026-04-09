public with sharing class QuoteLineItemTriggerHandler {
  public void beforeInsert(List<QuoteLineItem> newItems) {
    checkQuoteStatus(newItems);
    calculateCosts(newItems);
  }

  public void beforeUpdate(
    List<QuoteLineItem> newItems,
    Map<Id, QuoteLineItem> oldMap
  ) {
    checkQuoteStatus(newItems);
    calculateCosts(newItems);
  }

  public void beforeDelete(List<QuoteLineItem> oldItems) {
    checkQuoteStatus(oldItems);
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

    for (QuoteLineItem item : [
      SELECT QuoteId, Item_Type__c, TotalPrice, Cost__c, Quantity
      FROM QuoteLineItem
      WHERE QuoteId IN :quoteIds
    ]) {
      Decimal lineCost =
        (item.Cost__c != null ? item.Cost__c : 0) *
        (item.Quantity != null ? item.Quantity : 0);
      Decimal lineRevenue = item.TotalPrice != null ? item.TotalPrice : 0;

      totalCostMap.put(item.QuoteId, totalCostMap.get(item.QuoteId) + lineCost);

      if (item.Item_Type__c == 'Labor') {
        laborRevenueMap.put(
          item.QuoteId,
          laborRevenueMap.get(item.QuoteId) + lineRevenue
        );
      } else if (item.Item_Type__c == 'Product') {
        productRevenueMap.put(
          item.QuoteId,
          productRevenueMap.get(item.QuoteId) + lineRevenue
        );
      } else if (item.Item_Type__c == 'Add-on') {
        addonRevenueMap.put(
          item.QuoteId,
          addonRevenueMap.get(item.QuoteId) + lineRevenue
        );
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

  private void checkQuoteStatus(List<QuoteLineItem> items) {
    Set<Id> quoteIds = new Set<Id>();
    for (QuoteLineItem item : items) {
      if (item.QuoteId != null) {
        quoteIds.add(item.QuoteId);
      }
    }

    if (!quoteIds.isEmpty()) {
      Map<Id, Quote> quoteMap = new Map<Id, Quote>(
        [SELECT Id, Status FROM Quote WHERE Id IN :quoteIds]
      );
      for (QuoteLineItem item : items) {
        if (item.QuoteId != null && quoteMap.containsKey(item.QuoteId)) {
          if (quoteMap.get(item.QuoteId).Status == 'Approved') {
            item.addError(
              'You cannot add, edit, or remove line items on an approved quote.'
            );
          }
        }
      }
    }
  }

  private void calculateCosts(List<QuoteLineItem> items) {
    Set<Id> resourceRoleIds = new Set<Id>();
    Set<Id> productIds = new Set<Id>();
    Set<Id> addonIds = new Set<Id>();

    for (QuoteLineItem item : items) {
      if (item.Resource_Role__c != null) {
        resourceRoleIds.add(item.Resource_Role__c);
      } else if (item.Item_Type__c == 'Product' && item.Product2Id != null) {
        productIds.add(item.Product2Id);
      } else if (item.Item_Type__c == 'Add-on' && item.Add_on__c != null) {
        addonIds.add(item.Add_on__c);
      }
    }

    Map<Id, Resource_Role__c> resourceMap = new Map<Id, Resource_Role__c>();
    if (!resourceRoleIds.isEmpty()) {
      resourceMap = new Map<Id, Resource_Role__c>(
        [
          SELECT Id, Cost__c, Price__c
          FROM Resource_Role__c
          WHERE Id IN :resourceRoleIds
        ]
      );
    }

    Map<Id, Product2> productMap = new Map<Id, Product2>();
    if (!productIds.isEmpty()) {
      productMap = new Map<Id, Product2>(
        [SELECT Id, Cost__c FROM Product2 WHERE Id IN :productIds]
      );
    }
    Map<Id, Add_on__c> addonMap = new Map<Id, Add_on__c>();
    if (!addonIds.isEmpty()) {
      addonMap = new Map<Id, Add_on__c>(
        [SELECT Id, Cost__c, Price__c FROM Add_on__c WHERE Id IN :addonIds]
      );
    }

    for (QuoteLineItem item : items) {
      if (
        item.Resource_Role__c != null &&
        resourceMap.containsKey(item.Resource_Role__c)
      ) {
        Resource_Role__c resource = resourceMap.get(item.Resource_Role__c);
        Decimal hours = item.Duration_Hours__c != null
          ? item.Duration_Hours__c
          : 160;
        item.Cost__c =
          (resource.Cost__c != null ? resource.Cost__c : 0) * hours;

        if (item.UnitPrice == null || item.UnitPrice == 0) {
          item.UnitPrice =
            (resource.Price__c != null ? resource.Price__c : 0) * hours;
        }
      } else if (
        item.Item_Type__c == 'Product' &&
        item.Product2Id != null &&
        productMap.containsKey(item.Product2Id)
      ) {
        Product2 prod = productMap.get(item.Product2Id);
        item.Cost__c = prod.Cost__c != null ? prod.Cost__c : 0;
      } else if (
        item.Item_Type__c == 'Add-on' &&
        item.Add_on__c != null &&
        addonMap.containsKey(item.Add_on__c)
      ) {
        Add_on__c addon = addonMap.get(item.Add_on__c);
        item.Cost__c = addon.Cost__c != null ? addon.Cost__c : 0;
        if (item.UnitPrice == null || item.UnitPrice == 0) {
          item.UnitPrice = addon.Price__c != null ? addon.Price__c : 0;
        }
      }
    }
  }
}

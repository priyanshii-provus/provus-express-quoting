/**
 * @description Core service class for Quote operations.
 * Handles the creation, retrieval, and complex updates of Quote and QuoteLineItem records.
 * Uses without sharing due to specific business requirements for Quote access.
 */
public without sharing class QuoteService {
  @AuraEnabled(cacheable=true)
  public static List<Opportunity> getOpportunities() {
    return [SELECT Id, Name FROM Opportunity ORDER BY Name ASC];
  }

  @AuraEnabled(cacheable=true)
  public static List<Quote> getQuotes(String status, Id accountId) {
    String query =
      'SELECT Id, QuoteNumber, Name, Status, TotalPrice, ' +
      'Discount, Margin_Percentage__c, Total_Cost__c, Total_Margin__c, ' +
      'Quote_Time_Period__c, Valid_Until__c, CreatedDate, CreatedBy.Name, ' +
      'Opportunity.Name, Opportunity.Account.Name ' +
      'FROM Quote WHERE Id != null';

    if (String.isNotBlank(status) && status != 'All Status') {
      query += ' AND Status = :status';
    }

    if (accountId != null) {
      query += ' AND Opportunity.AccountId = :accountId';
    }

    query += ' ORDER BY CreatedDate DESC LIMIT 50';

    return Database.query(query);
  }

  @AuraEnabled(cacheable=true)
  public static Quote getQuoteById(Id quoteId) {
    return [
      SELECT
        Id,
        QuoteNumber,
        Name,
        Status,
        TotalPrice,
        Subtotal,
        Discount,
        Valid_Until__c,
        Quote_Time_Period__c,
        Margin_Percentage__c,
        Total_Margin__c,
        Total_Cost__c,
        Discount_Amount__c,
        Line_Discount_Total__c,
        Labor_Revenue__c,
        Products_Revenue__c,
        Addons_Revenue__c,
        Description,
        Start_Date__c,
        End_Date__c,
        OpportunityId,
        Opportunity.Name,
        Opportunity.Account.Name,
        Opportunity.AccountId,
        Pricebook2Id,
        CreatedDate,
        CreatedBy.Name,
        LastModifiedDate,
        LastModifiedBy.Name
      FROM Quote
      WHERE Id = :quoteId
    ];
  }

  @AuraEnabled(cacheable=true)
  public static List<QuoteLineItem> getQuoteLineItems(Id quoteId) {
    return [
      SELECT
        Id,
        QuoteId,
        Product2Id,
        Product2.Name,
        PricebookEntryId,
        Quantity,
        UnitPrice,
        TotalPrice,
        Discount,
        Resource_Role__c,
        Resource_Role__r.Name,
        Duration_Hours__c,
        Phase__c,
        Item_Type__c,
        Cost__c,
        Margin__c,
        Margin_Percentage__c,
        Start_Date__c,
        End_Date__c,
        Add_on__c,
        Add_on__r.Name,
        Quote.Quote_Time_Period__c
      FROM QuoteLineItem
      WHERE QuoteId = :quoteId
      ORDER BY Item_Type__c, CreatedDate ASC
    ];
  }

  @AuraEnabled
  public static Quote createQuote(
    String name,
    Id opportunityId,
    Id pricebook2Id,
    String timePeriod
  ) {
    Quote q = new Quote(
      Name = name,
      OpportunityId = opportunityId,
      Pricebook2Id = pricebook2Id,
      Quote_Time_Period__c = timePeriod,
      Status = 'Draft'
    );
    insert q;
    return getQuoteById(q.Id);
  }

  @AuraEnabled
  public static Quote updateQuoteStatus(Id quoteId, String newStatus) {
    Quote q = new Quote(Id = quoteId, Status = newStatus);
    update q;
    return getQuoteById(quoteId);
  }

  @AuraEnabled
  public static Quote updateQuoteFields(Id quoteId, String description) {
    Quote q = new Quote(Id = quoteId);
    q.Description = description;
    update q;
    return getQuoteById(quoteId);
  }

  @AuraEnabled
  public static Quote cloneQuote(Id quoteId) {
    Quote original = [
      SELECT
        Id,
        Name,
        OpportunityId,
        Pricebook2Id,
        Quote_Time_Period__c,
        Description
      FROM Quote
      WHERE Id = :quoteId
    ];

    Quote cloned = new Quote(
      Name = original.Name + ' - Copy',
      OpportunityId = original.OpportunityId,
      Pricebook2Id = original.Pricebook2Id,
      Quote_Time_Period__c = original.Quote_Time_Period__c,
      Description = original.Description,
      Status = 'Draft'
    );

    insert cloned;

    List<QuoteLineItem> originalLines = [
      SELECT
        PricebookEntryId,
        Product2Id,
        Quantity,
        UnitPrice,
        Resource_Role__c,
        Duration_Hours__c,
        Phase__c,
        Item_Type__c
      FROM QuoteLineItem
      WHERE QuoteId = :quoteId
    ];

    List<QuoteLineItem> clonedLines = new List<QuoteLineItem>();
    for (QuoteLineItem line : originalLines) {
      clonedLines.add(
        new QuoteLineItem(
          QuoteId = cloned.Id,
          PricebookEntryId = line.PricebookEntryId,
          Product2Id = line.Product2Id,
          Quantity = line.Quantity,
          UnitPrice = line.UnitPrice,
          Resource_Role__c = line.Resource_Role__c,
          Duration_Hours__c = line.Duration_Hours__c,
          Phase__c = line.Phase__c,
          Item_Type__c = line.Item_Type__c
        )
      );
    }

    if (!clonedLines.isEmpty()) {
      insert clonedLines;
    }

    return getQuoteById(cloned.Id);
  }

  @AuraEnabled
  public static void deleteQuote(Id quoteId) {
    delete new Quote(Id = quoteId);
  }
  @AuraEnabled
  public static QuoteLineItem addLineItem(
    Id quoteId,
    Id pricebookEntryId,
    Id product2Id,
    Decimal quantity,
    Decimal unitPrice,
    Id resourceRoleId,
    Decimal durationHours,
    String phase,
    String itemType,
    Id addonId
  ) {
    Quote q = [
      SELECT Pricebook2Id, Start_Date__c, End_Date__c, Quote_Time_Period__c
      FROM Quote
      WHERE Id = :quoteId
      LIMIT 1
    ];
    Id pbId = q.Pricebook2Id;

    if (pricebookEntryId != null && pbId == null) {
      PricebookEntry pbe = [
        SELECT Pricebook2Id
        FROM PricebookEntry
        WHERE Id = :pricebookEntryId
        LIMIT 1
      ];
      pbId = pbe.Pricebook2Id;
      update new Quote(Id = quoteId, Pricebook2Id = pbId);
    } else if (pbId == null) {
      try {
        pbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;
      } catch (Exception e) {
      }
      if (pbId != null) {
        update new Quote(Id = quoteId, Pricebook2Id = pbId);
      }
    }

    if (
      itemType == 'Resource' ||
      itemType == 'Labor' ||
      pricebookEntryId == null
    ) {
      List<Product2> prods = [
        SELECT Id
        FROM Product2
        WHERE Name = 'Resource Placeholder'
        LIMIT 1
      ];
      Product2 prod;
      if (prods.isEmpty()) {
        prod = new Product2(Name = 'Resource Placeholder', IsActive = true);
        insert prod;
      } else {
        prod = prods[0];
      }

      List<PricebookEntry> pbes = [
        SELECT Id
        FROM PricebookEntry
        WHERE Product2Id = :prod.Id AND Pricebook2Id = :pbId
        LIMIT 1
      ];
      if (pbes.isEmpty()) {
        PricebookEntry pbe = new PricebookEntry(
          Pricebook2Id = pbId,
          Product2Id = prod.Id,
          UnitPrice = 0,
          IsActive = true
        );
        insert pbe;
        pricebookEntryId = pbe.Id;
      } else {
        pricebookEntryId = pbes[0].Id;
      }
      product2Id = prod.Id;
    }

    QuoteLineItem item = new QuoteLineItem(
      QuoteId = quoteId,
      PricebookEntryId = pricebookEntryId,
      Product2Id = product2Id,
      Quantity = quantity,
      UnitPrice = unitPrice,
      Resource_Role__c = resourceRoleId,
      Duration_Hours__c = durationHours,
      Phase__c = phase,
      Item_Type__c = itemType,
      Add_on__c = addonId
    );

    if (q.Start_Date__c != null) {
      item.Start_Date__c = q.Start_Date__c;

      if (itemType == 'Labor' || itemType == 'Resource') {
        // Calculate end date based on quantity (months)
        item.End_Date__c = q.Start_Date__c.addMonths(Integer.valueOf(quantity));
      } else if (q.End_Date__c != null) {
        item.End_Date__c = q.End_Date__c;
      }
    }

    insert item;
    return item;
  }

  @AuraEnabled
  public static void removeLineItem(Id lineItemId) {
    delete new QuoteLineItem(Id = lineItemId);
  }

  @AuraEnabled
  public static void updateLineItems(List<QuoteLineItem> items) {
    update items;
  }
}

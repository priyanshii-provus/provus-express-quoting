Id quoteId = [SELECT Id, Pricebook2Id FROM Quote LIMIT 1].Id;
Quote q = [SELECT Pricebook2Id FROM Quote WHERE Id = :quoteId];
Id pbId = q.Pricebook2Id;

if (pbId == null) {
    try { pbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id; } catch(Exception e) {}
    if (pbId != null) {
        update new Quote(Id = quoteId, Pricebook2Id = pbId);
    }
}

// Emulate resource (no pbe given)
Id pricebookEntryId = null;
Id product2Id = null;

if (pricebookEntryId == null) {
    List<Product2> prods = [SELECT Id FROM Product2 WHERE Name = 'Resource Placeholder' LIMIT 1];
    Product2 prod;
    if (prods.isEmpty()) {
        prod = new Product2(Name = 'Resource Placeholder', IsActive = true);
        insert prod;
    } else {
        prod = prods[0];
    }
    
    List<PricebookEntry> pbes = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id AND Pricebook2Id = :pbId LIMIT 1];
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

try {
    QuoteLineItem item = new QuoteLineItem(
        QuoteId = quoteId,
        PricebookEntryId = pricebookEntryId,
        Product2Id = product2Id,
        Quantity = 1,
        UnitPrice = 100
    );
    insert item;
    System.debug('SUCCESS: ' + item.Id);
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
}

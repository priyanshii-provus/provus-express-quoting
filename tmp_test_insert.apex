Id quoteId = [SELECT Id FROM Quote LIMIT 1].Id;
Id pbeId = [SELECT Id FROM PricebookEntry LIMIT 1].Id;

try {
    QuoteLineItem item = new QuoteLineItem(
        QuoteId = quoteId,
        PricebookEntryId = pbeId,
        Quantity = 1,
        UnitPrice = 100
    );
    insert item;
    System.debug('SUCCESS: ' + item.Id);
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
}

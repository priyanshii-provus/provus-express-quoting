Id quoteId = '0Q0C4000001HjWPKA0'; // User's quote
Id resourceRoleId = [SELECT Id FROM Resource_Role__c LIMIT 1].Id;

try {
    QuoteLineItem item = QuoteService.addLineItem(
        quoteId, 
        null, 
        null, 
        1, 
        80.00, 
        resourceRoleId, 
        1, 
        'Phase 1', 
        'Resource'
    );
    System.debug('SUCCESS: ' + item.Id);
} catch (Exception e) {
    System.debug('ERROR_DIAGNOSTIC: ' + e.getMessage() + '\n' + e.getStackTraceString());
}

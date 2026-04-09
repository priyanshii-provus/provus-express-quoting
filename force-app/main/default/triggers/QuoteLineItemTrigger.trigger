trigger QuoteLineItemTrigger on QuoteLineItem(
  before insert,
  before update,
  before delete,
  after insert,
  after update,
  after delete
) {
  QuoteLineItemTriggerHandler handler = new QuoteLineItemTriggerHandler();

  if (Trigger.isBefore) {
    if (Trigger.isInsert) {
      handler.beforeInsert(Trigger.new);
    } else if (Trigger.isUpdate) {
      handler.beforeUpdate(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isDelete) {
      handler.beforeDelete(Trigger.old);
    }
  } else if (Trigger.isAfter) {
    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isDelete) {
      Set<Id> quoteIds = new Set<Id>();
      List<QuoteLineItem> items = Trigger.isDelete ? Trigger.old : Trigger.new;
      for (QuoteLineItem item : items) {
        quoteIds.add(item.QuoteId);
      }
      handler.rollupToQuote(quoteIds);
    }
  }
}

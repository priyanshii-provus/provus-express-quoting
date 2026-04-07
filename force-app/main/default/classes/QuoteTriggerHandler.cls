public with sharing class QuoteTriggerHandler {
    
    public void beforeInsert(List<Quote> newQuotes) {
        calculateMargins(newQuotes);
        setDefaults(newQuotes);
        calculateEndDate(newQuotes);
    }
    
    public void beforeUpdate(List<Quote> newQuotes, Map<Id, Quote> oldQuoteMap) {
        calculateMargins(newQuotes);
        calculateEndDate(newQuotes);
    }
    
    public void afterInsert(List<Quote> newQuotes) {
        // Future: sync to external systems, send notifications, etc.
    }
    
    public void afterUpdate(List<Quote> newQuotes, Map<Id, Quote> oldQuoteMap) {
        // Future: track status changes, approval workflow triggers, etc.
    }
    
    private void calculateMargins(List<Quote> quotes) {
        for (Quote q : quotes) {
            if (q.TotalPrice != null && q.Total_Cost__c != null) {
                Decimal margin = q.TotalPrice - q.Total_Cost__c;
                q.Margin_Percentage__c = q.TotalPrice != 0 ? 
                    (margin / q.TotalPrice) * 100 : 0;
            }
        }
    }
    
    private void setDefaults(List<Quote> quotes) {
        for (Quote q : quotes) {
            if (q.Quote_Time_Period__c == null) {
                q.Quote_Time_Period__c = 'Months';
            }
            if (q.Valid_Until__c == null) {
                q.Valid_Until__c = Date.today().addMonths(1);
            }
        }
    }
    
    private void calculateEndDate(List<Quote> quotes) {
        for (Quote q : quotes) {
            if (q.Start_Date__c != null && q.Quote_Time_Period__c != null && q.End_Date__c == null) {
                if (q.Quote_Time_Period__c == 'Months') {
                    q.End_Date__c = q.Start_Date__c.addMonths(1);
                } else if (q.Quote_Time_Period__c == 'Quarters') {
                    q.End_Date__c = q.Start_Date__c.addMonths(3);
                } else if (q.Quote_Time_Period__c == 'Years') {
                    q.End_Date__c = q.Start_Date__c.addYears(1);
                } else if (q.Quote_Time_Period__c == 'Weeks') {
                    q.End_Date__c = q.Start_Date__c.addDays(7);
                }
            }
        }
    }
}

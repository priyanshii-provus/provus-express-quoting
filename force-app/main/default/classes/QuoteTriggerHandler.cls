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
      if (
        q.TotalPrice != null &&
        q.Total_Cost__c != null &&
        q.TotalPrice != 0
      ) {
        Decimal margin = q.TotalPrice - q.Total_Cost__c;
        Decimal marginPct = (margin / q.TotalPrice) * 100;

        // Clamping to avoid "value outside of valid range" errors for Percent(5,2)
        if (marginPct > 999.99)
          marginPct = 999.99;
        else if (marginPct < -999.99)
          marginPct = -999.99;

        q.Margin_Percentage__c = marginPct;
      } else {
        q.Margin_Percentage__c = 0;
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
      if (
        q.Start_Date__c != null &&
        q.Quote_Time_Period__c != null &&
        q.End_Date__c == null
      ) {
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

public without sharing class DashboardController {
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getQuoteInsights() {
    Map<String, Object> insights = new Map<String, Object>();

    // Awaiting Approval
    List<AggregateResult> pendingAgg = [
      SELECT COUNT(Id) cnt, SUM(TotalPrice) total
      FROM Quote
      WHERE Status = 'Pending Approval'
    ];
    insights.put('awaitingApproval', buildInsight(pendingAgg));

    // Low Margin Drafts (< 15%)
    List<AggregateResult> lowMarginAgg = [
      SELECT COUNT(Id) cnt, SUM(TotalPrice) total
      FROM Quote
      WHERE Status = 'Draft' AND Margin_Percentage__c < 15
    ];
    insights.put('lowMargin', buildInsight(lowMarginAgg));

    // Draft Pipeline
    List<AggregateResult> draftAgg = [
      SELECT COUNT(Id) cnt, SUM(TotalPrice) total
      FROM Quote
      WHERE Status = 'Draft'
    ];
    insights.put('draftPipeline', buildInsight(draftAgg));

    // High Margin Deals (>= 35%)
    List<AggregateResult> highMarginAgg = [
      SELECT COUNT(Id) cnt, SUM(TotalPrice) total
      FROM Quote
      WHERE Margin_Percentage__c >= 35 AND Status != 'Rejected'
    ];
    insights.put('highMargin', buildInsight(highMarginAgg));

    // Won This Month
    List<AggregateResult> wonAgg = [
      SELECT COUNT(Id) cnt, SUM(TotalPrice) total
      FROM Quote
      WHERE Status IN ('Accepted', 'Approved') AND CreatedDate = THIS_MONTH
    ];
    insights.put('wonThisMonth', buildInsight(wonAgg));

    // Average Margin
    List<AggregateResult> avgMarginAgg = [
      SELECT AVG(Margin_Percentage__c) avgMargin
      FROM Quote
      WHERE Margin_Percentage__c != NULL
    ];
    Decimal avgMargin = avgMarginAgg.isEmpty() ||
      avgMarginAgg[0].get('avgMargin') == null
      ? 0
      : (Decimal) avgMarginAgg[0].get('avgMargin');
    insights.put('averageMargin', avgMargin);

    // Total Quotes Count
    Integer totalQuotes = [SELECT COUNT() FROM Quote];
    insights.put('totalQuotes', totalQuotes);

    return insights;
  }

  @AuraEnabled(cacheable=true)
  public static List<Quote> getRecentQuotes() {
    return [
      SELECT
        Id,
        QuoteNumber,
        Name,
        Status,
        TotalPrice,
        Margin_Percentage__c,
        Opportunity.Name,
        Opportunity.Account.Name,
        CreatedDate,
        CreatedBy.Name
      FROM Quote
      ORDER BY CreatedDate DESC
      LIMIT 10
    ];
  }

  @AuraEnabled(cacheable=true)
  public static List<Map<String, Object>> getQuotesByStatus() {
    List<Map<String, Object>> result = new List<Map<String, Object>>();
    for (AggregateResult ar : [
      SELECT Status, COUNT(Id) cnt, SUM(TotalPrice) total
      FROM Quote
      GROUP BY Status
    ]) {
      result.add(
        new Map<String, Object>{
          'status' => ar.get('Status'),
          'count' => ar.get('cnt'),
          'totalAmount' => ar.get('total')
        }
      );
    }
    return result;
  }

  @AuraEnabled(cacheable=true)
  public static List<Map<String, Object>> getMonthlyRevenue() {
    List<Map<String, Object>> result = new List<Map<String, Object>>();
    for (AggregateResult ar : [
      SELECT
        CALENDAR_MONTH(CreatedDate) month,
        CALENDAR_YEAR(CreatedDate) year,
        SUM(TotalPrice) total,
        COUNT(Id) cnt
      FROM Quote
      WHERE Status IN ('Accepted', 'Approved') AND CreatedDate = THIS_YEAR
      GROUP BY CALENDAR_MONTH(CreatedDate), CALENDAR_YEAR(CreatedDate)
      ORDER BY CALENDAR_YEAR(CreatedDate), CALENDAR_MONTH(CreatedDate)
    ]) {
      result.add(
        new Map<String, Object>{
          'month' => ar.get('month'),
          'year' => ar.get('year'),
          'totalRevenue' => ar.get('total'),
          'quoteCount' => ar.get('cnt')
        }
      );
    }
    return result;
  }

  private static Map<String, Object> buildInsight(
    List<AggregateResult> aggResults
  ) {
    Integer count = 0;
    Decimal amount = 0;
    if (!aggResults.isEmpty()) {
      count = aggResults[0].get('cnt') != null
        ? (Integer) aggResults[0].get('cnt')
        : 0;
      amount = aggResults[0].get('total') != null
        ? (Decimal) aggResults[0].get('total')
        : 0;
    }
    return new Map<String, Object>{ 'count' => count, 'amount' => amount };
  }
}

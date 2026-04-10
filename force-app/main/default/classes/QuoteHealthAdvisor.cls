public without sharing class QuoteHealthAdvisor {

  public class HealthScore {
    @AuraEnabled public Integer score;
    @AuraEnabled public String status;       // 'Healthy', 'Warning', 'Critical'
    @AuraEnabled public String statusIcon;   // 'utility:like', 'utility:warning', 'utility:error'
    @AuraEnabled public List<Recommendation> recommendations;
    @AuraEnabled public Decimal marginPct;
    @AuraEnabled public Decimal discountPct;
    @AuraEnabled public Decimal laborRatio;
    @AuraEnabled public Integer totalItems;
  }

  public class Recommendation {
    @AuraEnabled public String severity;     // 'info', 'warning', 'error', 'success'
    @AuraEnabled public String icon;
    @AuraEnabled public String title;
    @AuraEnabled public String detail;
    @AuraEnabled public Integer impact;      // Estimated score impact
  }

  // Target benchmarks (could be moved to Custom Metadata later)
  private static final Decimal TARGET_MARGIN = 25.0;
  private static final Decimal MIN_MARGIN = 10.0;
  private static final Decimal MAX_DISCOUNT = 20.0;
  private static final Decimal IDEAL_LABOR_RATIO = 0.60;  // 60% labor revenue is ideal
  private static final Decimal MIN_LABOR_RATIO = 0.30;

  @AuraEnabled
  public static HealthScore evaluateQuoteHealth(Id quoteId) {
    // Fetch quote data
    Quote q = [
      SELECT Id, TotalPrice, Subtotal, Discount,
             Margin_Percentage__c, Total_Cost__c, Total_Margin__c,
             Labor_Revenue__c, Products_Revenue__c, Addons_Revenue__c,
             Start_Date__c, End_Date__c, Status
      FROM Quote WHERE Id = :quoteId LIMIT 1
    ];

    // Fetch line items for deeper analysis
    List<QuoteLineItem> items = [
      SELECT Id, Item_Type__c, TotalPrice, Cost__c, Quantity,
             UnitPrice, Discount, Resource_Role__c, Phase__c
      FROM QuoteLineItem WHERE QuoteId = :quoteId
    ];

    HealthScore result = new HealthScore();
    result.recommendations = new List<Recommendation>();
    result.totalItems = items.size();

    // Calculate key metrics
    Decimal totalRevenue = (q.TotalPrice != null ? q.TotalPrice : 0);
    Decimal totalCost = (q.Total_Cost__c != null ? q.Total_Cost__c : 0);
    Decimal marginPct = (q.Margin_Percentage__c != null ? q.Margin_Percentage__c : 0);
    Decimal discountPct = (q.Discount != null ? q.Discount : 0);
    Decimal laborRevenue = (q.Labor_Revenue__c != null ? q.Labor_Revenue__c : 0);
    Decimal productRevenue = (q.Products_Revenue__c != null ? q.Products_Revenue__c : 0);
    Decimal addonRevenue = (q.Addons_Revenue__c != null ? q.Addons_Revenue__c : 0);

    result.marginPct = marginPct;
    result.discountPct = discountPct;
    result.laborRatio = (totalRevenue > 0) ? (laborRevenue / totalRevenue) : 0;

    Integer score = 100;

    // ── Rule 1: Margin Health ──
    if (marginPct >= TARGET_MARGIN) {
      Recommendation r = new Recommendation();
      r.severity = 'success';
      r.icon = 'utility:like';
      r.title = 'Strong Margin';
      r.detail = 'Your margin looks great and meets the target.';
      r.impact = 0;
      result.recommendations.add(r);
    } else if (marginPct >= MIN_MARGIN) {
      Integer penalty = (Integer)((TARGET_MARGIN - marginPct) * 1.5);
      score -= penalty;
      Recommendation r = new Recommendation();
      r.severity = 'warning';
      r.icon = 'utility:warning';
      r.title = 'Margin Below Target';
      r.detail = 'Margin is a bit low. Try raising prices or adding higher-margin items.';
      r.impact = penalty;
      result.recommendations.add(r);
    } else {
      Integer penalty = (Integer)((TARGET_MARGIN - marginPct) * 2.0);
      score -= penalty;
      Recommendation r = new Recommendation();
      r.severity = 'error';
      r.icon = 'utility:error';
      r.title = 'Critical: Low Margin';
      r.detail = 'Margin is critically low. This project might not be profitable. Please review costs and pricing.';
      r.impact = penalty;
      result.recommendations.add(r);
    }

    // ── Rule 2: Discount Analysis ──
    if (discountPct > MAX_DISCOUNT) {
      Integer penalty = (Integer)((discountPct - MAX_DISCOUNT) * 2);
      score -= penalty;
      Recommendation r = new Recommendation();
      r.severity = 'warning';
      r.icon = 'utility:discount';
      r.title = 'High Discounts';
      r.detail = 'You are giving too much discount. Try to lower it to protect profitability.';
      r.impact = penalty;
      result.recommendations.add(r);
    } else if (discountPct > 0 && discountPct <= MAX_DISCOUNT) {
      Recommendation r = new Recommendation();
      r.severity = 'info';
      r.icon = 'utility:info';
      r.title = 'Discount OK';
      r.detail = 'Discounts are well within safe limits.';
      r.impact = 0;
      result.recommendations.add(r);
    }

    // ── Rule 3: Revenue Mix (Labor vs Products) ──
    if (totalRevenue > 0) {
      Decimal laborRatio = laborRevenue / totalRevenue;
      if (laborRatio < MIN_LABOR_RATIO && laborRevenue > 0) {
        Integer penalty = 10;
        score -= penalty;
        Recommendation r = new Recommendation();
        r.severity = 'warning';
        r.icon = 'utility:people';
        r.title = 'Need More Services';
        r.detail = 'This quote is mostly products. Adding more service roles can improve overall margins.';
        r.impact = penalty;
        result.recommendations.add(r);
      } else if (laborRatio >= IDEAL_LABOR_RATIO) {
        Recommendation r = new Recommendation();
        r.severity = 'success';
        r.icon = 'utility:check';
        r.title = 'Good Services Mix';
        r.detail = 'Great balance of services. Service-heavy quotes usually have better margins.';
        r.impact = 0;
        result.recommendations.add(r);
      }
    }

    // ── Rule 4: Empty Quote Check ──
    if (items.isEmpty()) {
      score -= 40;
      Recommendation r = new Recommendation();
      r.severity = 'error';
      r.icon = 'utility:error';
      r.title = 'No Line Items';
      r.detail = 'Your quote is empty. You need to add items to get an accurate score.';
      r.impact = 40;
      result.recommendations.add(r);
    }

    // ── Rule 5: Zero-cost items ──
    Integer zeroCostCount = 0;
    for (QuoteLineItem item : items) {
      if (item.Cost__c == null || item.Cost__c == 0) {
        zeroCostCount++;
      }
    }
    if (zeroCostCount > 0 && !items.isEmpty()) {
      Integer penalty = Math.min(zeroCostCount * 5, 15);
      score -= penalty;
      Recommendation r = new Recommendation();
      r.severity = 'warning';
      r.icon = 'utility:warning';
      r.title = 'Missing Costs';
      r.detail = 'Some items are missing costs. The margin calculation might be wrong.';
      r.impact = penalty;
      result.recommendations.add(r);
    }

    // ── Rule 6: Phase Diversity ──
    Set<String> phases = new Set<String>();
    for (QuoteLineItem item : items) {
      phases.add(item.Phase__c != null ? item.Phase__c : 'Default');
    }
    if (phases.size() == 1 && items.size() > 3) {
      Integer penalty = 5;
      score -= penalty;
      Recommendation r = new Recommendation();
      r.severity = 'info';
      r.icon = 'utility:layers';
      r.title = 'Single Phase';
      r.detail = 'All items are in one phase. Consider grouping them into phases to make the quote clearer for the customer.';
      r.impact = penalty;
      result.recommendations.add(r);
    }

    // ── Rule 7: Date Validation ──
    if (q.Start_Date__c == null) {
      Integer penalty = 5;
      score -= penalty;
      Recommendation r = new Recommendation();
      r.severity = 'info';
      r.icon = 'utility:date_input';
      r.title = 'Missing Start Date';
      r.detail = 'Set a project start date so the timeline calculates correctly.';
      r.impact = penalty;
      result.recommendations.add(r);
    }

    // Clamp score
    score = Math.max(0, Math.min(100, score));
    result.score = score;

    // Determine status
    if (score >= 80) {
      result.status = 'Healthy';
      result.statusIcon = 'utility:like';
    } else if (score >= 50) {
      result.status = 'Warning';
      result.statusIcon = 'utility:warning';
    } else {
      result.status = 'Critical';
      result.statusIcon = 'utility:error';
    }

    return result;
  }
}

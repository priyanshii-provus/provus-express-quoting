public with sharing class QuotePDFController {
  public Quote quote { get; set; }
  public List<QuoteLineItem> lineItems { get; set; }

  // Computed financials for the PDF
  public Decimal computedSubtotal { get; set; }
  public Decimal computedDiscount { get; set; }
  public Decimal computedTotalCost { get; set; }
  public Decimal computedMargin { get; set; }
  public Decimal computedTotalRevenue { get; set; }
  public String validUntilDisplay { get; set; }

  // Constructor for Visualforce page
  public QuotePDFController() {
    String quoteId = ApexPages.currentPage().getParameters().get('quoteId');
    if (String.isNotBlank(quoteId)) {
      loadQuoteData(quoteId);
    }
  }

  private void loadQuoteData(String quoteId) {
    quote = [
      SELECT
        Id,
        Name,
        QuoteNumber,
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
        Description,
        Opportunity.Name,
        Opportunity.Account.Name,
        CreatedDate,
        CreatedBy.Name
      FROM Quote
      WHERE Id = :quoteId
      LIMIT 1
    ];

    lineItems = [
      SELECT
        Id,
        Product2.Name,
        Item_Type__c,
        Quantity,
        UnitPrice,
        Discount,
        TotalPrice,
        Cost__c,
        Resource_Role__c,
        Resource_Role__r.Name
      FROM QuoteLineItem
      WHERE QuoteId = :quoteId
      ORDER BY Item_Type__c, CreatedDate ASC
    ];

    // Compute financials from line items directly
    computedSubtotal = 0;
    computedTotalRevenue = 0;
    computedTotalCost = 0;
    Decimal totalUnitPriceTimesQty = 0;

    for (QuoteLineItem item : lineItems) {
      Decimal lineTotal = item.TotalPrice != null ? item.TotalPrice : 0;
      Decimal lineCost =
        (item.Cost__c != null ? item.Cost__c : 0) *
        (item.Quantity != null ? item.Quantity : 0);
      Decimal lineSubtotal =
        (item.UnitPrice != null ? item.UnitPrice : 0) *
        (item.Quantity != null ? item.Quantity : 0);

      computedTotalRevenue += lineTotal;
      computedTotalCost += lineCost;
      totalUnitPriceTimesQty += lineSubtotal;
    }

    // Subtotal is sum of UnitPrice * Quantity (before discount)
    computedSubtotal = totalUnitPriceTimesQty;

    // Discount is the difference between subtotal and total revenue
    computedDiscount = computedSubtotal - computedTotalRevenue;
    if (computedDiscount < 0)
      computedDiscount = 0;

    // Use quote-level fields if they have actual values, otherwise use computed
    if (quote.Total_Cost__c != null && quote.Total_Cost__c > 0) {
      computedTotalCost = quote.Total_Cost__c;
    }
    if (quote.Discount_Amount__c != null && quote.Discount_Amount__c > 0) {
      computedDiscount = quote.Discount_Amount__c;
    }

    // Margin = (Revenue - Cost) / Revenue * 100
    if (quote.Margin_Percentage__c != null && quote.Margin_Percentage__c != 0) {
      computedMargin = quote.Margin_Percentage__c;
    } else if (computedTotalRevenue > 0) {
      computedMargin =
        ((computedTotalRevenue - computedTotalCost) / computedTotalRevenue) *
        100;
    } else {
      computedMargin = 0;
    }

    // Valid Until display
    if (quote.Valid_Until__c != null) {
      validUntilDisplay = quote.Valid_Until__c.format();
    } else {
      validUntilDisplay = 'Not Set';
    }
  }

  @AuraEnabled
  public static Quote_PDF_Version__c generatePDF(Id quoteId) {
    // Query quote data for snapshot
    Quote q = [
      SELECT
        Id,
        Name,
        QuoteNumber,
        Status,
        TotalPrice,
        Subtotal,
        Discount,
        Margin_Percentage__c,
        Total_Cost__c,
        Discount_Amount__c,
        Opportunity.Account.Name,
        CreatedBy.Name
      FROM Quote
      WHERE Id = :quoteId
      LIMIT 1
    ];

    // Also compute from line items for snapshot accuracy
    List<QuoteLineItem> items = [
      SELECT TotalPrice, Cost__c, Quantity, UnitPrice
      FROM QuoteLineItem
      WHERE QuoteId = :quoteId
    ];
    Decimal snapRevenue = 0;
    Decimal snapCost = 0;
    Decimal snapSubtotal = 0;
    for (QuoteLineItem item : items) {
      snapRevenue += (item.TotalPrice != null ? item.TotalPrice : 0);
      snapCost +=
        (item.Cost__c != null ? item.Cost__c : 0) *
        (item.Quantity != null ? item.Quantity : 0);
      snapSubtotal +=
        (item.UnitPrice != null ? item.UnitPrice : 0) *
        (item.Quantity != null ? item.Quantity : 0);
    }

    Decimal snapDiscount = snapSubtotal - snapRevenue;
    if (snapDiscount < 0)
      snapDiscount = 0;

    // Prefer quote-level if populated
    if (q.Total_Cost__c != null && q.Total_Cost__c > 0)
      snapCost = q.Total_Cost__c;
    if (q.Discount_Amount__c != null && q.Discount_Amount__c > 0)
      snapDiscount = q.Discount_Amount__c;

    Decimal snapMargin = 0;
    if (q.Margin_Percentage__c != null && q.Margin_Percentage__c != 0) {
      snapMargin = q.Margin_Percentage__c;
    } else if (snapRevenue > 0) {
      snapMargin = ((snapRevenue - snapCost) / snapRevenue) * 100;
    }

    // Calculate next version number
    List<AggregateResult> agg = [
      SELECT MAX(Version_Number__c) maxVer
      FROM Quote_PDF_Version__c
      WHERE Quote__c = :quoteId
    ];
    Integer nextVersion = 1;
    if (agg[0].get('maxVer') != null) {
      nextVersion = ((Decimal) agg[0].get('maxVer')).intValue() + 1;
    }

    // Generate PDF blob
    PageReference pdfPage = Page.QuotePDFTemplate;
    pdfPage.getParameters().put('quoteId', quoteId);

    Blob pdfBlob;
    if (Test.isRunningTest()) {
      pdfBlob = Blob.valueOf('Test PDF Content');
    } else {
      pdfBlob = pdfPage.getContentAsPDF();
    }

    // Create ContentVersion (Salesforce File)
    String fileName = q.QuoteNumber + '_v' + nextVersion + '.pdf';
    ContentVersion cv = new ContentVersion(
      Title = q.Name + ' - v' + nextVersion,
      PathOnClient = fileName,
      VersionData = pdfBlob,
      Origin = 'C'
    );
    insert cv;

    // Get the ContentDocumentId
    cv = [
      SELECT Id, ContentDocumentId, ContentSize
      FROM ContentVersion
      WHERE Id = :cv.Id
    ];

    // Link to the Quote
    ContentDocumentLink cdl = new ContentDocumentLink(
      ContentDocumentId = cv.ContentDocumentId,
      LinkedEntityId = quoteId,
      ShareType = 'V',
      Visibility = 'AllUsers'
    );
    insert cdl;

    // Build snapshot JSON
    Map<String, Object> snapshot = new Map<String, Object>{
      'totalPrice' => snapRevenue,
      'subtotal' => snapSubtotal,
      'marginPercentage' => snapMargin,
      'totalCost' => snapCost,
      'discount' => snapDiscount,
      'status' => q.Status,
      'accountName' => q.Opportunity?.Account?.Name
    };

    // Create PDF Version record
    Quote_PDF_Version__c pdfVersion = new Quote_PDF_Version__c(
      Quote__c = quoteId,
      Version_Number__c = nextVersion,
      Content_Document_Id__c = cv.ContentDocumentId,
      Content_Version_Id__c = cv.Id,
      File_Size__c = cv.ContentSize,
      Generated_Date__c = Datetime.now(),
      Quote_Snapshot_JSON__c = JSON.serialize(snapshot)
    );
    insert pdfVersion;

    return pdfVersion;
  }

  @AuraEnabled(cacheable=false)
  public static List<Map<String, Object>> getPDFVersions(Id quoteId) {
    List<Quote_PDF_Version__c> versions = [
      SELECT
        Id,
        Name,
        Version_Number__c,
        Content_Document_Id__c,
        Content_Version_Id__c,
        File_Size__c,
        Generated_Date__c,
        Notes__c,
        Quote_Snapshot_JSON__c,
        CreatedBy.Name,
        CreatedDate
      FROM Quote_PDF_Version__c
      WHERE Quote__c = :quoteId
      ORDER BY Version_Number__c DESC
    ];

    // Find max version number for "Latest" badge
    Decimal maxVersion = 0;
    for (Quote_PDF_Version__c v : versions) {
      if (v.Version_Number__c > maxVersion) {
        maxVersion = v.Version_Number__c;
      }
    }

    List<Map<String, Object>> result = new List<Map<String, Object>>();
    for (Quote_PDF_Version__c v : versions) {
      Map<String, Object> row = new Map<String, Object>();
      row.put('id', v.Id);
      row.put('versionNumber', v.Version_Number__c);
      row.put('isLatest', v.Version_Number__c == maxVersion);
      row.put('contentDocumentId', v.Content_Document_Id__c);
      row.put('contentVersionId', v.Content_Version_Id__c);
      row.put('fileSize', v.File_Size__c);
      row.put('generatedDate', v.Generated_Date__c);
      row.put('notes', v.Notes__c);
      row.put('createdByName', v.CreatedBy.Name);
      row.put('createdDate', v.CreatedDate);

      // Parse snapshot for totals
      if (String.isNotBlank(v.Quote_Snapshot_JSON__c)) {
        Map<String, Object> snap = (Map<String, Object>) JSON.deserializeUntyped(
          v.Quote_Snapshot_JSON__c
        );
        row.put('totalPrice', snap.get('totalPrice'));
        row.put('marginPercentage', snap.get('marginPercentage'));
        row.put('totalCost', snap.get('totalCost'));
      }

      result.add(row);
    }

    return result;
  }

  @AuraEnabled
  public static void deletePDFVersion(Id versionId) {
    Quote_PDF_Version__c v = [
      SELECT Id, Content_Document_Id__c
      FROM Quote_PDF_Version__c
      WHERE Id = :versionId
      LIMIT 1
    ];

    // Delete the ContentDocument (this also deletes ContentVersions and links)
    if (String.isNotBlank(v.Content_Document_Id__c)) {
      try {
        delete new ContentDocument(Id = v.Content_Document_Id__c);
      } catch (Exception e) {
        System.debug('Failed to delete ContentDocument: ' + e.getMessage());
      }
    }

    delete v;
  }
}

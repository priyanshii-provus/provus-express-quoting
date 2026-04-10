public with sharing class AdminSettingsController {
  @AuraEnabled(cacheable=false)
  public static Map<String, Object> getCompanySettings() {
    Map<String, Object> result = new Map<String, Object>();
    Provus_Company_Settings__c settings = Provus_Company_Settings__c.getOrgDefaults();
    if (settings != null) {
      result.put('companyName', settings.Company_Name__c);
      result.put('phone', settings.Phone__c);
      result.put('website', settings.Website__c);
      result.put('industry', settings.Industry__c);
      result.put('addressLine1', settings.Address_Line1__c);
      result.put('city', settings.City__c);
      result.put('state', settings.State__c);
      result.put('country', settings.Country__c);
      result.put('timezone', settings.Timezone__c);
      result.put('currencyCode', settings.Currency_Code__c);
    }
    return result;
  }

  @AuraEnabled
  public static void saveCompanySettings(
    String companyName,
    String phone,
    String website,
    String industry,
    String addressLine1,
    String city,
    String state,
    String country,
    String timezone,
    String currencyCode
  ) {
    if (!TeamController.isAdmin()) {
      throw new AuraHandledException(
        'Only Admins can update company settings.'
      );
    }
    try {
      Provus_Company_Settings__c settings = Provus_Company_Settings__c.getOrgDefaults();
      // getOrgDefaults() returns an empty sObject if none exists, which can be directly upserted.
      settings.Company_Name__c = companyName;
      settings.Phone__c = phone;
      settings.Website__c = website;
      settings.Industry__c = industry;
      settings.Address_Line1__c = addressLine1;
      settings.City__c = city;
      settings.State__c = state;
      settings.Country__c = country;
      settings.Timezone__c = timezone;
      settings.Currency_Code__c = currencyCode;
      upsert settings;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled(cacheable=false)
  public static List<Map<String, Object>> getAllPDFVersions() {
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
        CreatedDate,
        Quote__c,
        Quote__r.Name,
        Quote__r.QuoteNumber
      FROM Quote_PDF_Version__c
      ORDER BY Generated_Date__c DESC
      LIMIT 200
    ];

    List<Map<String, Object>> result = new List<Map<String, Object>>();
    for (Quote_PDF_Version__c v : versions) {
      Map<String, Object> row = new Map<String, Object>();
      row.put('id', v.Id);
      row.put('versionNumber', v.Version_Number__c);
      row.put('contentDocumentId', v.Content_Document_Id__c);
      row.put('contentVersionId', v.Content_Version_Id__c);
      row.put('fileSize', v.File_Size__c);
      row.put('generatedDate', v.Generated_Date__c);
      row.put('notes', v.Notes__c);
      row.put('createdByName', v.CreatedBy.Name);
      row.put('createdDate', v.CreatedDate);
      row.put('quoteId', v.Quote__c);
      row.put('quoteName', v.Quote__r != null ? v.Quote__r.Name : '');
      row.put('quoteNumber', v.Quote__r != null ? v.Quote__r.QuoteNumber : '');
      if (String.isNotBlank(v.Quote_Snapshot_JSON__c)) {
        try {
          Map<String, Object> snap = (Map<String, Object>) JSON.deserializeUntyped(
            v.Quote_Snapshot_JSON__c
          );
          row.put('totalPrice', snap.get('totalPrice'));
          row.put('marginPercentage', snap.get('marginPercentage'));
          row.put('status', snap.get('status'));
        } catch (Exception ex) {
          /* skip bad JSON */
        }
      }
      result.add(row);
    }
    return result;
  }
}

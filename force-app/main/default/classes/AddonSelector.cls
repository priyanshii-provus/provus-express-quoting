/**
 * @description Selector class for querying Add-on records.
 */
public inherited sharing class AddonSelector {
  public static List<Add_on__c> getAddons(Boolean activeOnly) {
    String query =
      'SELECT Id, Name, Price__c, Cost__c, Billing_Unit__c, ' +
      'Active__c, Description__c, CreatedDate, LastModifiedDate ' +
      'FROM Add_on__c';

    if (activeOnly != null && activeOnly) {
      query += ' WHERE Active__c = true';
    }

    query += ' ORDER BY Name ASC';
    return Database.query(query);
  }

  public static Add_on__c getAddonById(Id addonId) {
    return [
      SELECT
        Id,
        Name,
        Price__c,
        Cost__c,
        Billing_Unit__c,
        Active__c,
        Description__c,
        CreatedDate,
        LastModifiedDate
      FROM Add_on__c
      WHERE Id = :addonId
    ];
  }
}

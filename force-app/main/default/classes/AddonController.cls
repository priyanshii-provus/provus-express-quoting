public without sharing class AddonController {
  @AuraEnabled(cacheable=true)
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

  @AuraEnabled
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

  @AuraEnabled
  public static Add_on__c createAddon(
    String name,
    Decimal price,
    Decimal cost,
    String billingUnit,
    String description
  ) {
    Add_on__c addon = new Add_on__c(
      Name = name,
      Price__c = price,
      Cost__c = cost,
      Billing_Unit__c = billingUnit,
      Description__c = description,
      Active__c = true
    );
    insert addon;
    return addon;
  }

  @AuraEnabled
  public static Add_on__c updateAddon(
    Id addonId,
    String name,
    Decimal price,
    Decimal cost,
    String billingUnit,
    String description,
    Boolean isActive
  ) {
    Add_on__c addon = new Add_on__c(
      Id = addonId,
      Name = name,
      Price__c = price,
      Cost__c = cost,
      Billing_Unit__c = billingUnit,
      Description__c = description,
      Active__c = isActive
    );
    update addon;
    return getAddonById(addonId);
  }

  @AuraEnabled
  public static void deleteAddon(Id addonId) {
    delete new Add_on__c(Id = addonId);
  }

  @AuraEnabled
  public static void updateAddons(List<Add_on__c> addons) {
    update addons;
  }

  @AuraEnabled(cacheable=true)
  public static Decimal getAddonMargin(Id addonId) {
    Add_on__c addon = [
      SELECT Price__c, Cost__c
      FROM Add_on__c
      WHERE Id = :addonId
    ];
    if (
      addon.Price__c != null &&
      addon.Cost__c != null &&
      addon.Price__c != 0
    ) {
      return ((addon.Price__c - addon.Cost__c) / addon.Price__c) * 100;
    }
    return 0;
  }
}

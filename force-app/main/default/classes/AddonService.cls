public inherited sharing class AddonService {
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
    return AddonSelector.getAddonById(addonId);
  }

  public static void deleteAddon(Id addonId) {
    delete new Add_on__c(Id = addonId);
  }

  public static void updateAddons(List<Add_on__c> addons) {
    update addons;
  }

  public static Decimal getAddonMargin(Id addonId) {
    Add_on__c addon = AddonSelector.getAddonById(addonId);
    if (
      addon.Price__c != null &&
      addon.Cost__c != null &&
      addon.Price__c != 0
    ) {
      return ((addon.Price__c - addon.Cost__c) / addon.Price__c) * 100;
    }
    return 0;
  }

  public static Integer importAddons(List<Map<String, String>> addons) {
    List<Add_on__c> toInsert = new List<Add_on__c>();

    for (Map<String, String> row : addons) {
      String addonName = row.get('Name');
      if (String.isBlank(addonName)) continue;

      Add_on__c a = new Add_on__c();
      a.Name = addonName.trim();

      String descVal = row.get('Description');
      if (String.isNotBlank(descVal)) a.Description__c = descVal.trim();

      String billingUnit = row.get('Billing_Unit');
      if (String.isNotBlank(billingUnit)) {
        a.Billing_Unit__c = billingUnit.trim();
      } else {
        a.Billing_Unit__c = 'Each';
      }

      String priceStr = row.get('Price');
      if (String.isNotBlank(priceStr)) {
        try { a.Price__c = Decimal.valueOf(priceStr.trim()); } catch (Exception e) { a.Price__c = 0; }
      }

      String costStr = row.get('Cost');
      if (String.isNotBlank(costStr)) {
        try { a.Cost__c = Decimal.valueOf(costStr.trim()); } catch (Exception e) { a.Cost__c = 0; }
      }

      String isActive = row.get('Is_Active');
      if (String.isNotBlank(isActive)) {
        a.Active__c = isActive.trim().equalsIgnoreCase('true');
      } else {
        a.Active__c = true;
      }

      toInsert.add(a);
    }

    if (!toInsert.isEmpty()) {
      insert toInsert;
    }
    return toInsert.size();
  }
}

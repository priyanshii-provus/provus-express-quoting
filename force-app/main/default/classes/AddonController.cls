public without sharing class AddonController {
  @AuraEnabled(cacheable=true)
  public static List<Add_on__c> getAddons(Boolean activeOnly) {
    return AddonSelector.getAddons(activeOnly);
  }

  @AuraEnabled
  public static Add_on__c getAddonById(Id addonId) {
    return AddonSelector.getAddonById(addonId);
  }

  @AuraEnabled
  public static Add_on__c createAddon(
    String name,
    Decimal price,
    Decimal cost,
    String billingUnit,
    String description
  ) {
    return AddonService.createAddon(name, price, cost, billingUnit, description);
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
    return AddonService.updateAddon(addonId, name, price, cost, billingUnit, description, isActive);
  }

  @AuraEnabled
  public static void deleteAddon(Id addonId) {
    AddonService.deleteAddon(addonId);
  }

  @AuraEnabled
  public static void updateAddons(List<Add_on__c> addons) {
    AddonService.updateAddons(addons);
  }

  @AuraEnabled(cacheable=true)
  public static Decimal getAddonMargin(Id addonId) {
    return AddonService.getAddonMargin(addonId);
  }

  @AuraEnabled
  public static Integer importAddons(List<Map<String, String>> addons) {
    return AddonService.importAddons(addons);
  }
}

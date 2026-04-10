public without sharing class ResourceRoleController {
  @AuraEnabled(cacheable=true)
  public static List<Resource_Role__c> getResourceRoles(Boolean activeOnly) {
    return ResourceRoleSelector.getResourceRoles(activeOnly);
  }

  @AuraEnabled
  public static Resource_Role__c getResourceRoleById(Id roleId) {
    return ResourceRoleSelector.getResourceRoleById(roleId);
  }

  @AuraEnabled
  public static Resource_Role__c createResourceRole(
    String name,
    String billingUnit,
    Decimal price,
    Decimal cost,
    String location
  ) {
    return ResourceRoleService.createResourceRole(name, billingUnit, price, cost, location);
  }

  @AuraEnabled
  public static Resource_Role__c updateResourceRole(
    Id roleId,
    String name,
    String billingUnit,
    Decimal price,
    Decimal cost,
    String location,
    Boolean isActive
  ) {
    return ResourceRoleService.updateResourceRole(roleId, name, billingUnit, price, cost, location, isActive);
  }

  @AuraEnabled
  public static void deleteResourceRole(Id roleId) {
    ResourceRoleService.deleteResourceRole(roleId);
  }

  @AuraEnabled
  public static void updateResourceRoles(List<Resource_Role__c> roles) {
    ResourceRoleService.updateResourceRoles(roles);
  }

  @AuraEnabled(cacheable=true)
  public static Decimal getMargin(Id roleId) {
    return ResourceRoleService.getMargin(roleId);
  }

  @AuraEnabled
  public static Integer importResourceRoles(List<Map<String, String>> roles) {
    return ResourceRoleService.importResourceRoles(roles);
  }
}

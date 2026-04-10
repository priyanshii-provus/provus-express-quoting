/**
 * @description Service class managing business logic and DML operations for Resource Role records.
 */
public inherited sharing class ResourceRoleService {
  public static Resource_Role__c createResourceRole(
    String name,
    String billingUnit,
    Decimal price,
    Decimal cost,
    String location
  ) {
    Resource_Role__c role = new Resource_Role__c(
      Name = name,
      Billing_Unit__c = billingUnit,
      Price__c = price,
      Cost__c = cost,
      Location__c = location,
      Active__c = true
    );
    insert role;
    return role;
  }

  public static Resource_Role__c updateResourceRole(
    Id roleId,
    String name,
    String billingUnit,
    Decimal price,
    Decimal cost,
    String location,
    Boolean isActive
  ) {
    Resource_Role__c role = new Resource_Role__c(
      Id = roleId,
      Name = name,
      Billing_Unit__c = billingUnit,
      Price__c = price,
      Cost__c = cost,
      Location__c = location,
      Active__c = isActive
    );
    update role;
    return ResourceRoleSelector.getResourceRoleById(roleId);
  }

  public static void deleteResourceRole(Id roleId) {
    delete new Resource_Role__c(Id = roleId);
  }

  public static void updateResourceRoles(List<Resource_Role__c> roles) {
    update roles;
  }

  public static Decimal getMargin(Id roleId) {
    Resource_Role__c role = ResourceRoleSelector.getResourceRoleById(roleId);
    if (role.Price__c != null && role.Cost__c != null && role.Price__c != 0) {
      return ((role.Price__c - role.Cost__c) / role.Price__c) * 100;
    }
    return 0;
  }

  public static Integer importResourceRoles(List<Map<String, String>> roles) {
    List<Resource_Role__c> toInsert = new List<Resource_Role__c>();
    for (Map<String, String> row : roles) {
      String roleName = row.get('Name');
      if (String.isBlank(roleName)) {
        continue;
      }
      Resource_Role__c rr = new Resource_Role__c();
      rr.Name = roleName.trim();

      String billingUnit = row.get('Billing_Unit');
      if (String.isNotBlank(billingUnit)) {
        rr.Billing_Unit__c = billingUnit.trim();
      } else {
        rr.Billing_Unit__c = 'Hour';
      }

      String price = row.get('Price');
      if (String.isNotBlank(price)) {
        try { rr.Price__c = Decimal.valueOf(price.trim()); } catch (Exception e) { rr.Price__c = 0; }
      }

      String cost = row.get('Cost');
      if (String.isNotBlank(cost)) {
        try { rr.Cost__c = Decimal.valueOf(cost.trim()); } catch (Exception e) { rr.Cost__c = 0; }
      }

      String location = row.get('Location');
      if (String.isNotBlank(location)) {
        rr.Location__c = location.trim();
      }

      String isActive = row.get('Is_Active');
      if (String.isNotBlank(isActive)) {
        rr.Active__c = isActive.trim().equalsIgnoreCase('true');
      } else {
        rr.Active__c = true;
      }

      toInsert.add(rr);
    }

    if (!toInsert.isEmpty()) {
      insert toInsert;
    }
    return toInsert.size();
  }
}

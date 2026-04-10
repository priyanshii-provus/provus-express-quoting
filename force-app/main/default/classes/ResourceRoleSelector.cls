public inherited sharing class ResourceRoleSelector {
  public static List<Resource_Role__c> getResourceRoles(Boolean activeOnly) {
    String query =
      'SELECT Id, Name, Billing_Unit__c, Price__c, Cost__c, ' +
      'Active__c, Location__c, CreatedDate, LastModifiedDate ' +
      'FROM Resource_Role__c';

    if (activeOnly != null && activeOnly) {
      query += ' WHERE Active__c = true';
    }

    query += ' ORDER BY Name ASC';

    return Database.query(query);
  }

  public static Resource_Role__c getResourceRoleById(Id roleId) {
    return [
      SELECT
        Id,
        Name,
        Billing_Unit__c,
        Price__c,
        Cost__c,
        Active__c,
        Location__c,
        CreatedDate,
        LastModifiedDate
      FROM Resource_Role__c
      WHERE Id = :roleId
    ];
  }
}

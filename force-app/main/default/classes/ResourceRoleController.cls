public with sharing class ResourceRoleController {
    
    @AuraEnabled(cacheable=true)
    public static List<Resource_Role__c> getResourceRoles(Boolean activeOnly) {
        String query = 'SELECT Id, Name, Billing_Unit__c, Price__c, Cost__c, ' +
                      'Active__c, Location__c, CreatedDate, LastModifiedDate ' +
                      'FROM Resource_Role__c';
        
        if (activeOnly != null && activeOnly) {
            query += ' WHERE Active__c = true';
        }
        
        query += ' ORDER BY Name ASC';
        
        return Database.query(query);
    }
    
    @AuraEnabled
    public static Resource_Role__c getResourceRoleById(Id roleId) {
        return [SELECT Id, Name, Billing_Unit__c, Price__c, Cost__c, 
                Active__c, Location__c, CreatedDate, LastModifiedDate
                FROM Resource_Role__c WHERE Id = :roleId];
    }
    
    @AuraEnabled
    public static Resource_Role__c createResourceRole(String name, String billingUnit, 
                                                       Decimal price, Decimal cost, 
                                                       String location) {
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
    
    @AuraEnabled
    public static Resource_Role__c updateResourceRole(Id roleId, String name, 
                                                       String billingUnit, Decimal price, 
                                                       Decimal cost, String location, 
                                                       Boolean isActive) {
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
        return getResourceRoleById(roleId);
    }
    
    @AuraEnabled
    public static void deleteResourceRole(Id roleId) {
        delete new Resource_Role__c(Id = roleId);
    }
    
    @AuraEnabled
    public static void updateResourceRoles(List<Resource_Role__c> roles) {
        update roles;
    }
    
    @AuraEnabled(cacheable=true)
    public static Decimal getMargin(Id roleId) {
        Resource_Role__c role = [SELECT Price__c, Cost__c FROM Resource_Role__c WHERE Id = :roleId];
        if (role.Price__c != null && role.Cost__c != null && role.Price__c != 0) {
            return ((role.Price__c - role.Cost__c) / role.Price__c) * 100;
        }
        return 0;
    }
}

@isTest
private class ResourceRoleSelectorTest {
    @TestSetup
    static void setup() {
        Resource_Role__c activeRole = new Resource_Role__c(Name = 'Developer Active', Active__c = true, Price__c = 150, Cost__c = 100, Billing_Unit__c = 'Hour');
        Resource_Role__c inactiveRole = new Resource_Role__c(Name = 'Developer Inactive', Active__c = false, Price__c = 150, Cost__c = 100, Billing_Unit__c = 'Hour');
        insert new List<Resource_Role__c>{activeRole, inactiveRole};
    }

    @isTest
    static void testGetResourceRoles() {
        Test.startTest();
        List<Resource_Role__c> allRoles = ResourceRoleSelector.getResourceRoles(false);
        List<Resource_Role__c> activeRoles = ResourceRoleSelector.getResourceRoles(true);
        Test.stopTest();
        
        System.assertEquals(2, allRoles.size(), 'Should return all resource roles');
        System.assertEquals(1, activeRoles.size(), 'Should return only active resource roles');
        System.assertEquals('Developer Active', activeRoles[0].Name, 'Should match the active resource role name');
    }
}

@isTest
private class ResourceRoleServiceTest {
    @TestSetup
    static void setup() {
        Resource_Role__c role = new Resource_Role__c(Name = 'Developer Active', Active__c = true, Price__c = 150, Cost__c = 100, Billing_Unit__c = 'Hour');
        insert role;
    }

    @isTest
    static void testCreateResourceRole() {
        Test.startTest();
        Resource_Role__c newRole = ResourceRoleService.createResourceRole('New Role', 'Month', 5000, 3000, 'Onsite');
        Test.stopTest();
        
        System.assertNotEquals(null, newRole.Id, 'Resource Role should be inserted and have an ID');
        System.assertEquals('New Role', newRole.Name, 'Resource Role name should match');
        System.assertEquals(5000, newRole.Price__c, 'Price should match');
    }

    @isTest
    static void testUpdateResourceRole() {
        Resource_Role__c role = [SELECT Id FROM Resource_Role__c LIMIT 1];
        
        Test.startTest();
        Resource_Role__c updatedRole = ResourceRoleService.updateResourceRole(role.Id, 'Updated Role', 'Day', 1000, 700, 'Remote', false);
        Test.stopTest();
        
        System.assertEquals('Updated Role', updatedRole.Name, 'Resource Role name should be updated');
        System.assertEquals(false, updatedRole.Active__c, 'Resource Role should be deactivated');
        System.assertEquals(1000, updatedRole.Price__c, 'Price should be updated');
    }

    @isTest
    static void testDeleteResourceRole() {
        Resource_Role__c role = [SELECT Id FROM Resource_Role__c LIMIT 1];
        
        Test.startTest();
        ResourceRoleService.deleteResourceRole(role.Id);
        Test.stopTest();
        
        Integer count = [SELECT COUNT() FROM Resource_Role__c WHERE Id = :role.Id];
        System.assertEquals(0, count, 'Resource Role should be deleted successfully');
    }

    @isTest
    static void testGetMargin() {
        Resource_Role__c role = [SELECT Id FROM Resource_Role__c LIMIT 1];
        
        Test.startTest();
        Decimal margin = ResourceRoleService.getMargin(role.Id);
        Test.stopTest();
        
        System.assertEquals(50, margin, 'Margin should be Price - Cost (150 - 100)');
    }
}

@isTest
private class ResourceRoleControllerTest {

    @testSetup
    static void setup() {
        TestDataFactory.createResourceRole('Developer', 150, 100);
        Resource_Role__c inactive = TestDataFactory.createResourceRole('Tester', 100, 60);
        inactive.Active__c = false;
        update inactive;
    }

    @isTest
    static void testGetAllRoles() {
        Test.startTest();
        List<Resource_Role__c> all = ResourceRoleController.getResourceRoles(false);
        Test.stopTest();
        System.assertEquals(2, all.size(), 'Should return all 2 roles');
    }

    @isTest
    static void testGetActiveOnly() {
        Test.startTest();
        List<Resource_Role__c> active = ResourceRoleController.getResourceRoles(true);
        Test.stopTest();
        System.assertEquals(1, active.size(), 'Should return only 1 active role');
        System.assertEquals('Developer', active[0].Name, 'Active role should be Developer');
    }

    @isTest
    static void testGetRoleById() {
        Resource_Role__c dev = [SELECT Id FROM Resource_Role__c WHERE Name = 'Developer' LIMIT 1];
        Test.startTest();
        Resource_Role__c fetched = ResourceRoleController.getResourceRoleById(dev.Id);
        Test.stopTest();
        System.assertEquals('Developer', fetched.Name, 'Should return Developer role');
    }

    @isTest
    static void testCreateRole() {
        Test.startTest();
        Resource_Role__c created = ResourceRoleController.createResourceRole('Architect', 'Hour', 200, 120, 'Remote');
        Test.stopTest();
        System.assertNotEquals(null, created.Id, 'New role should be created');
        System.assertEquals('Architect', created.Name, 'Name should match');
    }

    @isTest
    static void testUpdateRole() {
        Resource_Role__c dev = [SELECT Id FROM Resource_Role__c WHERE Name = 'Developer' LIMIT 1];
        Test.startTest();
        Resource_Role__c updated = ResourceRoleController.updateResourceRole(dev.Id, 'Senior Developer', 'Hour', 180, 110, 'Onshore', true);
        Test.stopTest();
        System.assertEquals('Senior Developer', updated.Name, 'Name should be updated');
        System.assertEquals(180, updated.Price__c, 'Price should be updated');
    }

    @isTest
    static void testDeleteRole() {
        Resource_Role__c dev = [SELECT Id FROM Resource_Role__c WHERE Name = 'Developer' LIMIT 1];
        Test.startTest();
        ResourceRoleController.deleteResourceRole(dev.Id);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Resource_Role__c WHERE Name = 'Developer'], 'Developer role should be deleted');
    }

    @isTest
    static void testGetMargin() {
        Resource_Role__c dev = [SELECT Id FROM Resource_Role__c WHERE Name = 'Developer' LIMIT 1]; // price=150, cost=100
        Test.startTest();
        Decimal margin = ResourceRoleController.getMargin(dev.Id);
        Test.stopTest();
        // margin = ((150-100)/150)*100 = 33.33...
        System.assert(margin > 33.0 && margin < 34.0, 'Margin should be ~33.33%');
    }

    @isTest
    static void testGetMarginZeroCost() {
        Resource_Role__c role = new Resource_Role__c(Name = 'Zero Cost Role', Price__c = 100, Cost__c = 0, Billing_Unit__c = 'Hour', Active__c = true);
        insert role;
        Test.startTest();
        Decimal margin = ResourceRoleController.getMargin(role.Id);
        Test.stopTest();
        System.assertEquals(100.0, margin, 'Margin should be 100% when cost is 0');
    }

    @isTest
    static void testGetMarginZeroPrice() {
        Resource_Role__c role = new Resource_Role__c(Name = 'Zero Price Role', Price__c = 0, Cost__c = 0, Billing_Unit__c = 'Hour', Active__c = true);
        insert role;
        Test.startTest();
        Decimal margin = ResourceRoleController.getMargin(role.Id);
        Test.stopTest();
        System.assertEquals(0, margin, 'Margin should be 0 when price is 0');
    }
}

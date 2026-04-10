@isTest
private class AddonServiceTest {
    @TestSetup
    static void setup() {
        Add_on__c addon = new Add_on__c(Name = 'Support Plan Active', Active__c = true, Price__c = 100, Cost__c = 50, Billing_Unit__c = 'Month');
        insert addon;
    }

    @isTest
    static void testCreateAddon() {
        Test.startTest();
        Add_on__c newAddon = AddonService.createAddon('New Addon', 500, 200, 'Year', 'Annual subscription');
        Test.stopTest();
        
        System.assertNotEquals(null, newAddon.Id, 'Addon should be inserted and have an ID');
        System.assertEquals('New Addon', newAddon.Name, 'Addon name should match');
        System.assertEquals(500, newAddon.Price__c, 'Price should match');
    }

    @isTest
    static void testUpdateAddon() {
        Add_on__c addon = [SELECT Id FROM Add_on__c LIMIT 1];
        
        Test.startTest();
        Add_on__c updatedAddon = AddonService.updateAddon(addon.Id, 'Updated Addon', 150, 75, 'Month', 'Updated Description', false);
        Test.stopTest();
        
        System.assertEquals('Updated Addon', updatedAddon.Name, 'Addon name should be updated');
        System.assertEquals(false, updatedAddon.Active__c, 'Addon should be deactivated');
        System.assertEquals(150, updatedAddon.Price__c, 'Price should be updated');
    }

    @isTest
    static void testDeleteAddon() {
        Add_on__c addon = [SELECT Id FROM Add_on__c LIMIT 1];
        
        Test.startTest();
        AddonService.deleteAddon(addon.Id);
        Test.stopTest();
        
        Integer count = [SELECT COUNT() FROM Add_on__c WHERE Id = :addon.Id];
        System.assertEquals(0, count, 'Addon should be deleted successfully');
    }

    @isTest
    static void testGetMargin() {
        Add_on__c addon = [SELECT Id FROM Add_on__c LIMIT 1];
        
        Test.startTest();
        Decimal margin = AddonService.getMargin(addon.Id);
        Test.stopTest();
        
        System.assertEquals(50, margin, 'Margin should be Price - Cost (100 - 50)');
    }
}

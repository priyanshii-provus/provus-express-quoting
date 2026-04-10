@isTest
private class AddonSelectorTest {
    @TestSetup
    static void setup() {
        Add_on__c activeAddon = new Add_on__c(Name = 'Support Plan Active', Active__c = true, Price__c = 100, Cost__c = 50, Billing_Unit__c = 'Month');
        Add_on__c inactiveAddon = new Add_on__c(Name = 'Support Plan Inactive', Active__c = false, Price__c = 100, Cost__c = 50, Billing_Unit__c = 'Month');
        insert new List<Add_on__c>{activeAddon, inactiveAddon};
    }

    @isTest
    static void testGetAddons() {
        Test.startTest();
        List<Add_on__c> allAddons = AddonSelector.getAddons(false);
        List<Add_on__c> activeAddons = AddonSelector.getAddons(true);
        Test.stopTest();
        
        System.assertEquals(2, allAddons.size(), 'Should return all addons');
        System.assertEquals(1, activeAddons.size(), 'Should return only active addons');
        System.assertEquals('Support Plan Active', activeAddons[0].Name, 'Should match the active addon name');
    }
}

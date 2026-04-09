@isTest
private class AddonControllerTest {
  @testSetup
  static void setup() {
    Add_on__c active = new Add_on__c(
      Name = 'Support',
      Price__c = 1000,
      Cost__c = 600,
      Billing_Unit__c = 'Month',
      Active__c = true,
      Description__c = 'Support Package'
    );
    Add_on__c inactive = new Add_on__c(
      Name = 'Legacy Support',
      Price__c = 500,
      Cost__c = 300,
      Billing_Unit__c = 'Month',
      Active__c = false,
      Description__c = 'Legacy Add-on'
    );
    insert new List<Add_on__c>{ active, inactive };
  }

  @isTest
  static void testGetAllAddons() {
    Test.startTest();
    List<Add_on__c> all = AddonController.getAddons(false);
    Test.stopTest();
    System.assertEquals(2, all.size(), 'Should return 2 addons');
  }

  @isTest
  static void testGetActiveAddons() {
    Test.startTest();
    List<Add_on__c> active = AddonController.getAddons(true);
    Test.stopTest();
    System.assertEquals(1, active.size(), 'Should return 1 active addon');
    System.assertEquals(
      'Support',
      active[0].Name,
      'Active addon should be Support'
    );
  }

  @isTest
  static void testGetAddonById() {
    Add_on__c addon = [SELECT Id FROM Add_on__c WHERE Name = 'Support' LIMIT 1];
    Test.startTest();
    Add_on__c fetched = AddonController.getAddonById(addon.Id);
    Test.stopTest();
    System.assertEquals(
      'Support',
      fetched.Name,
      'Should fetch the correct addon'
    );
  }

  @isTest
  static void testCreateAddon() {
    Test.startTest();
    Add_on__c created = AddonController.createAddon(
      'Training',
      5000,
      3000,
      'Month',
      'User training sessions'
    );
    Test.stopTest();
    System.assertNotEquals(null, created.Id, 'Addon should be created');
    System.assertEquals(5000, created.Price__c, 'Price should match');
  }

  @isTest
  static void testUpdateAddon() {
    Add_on__c addon = [SELECT Id FROM Add_on__c WHERE Name = 'Support' LIMIT 1];
    Test.startTest();
    Add_on__c updated = AddonController.updateAddon(
      addon.Id,
      'Premium Support',
      2000,
      1000,
      'Month',
      'Better support',
      true
    );
    Test.stopTest();
    System.assertEquals(
      'Premium Support',
      updated.Name,
      'Name should be updated'
    );
    System.assertEquals(2000, updated.Price__c, 'Price should be updated');
  }

  @isTest
  static void testDeleteAddon() {
    Add_on__c addon = [
      SELECT Id
      FROM Add_on__c
      WHERE Name = 'Legacy Support'
      LIMIT 1
    ]; // delete inactive one
    Test.startTest();
    AddonController.deleteAddon(addon.Id);
    Test.stopTest();
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Add_on__c WHERE Name = 'Legacy Support'],
      'Addon should be deleted'
    );
  }

  @isTest
  static void testGetAddonMargin() {
    Add_on__c addon = [SELECT Id FROM Add_on__c WHERE Name = 'Support' LIMIT 1]; // price=1000, cost=600
    Test.startTest();
    Decimal margin = AddonController.getAddonMargin(addon.Id);
    Test.stopTest();
    // margin = ((1000-600)/1000)*100 = 40%
    System.assertEquals(40.0, margin, 'Margin should be 40%');
  }

  @isTest
  static void testGetMarginZeroPrice() {
    Add_on__c freeAddon = new Add_on__c(
      Name = 'Free Trial',
      Price__c = 0,
      Cost__c = 0,
      Billing_Unit__c = 'Month',
      Active__c = true
    );
    insert freeAddon;
    Test.startTest();
    Decimal margin = AddonController.getAddonMargin(freeAddon.Id);
    Test.stopTest();
    System.assertEquals(
      0,
      margin,
      'Margin should be 0 when price is 0 (avoid division by zero)'
    );
  }
}

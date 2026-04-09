@isTest
private class AdminSettingsControllerTest {
  @TestSetup
  static void setup() {
    Profile p = [
      SELECT Id
      FROM Profile
      WHERE Name = 'System Administrator'
      LIMIT 1
    ];
    User adminUser = new User(
      FirstName = 'Admin',
      LastName = 'Tester',
      Email = 'admintester_cs@testprovus.invalid',
      Username = 'admintester_cs@testprovus.invalid',
      Alias = 'admt',
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      ProfileId = p.Id,
      Express_Role__c = 'Admin'
    );
    insert adminUser;
  }

  @isTest
  static void testGetCompanySettings_Empty() {
    Test.startTest();
    Map<String, Object> result = AdminSettingsController.getCompanySettings();
    Test.stopTest();
    System.assertNotEquals(null, result, 'Should return a map even if empty');
  }

  @isTest
  static void testSaveAndGetCompanySettings() {
    User adminUser = [
      SELECT Id
      FROM User
      WHERE Username = 'admintester_cs@testprovus.invalid'
      LIMIT 1
    ];
    System.runAs(adminUser) {
      Test.startTest();
      AdminSettingsController.saveCompanySettings(
        'Test Corp',
        '+1-555-0100',
        'https://testcorp.com',
        'Technology',
        '100 Main St',
        'San Francisco',
        'CA',
        'USA',
        'America/Los_Angeles',
        'USD'
      );
      Test.stopTest();
      Map<String, Object> result = AdminSettingsController.getCompanySettings();
      System.assertEquals(
        'Test Corp',
        result.get('companyName'),
        'Company name should match'
      );
      System.assertEquals(
        'USD',
        result.get('currencyCode'),
        'Currency should match'
      );
      System.assertEquals(
        'Technology',
        result.get('industry'),
        'Industry should match'
      );
    }
  }

  @isTest
  static void testSaveCompanySettings_NonAdmin_Throws() {
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    User stdUser = new User(
      FirstName = 'Std',
      LastName = 'User',
      Email = 'stduser_cs@testprovus.invalid',
      Username = 'stduser_cs@testprovus.invalid',
      Alias = 'stdu',
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      ProfileId = p.Id,
      Express_Role__c = 'User'
    );
    insert stdUser;
    System.runAs(stdUser) {
      Test.startTest();
      Boolean threw = false;
      try {
        AdminSettingsController.saveCompanySettings(
          'Hack',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          ''
        );
      } catch (Exception e) {
        threw = true;
      }
      Test.stopTest();
      System.assert(threw, 'Non-admin save should throw for non-admin user');
    }
  }

  @isTest
  static void testGetAllPDFVersions() {
    Test.startTest();
    List<Map<String, Object>> result = AdminSettingsController.getAllPDFVersions();
    Test.stopTest();
    System.assertNotEquals(null, result, 'PDF version list should not be null');
  }
}

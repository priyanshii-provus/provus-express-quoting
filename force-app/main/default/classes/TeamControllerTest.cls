@isTest
public class TeamControllerTest {
  @testSetup
  static void setup() {
    Profile p = [
      SELECT Id
      FROM Profile
      WHERE Name = 'System Administrator'
      LIMIT 1
    ];
    User adminUser = new User(
      Alias = 'adm',
      Email = 'adminuser@testorg.com',
      EmailEncodingKey = 'UTF-8',
      FirstName = 'Admin',
      LastName = 'Testing',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = p.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'admintestuser' + DateTime.now().getTime() + '@testorg.com',
      Express_Role__c = 'Admin'
    );
    insert adminUser;

    User normalUser = new User(
      Alias = 'nrml',
      Email = 'normaluser@testorg.com',
      EmailEncodingKey = 'UTF-8',
      FirstName = 'Normal',
      LastName = 'Testing2',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = p.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'normaltestuser' + DateTime.now().getTime() + '@testorg.com',
      Express_Role__c = 'User'
    );
    insert normalUser;
  }

  @isTest
  static void testGetUsers() {
    Test.startTest();
    List<Map<String, Object>> users = TeamController.getUsers();
    Test.stopTest();
    System.assert(users.size() >= 2, 'Should return at least 2 users');
  }

  @isTest
  static void testGetCurrentUserRole() {
    User u = [
      SELECT Id
      FROM User
      WHERE Email = 'adminuser@testorg.com' AND Express_Role__c = 'Admin'
      LIMIT 1
    ];
    System.runAs(u) {
      Test.startTest();
      String role = TeamController.getCurrentUserRole();
      Test.stopTest();
      System.assertEquals('Admin', role);
      System.assert(TeamController.isAdmin(), 'Should be admin');
      System.assert(
        TeamController.isManagerOrAdmin(),
        'Should be manager or admin'
      );
    }
  }

  @isTest
  static void testUpdateUserDetailsAsAdmin() {
    User admin = [
      SELECT Id
      FROM User
      WHERE Email = 'adminuser@testorg.com' AND Express_Role__c = 'Admin'
      LIMIT 1
    ];
    User normal = [
      SELECT Id
      FROM User
      WHERE Email = 'normaluser@testorg.com' AND Express_Role__c = 'User'
      LIMIT 1
    ];

    System.runAs(admin) {
      Test.startTest();
      TeamController.updateUserDetails(
        normal.Id,
        'Manager',
        'UpdatedFirst',
        'UpdatedLast',
        'updated@testorg.com'
      );
      Test.stopTest();

      User updatedUser = [
        SELECT Express_Role__c, FirstName, LastName, Email
        FROM User
        WHERE Id = :normal.Id
      ];
      System.assertEquals('Manager', updatedUser.Express_Role__c);
      System.assertEquals('UpdatedFirst', updatedUser.FirstName);
      System.assertEquals('UpdatedLast', updatedUser.LastName);
      System.assertEquals('updated@testorg.com', updatedUser.Email);
    }
  }

  @isTest
  static void testCreateUserDetailsAsAdmin() {
    User admin = [
      SELECT Id
      FROM User
      WHERE Email = 'adminuser@testorg.com' AND Express_Role__c = 'Admin'
      LIMIT 1
    ];

    System.runAs(admin) {
      Test.startTest();
      TeamController.createUserDetails(
        'Manager',
        'NewFirst',
        'NewLast',
        'newuser123@testorg.com',
        'newuserxyz123@example.com'
      );
      Test.stopTest();

      User createdUser = [
        SELECT Express_Role__c, FirstName, LastName, Email, Username, Alias
        FROM User
        WHERE Email = 'newuser123@testorg.com'
        LIMIT 1
      ];
      System.assertEquals('Manager', createdUser.Express_Role__c);
      System.assertEquals('NewFirst', createdUser.FirstName);
      System.assertEquals('NewLast', createdUser.LastName);
      System.assertEquals('newuserxyz123@example.com', createdUser.Username);
    }
  }

  @isTest
  static void testUpdateUserDetailsAsNonAdmin() {
    User normal = [
      SELECT Id
      FROM User
      WHERE Email = 'normaluser@testorg.com' AND Express_Role__c = 'User'
      LIMIT 1
    ];
    User target = [
      SELECT Id
      FROM User
      WHERE Email = 'adminuser@testorg.com' AND Express_Role__c = 'Admin'
      LIMIT 1
    ];

    System.runAs(normal) {
      Boolean exceptionThrown = false;
      Test.startTest();
      try {
        TeamController.updateUserDetails(
          target.Id,
          'User',
          'F',
          'L',
          'e@e.com'
        );
      } catch (AuraHandledException e) {
        exceptionThrown = true;
      }
      Test.stopTest();

      System.assert(
        exceptionThrown,
        'Non-admin should not be able to update users'
      );
    }
  }

  @isTest
  static void testUpdateUserDetailsInvalidRole() {
    User admin = [
      SELECT Id
      FROM User
      WHERE Email = 'adminuser@testorg.com' AND Express_Role__c = 'Admin'
      LIMIT 1
    ];
    User normal = [
      SELECT Id
      FROM User
      WHERE Email = 'normaluser@testorg.com'
      LIMIT 1
    ];

    System.runAs(admin) {
      Boolean exceptionThrown = false;
      Test.startTest();
      try {
        TeamController.updateUserDetails(
          normal.Id,
          'SuperUser',
          'F',
          'L',
          'e@e.com'
        );
      } catch (AuraHandledException e) {
        exceptionThrown = true;
      }
      Test.stopTest();

      System.assert(exceptionThrown, 'Invalid role should throw exception');
    }
  }

  @isTest
  static void testFetchCurrentUserRole() {
    User u = [
      SELECT Id
      FROM User
      WHERE Email = 'adminuser@testorg.com' AND Express_Role__c = 'Admin'
      LIMIT 1
    ];
    System.runAs(u) {
      Test.startTest();
      String role = TeamController.fetchCurrentUserRole();
      Test.stopTest();
      System.assertEquals('Admin', role);
    }
  }
}

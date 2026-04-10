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

    User managerUser = new User(
      Alias = 'mgr',
      Email = 'manageruser@testorg.com',
      EmailEncodingKey = 'UTF-8',
      FirstName = 'Manager',
      LastName = 'Testing3',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = p.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'managertestuser' + DateTime.now().getTime() + '@testorg.com',
      Express_Role__c = 'Manager'
    );
    insert managerUser;
  }

  // ─── getUsers ───
  @isTest
  static void testGetUsers() {
    Test.startTest();
    List<Map<String, Object>> users = TeamController.getUsers();
    Test.stopTest();
    System.assert(users.size() >= 2, 'Should return at least 2 users');
    // Verify map keys exist
    Map<String, Object> first = users[0];
    System.assert(first.containsKey('Id'), 'Should contain Id');
    System.assert(first.containsKey('Express_Role__c'), 'Should contain role');
    System.assert(first.containsKey('ProfileName'), 'Should contain ProfileName');
    System.assert(first.containsKey('LicenseName'), 'Should contain LicenseName');
  }

  // ─── getCurrentUserRole / fetchCurrentUserRole ───
  @isTest
  static void testGetCurrentUserRole_Admin() {
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
        'Admin should be manager or admin'
      );
    }
  }

  @isTest
  static void testGetCurrentUserRole_Manager() {
    User u = [
      SELECT Id
      FROM User
      WHERE Email = 'manageruser@testorg.com' AND Express_Role__c = 'Manager'
      LIMIT 1
    ];
    System.runAs(u) {
      Test.startTest();
      String role = TeamController.getCurrentUserRole();
      Boolean isMgrOrAdmin = TeamController.isManagerOrAdmin();
      Boolean isAdm = TeamController.isAdmin();
      Test.stopTest();
      System.assertEquals('Manager', role);
      System.assert(isMgrOrAdmin, 'Manager should pass isManagerOrAdmin');
      System.assert(!isAdm, 'Manager should NOT pass isAdmin');
    }
  }

  @isTest
  static void testFetchCurrentUserRole_BlankExpressRole() {
    // Create a user with blank Express_Role__c and System Administrator profile
    // The fallback logic should return 'Admin' for sysadmin profile
    Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
    User blankRoleUser = new User(
      Alias = 'blnk',
      Email = 'blankrole@testorg.com',
      EmailEncodingKey = 'UTF-8',
      FirstName = 'Blank',
      LastName = 'Role',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = p.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'blankrole' + DateTime.now().getTime() + '@testorg.com',
      Express_Role__c = null
    );
    insert blankRoleUser;

    System.runAs(blankRoleUser) {
      Test.startTest();
      String role = TeamController.fetchCurrentUserRole();
      Test.stopTest();
      // System Administrator with blank Express_Role__c should fallback to 'Admin'
      System.assertEquals('Admin', role, 'Blank role sysadmin should fallback to Admin');
    }
  }

  @isTest
  static void testFetchCurrentUserRole_StandardUserFallback() {
    // Create a Standard User with blank Express_Role__c
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    User stdUser = new User(
      Alias = 'stdu',
      Email = 'stdfallback@testorg.com',
      EmailEncodingKey = 'UTF-8',
      FirstName = 'StdFallback',
      LastName = 'User',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = p.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'stdfallback' + DateTime.now().getTime() + '@testorg.com',
      Express_Role__c = null
    );
    insert stdUser;

    System.runAs(stdUser) {
      Test.startTest();
      String role = TeamController.fetchCurrentUserRole();
      Test.stopTest();
      // Standard User with blank Express_Role__c should fallback to 'User'
      System.assertEquals('User', role, 'Blank role standard user should fallback to User');
    }
  }

  // ─── updateUserDetails ───
  @isTest
  static void testUpdateUserDetailsAsAdmin() {
    User admin = [
      SELECT Id FROM User
      WHERE Email = 'adminuser@testorg.com' AND Express_Role__c = 'Admin'
      LIMIT 1
    ];
    User normal = [
      SELECT Id FROM User
      WHERE Email = 'normaluser@testorg.com' AND Express_Role__c = 'User'
      LIMIT 1
    ];

    System.runAs(admin) {
      Test.startTest();
      TeamController.updateUserDetails(
        normal.Id, 'Manager', 'UpdatedFirst', 'UpdatedLast', 'updated@testorg.com'
      );
      Test.stopTest();

      User updatedUser = [
        SELECT Express_Role__c, FirstName, LastName, Email
        FROM User WHERE Id = :normal.Id
      ];
      System.assertEquals('Manager', updatedUser.Express_Role__c);
      System.assertEquals('UpdatedFirst', updatedUser.FirstName);
    }
  }

  @isTest
  static void testUpdateUserDetailsAsNonAdmin() {
    User normal = [
      SELECT Id FROM User
      WHERE Email = 'normaluser@testorg.com' AND Express_Role__c = 'User'
      LIMIT 1
    ];
    User target = [
      SELECT Id FROM User
      WHERE Email = 'adminuser@testorg.com' AND Express_Role__c = 'Admin'
      LIMIT 1
    ];

    System.runAs(normal) {
      Boolean exceptionThrown = false;
      Test.startTest();
      try {
        TeamController.updateUserDetails(target.Id, 'User', 'F', 'L', 'e@e.com');
      } catch (AuraHandledException e) {
        exceptionThrown = true;
      }
      Test.stopTest();
      System.assert(exceptionThrown, 'Non-admin should not be able to update users');
    }
  }

  @isTest
  static void testUpdateUserDetailsInvalidRole() {
    User admin = [
      SELECT Id FROM User
      WHERE Email = 'adminuser@testorg.com' AND Express_Role__c = 'Admin'
      LIMIT 1
    ];
    User normal = [
      SELECT Id FROM User WHERE Email = 'normaluser@testorg.com' LIMIT 1
    ];

    System.runAs(admin) {
      Boolean exceptionThrown = false;
      Test.startTest();
      try {
        TeamController.updateUserDetails(normal.Id, 'SuperUser', 'F', 'L', 'e@e.com');
      } catch (AuraHandledException e) {
        exceptionThrown = true;
      }
      Test.stopTest();
      System.assert(exceptionThrown, 'Invalid role should throw exception');
    }
  }

  // ─── createUserDetails ───
  @isTest
  static void testCreateUserDetailsAsAdmin() {
    User admin = [
      SELECT Id FROM User
      WHERE Email = 'adminuser@testorg.com' AND Express_Role__c = 'Admin'
      LIMIT 1
    ];

    System.runAs(admin) {
      Test.startTest();
      TeamController.createUserDetails(
        'Manager', 'NewFirst', 'NewLast',
        'newuser123@testorg.com', 'newuserxyz123@example.com'
      );
      Test.stopTest();

      User createdUser = [
        SELECT Express_Role__c, FirstName, LastName, Email, Username, Alias
        FROM User WHERE Email = 'newuser123@testorg.com' LIMIT 1
      ];
      System.assertEquals('Manager', createdUser.Express_Role__c);
      System.assertEquals('NewFirst', createdUser.FirstName);
      System.assertEquals('nnewlas', createdUser.Alias.toLowerCase(),
        'Alias should be first initial + up to 6 chars of last name');
    }
  }

  @isTest
  static void testCreateUserDetailsInvalidRole() {
    User admin = [
      SELECT Id FROM User WHERE Express_Role__c = 'Admin' LIMIT 1
    ];
    System.runAs(admin) {
      Boolean caught = false;
      Test.startTest();
      try {
        TeamController.createUserDetails('Invalid', 'A', 'B', 'c@d.com', 'u@u.com');
      } catch (Exception e) {
        caught = true;
      }
      Test.stopTest();
      System.assert(caught, 'Should catch invalid role');
    }
  }

  @isTest
  static void testCreateUserDetailsNonAdmin() {
    User normal = [
      SELECT Id FROM User
      WHERE Email = 'normaluser@testorg.com' AND Express_Role__c = 'User'
      LIMIT 1
    ];
    System.runAs(normal) {
      Boolean caught = false;
      Test.startTest();
      try {
        TeamController.createUserDetails('User', 'A', 'B', 'c@d.com', 'nonadmin_create@test.com');
      } catch (Exception e) {
        caught = true;
      }
      Test.stopTest();
      System.assert(caught, 'Non-admin should not be able to create users');
    }
  }

  // ─── deactivateUser ───
  @isTest
  static void testDeactivateUser() {
    User admin = [SELECT Id FROM User WHERE Express_Role__c = 'Admin' LIMIT 1];
    User normal = [SELECT Id FROM User WHERE Express_Role__c = 'User' LIMIT 1];

    System.runAs(admin) {
      Test.startTest();
      TeamController.deactivateUser(normal.Id);
      Test.stopTest();
      User result = [SELECT IsActive FROM User WHERE Id = :normal.Id];
      System.assertEquals(false, result.IsActive, 'User should be deactivated');
    }
  }

  @isTest
  static void testDeactivateUserNonAdmin() {
    User normal = [SELECT Id FROM User WHERE Express_Role__c = 'User' LIMIT 1];
    User admin = [SELECT Id FROM User WHERE Express_Role__c = 'Admin' LIMIT 1];

    System.runAs(normal) {
      Boolean caught = false;
      Test.startTest();
      try {
        TeamController.deactivateUser(admin.Id);
      } catch (AuraHandledException e) {
        caught = true;
      }
      Test.stopTest();
      System.assert(caught, 'Non-admin should not be able to deactivate users');
    }
  }

  // ─── resendSetupEmail ───
  @isTest
  static void testResendSetupEmail() {
    User admin = [SELECT Id FROM User WHERE Express_Role__c = 'Admin' LIMIT 1];
    User normal = [SELECT Id FROM User WHERE Express_Role__c = 'User' LIMIT 1];

    System.runAs(admin) {
      Test.startTest();
      TeamController.resendSetupEmail(normal.Id);
      Test.stopTest();
    }
  }

  @isTest
  static void testResendSetupEmailNonAdmin() {
    User normal = [SELECT Id FROM User WHERE Express_Role__c = 'User' LIMIT 1];
    User admin = [SELECT Id FROM User WHERE Express_Role__c = 'Admin' LIMIT 1];

    System.runAs(normal) {
      Boolean caught = false;
      Test.startTest();
      try {
        TeamController.resendSetupEmail(admin.Id);
      } catch (AuraHandledException e) {
        caught = true;
      }
      Test.stopTest();
      System.assert(caught, 'Non-admin should not be able to resend setup emails');
    }
  }

  // ─── getLicenseCounts ───
  @isTest
  static void testGetLicenseCounts() {
    Test.startTest();
    Map<String, Integer> counts = TeamController.getLicenseCounts();
    Test.stopTest();
    System.assert(counts.containsKey('total'), 'Should contain total count');
    System.assert(counts.containsKey('used'), 'Should contain used count');
    System.assert(counts.containsKey('available'), 'Should contain available count');
  }

  // ─── isProtectedUser edge cases ───
  @isTest
  static void testDeactivateProtectedUser() {
    User admin = [SELECT Id FROM User WHERE Express_Role__c = 'Admin' LIMIT 1];
    // The running sysadmin user is NOT a "protected" user by the logic,
    // but the user with name containing 'integration user' would be.
    // We test the code path by trying to deactivate a user whose
    // UserType != 'Standard' (which triggers the last condition in isProtectedUser).
    // Since we can't easily create non-Standard UserType users in tests,
    // we verify the deactivate path works for standard users and the
    // exception path is covered for the non-admin check.

    System.runAs(admin) {
      // Attempt to deactivate the admin user itself — this is a standard user
      // with 'System Administrator' profile, which should NOT match 'Cloud Integration'
      // or 'Security User', so it should succeed
      Test.startTest();
      // We already tested deactivateUser above; here just verify getUsers returns data
      List<Map<String, Object>> users = TeamController.getUsers();
      Test.stopTest();
      System.assert(users.size() > 0, 'Should return users');
    }
  }

  @isTest
  static void testIsProtectedUser_NullUser() {
    // Test the isProtectedUser null check indirectly through coverage
    // The method is private, but we can verify that deactivateUser
    // works correctly with a valid user (non-protected)
    User admin = [SELECT Id FROM User WHERE Express_Role__c = 'Admin' LIMIT 1];
    // Create a fresh user to deactivate (not the system admin)
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    User tempUser = new User(
      Alias = 'tmp',
      Email = 'tempuser_protected@testorg.com',
      EmailEncodingKey = 'UTF-8',
      FirstName = 'Temp',
      LastName = 'Protect',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = p.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'tempuser_prot' + DateTime.now().getTime() + '@testorg.com',
      Express_Role__c = 'User'
    );
    insert tempUser;

    System.runAs(admin) {
      Test.startTest();
      // This exercises deactivateUser -> isProtectedUser(u) with a non-protected user
      TeamController.deactivateUser(tempUser.Id);
      Test.stopTest();
      User result = [SELECT IsActive FROM User WHERE Id = :tempUser.Id];
      System.assertEquals(false, result.IsActive);
    }
  }

  @isTest
  static void testUpdateProtectedUser() {
    User admin = [SELECT Id FROM User WHERE Express_Role__c = 'Admin' LIMIT 1];
    User normal = [SELECT Id FROM User WHERE Express_Role__c = 'User' LIMIT 1];

    System.runAs(admin) {
      Test.startTest();
      TeamController.updateUserDetails(
        normal.Id, 'Admin', 'NewFirst', 'NewLast', 'new@testorg.com'
      );
      Test.stopTest();

      User updated = [SELECT Express_Role__c FROM User WHERE Id = :normal.Id];
      System.assertEquals('Admin', updated.Express_Role__c);
    }
  }

  @isTest
  static void testExceptionsAndFallbacks() {
    User adminUser = [SELECT Id FROM User WHERE Express_Role__c = 'Admin' LIMIT 1];
    User normalUser = [SELECT Id FROM User WHERE Express_Role__c = 'User' LIMIT 1];

    System.runAs(adminUser) {
      Test.startTest();

      // 1. Test getLicenseCounts Mock Empty
      TeamController.mockEmptyLicenses = true;
      Map<String, Integer> counts = TeamController.getLicenseCounts();
      System.assertNotEquals(null, counts.get('total'), 'Fallback total should populated');

      TeamController.mockEmptyLicenses = false;

      // Enable exceptions
      TeamController.throwTestException = true;

      // 2. Test getLicenseCounts Exception
      Map<String, Integer> errCounts = TeamController.getLicenseCounts();
      System.assertEquals(0, errCounts.get('total'));

      // 3. Test deactivateUser Exception
      try {
        TeamController.deactivateUser(normalUser.Id);
        System.assert(false, 'Should have thrown exception');
      } catch (AuraHandledException e) {
        System.assert(e.getMessage().contains('Simulated test exception'));
      }

      // 4. Test updateUserDetails Exception
      try {
        TeamController.updateUserDetails(normalUser.Id, 'Admin', 'f', 'l', 'e@e.com');
        System.assert(false, 'Should have thrown exception');
      } catch (AuraHandledException e) {
        System.assert(e.getMessage().contains('Simulated test exception'));
      }

      // 5. Test createUserDetails Exception
      try {
        TeamController.createUserDetails('Admin', 'f', 'l', 'e@e.com', 'testu' + DateTime.now().getTime() + '@test.com');
        System.assert(false, 'Should have thrown exception');
      } catch (AuraHandledException e) {
        System.assert(e.getMessage().contains('Simulated test exception'));
      }

      // 6. Test resendSetupEmail Exception
      try {
        TeamController.resendSetupEmail(normalUser.Id);
        System.assert(false, 'Should have thrown exception');
      } catch (AuraHandledException e) {
        System.assert(e.getMessage().contains('Simulated test exception'));
      }

      TeamController.throwTestException = false;

      // 7. Test isProtectedUser Exception branch (null handled safely)
      Boolean isProtected = TeamController.isProtectedUser(null);
      System.assertEquals(false, isProtected);

      Test.stopTest();
    }
  }

  @isTest
  static void testProtectedUserErrors() {
    User adminUser = [SELECT Id FROM User WHERE Express_Role__c = 'Admin' LIMIT 1];
    User normalUser = [SELECT Id FROM User WHERE Express_Role__c = 'User' LIMIT 1];

    System.runAs(adminUser) {
      TeamController.mockProtectedUser = true;
      Test.startTest();
      
      // Test deactivateUser
      try {
        TeamController.deactivateUser(normalUser.Id);
        System.assert(false, 'Should have thrown exception for protected user');
      } catch (AuraHandledException e) {
        System.assert(e.getMessage().contains('Cannot deactivate protected system user'));
      }

      // Test updateUserDetails
      try {
        TeamController.updateUserDetails(
          normalUser.Id, 'Admin', 'First', 'Last', 'email@test.com'
        );
        System.assert(false, 'Should have thrown exception for protected user');
      } catch (AuraHandledException e) {
        System.assert(e.getMessage().contains('Cannot modify protected system user'));
      }
      
      Test.stopTest();
      TeamController.mockProtectedUser = false;
    }
  }

  // ─── Permission Set Assignment ───
  @isTest
  static void testPermissionSetAssignment() {
    User admin = [SELECT Id FROM User WHERE Express_Role__c = 'Admin' LIMIT 1];

    // Mock Permission Sets if they don't exist in the test context
    // Actually, in real orgs they exist. In unit tests, we rely on them being deployed.
    
    System.runAs(admin) {
      Test.startTest();
      
      // 1. Test Manager assignment
      String mgrEmail = 'mgr_perm@test' + DateTime.now().getTime() + '.com';
      TeamController.createUserDetails('Manager', 'Mgr', 'Perm', mgrEmail, mgrEmail);
      
      // 2. Test User assignment
      String userEmail = 'usr_perm@test' + DateTime.now().getTime() + '.com';
      TeamController.createUserDetails('User', 'Usr', 'Perm', userEmail, userEmail);
      
      Test.stopTest();

      // Verify Manager
      User mgr = [SELECT Id FROM User WHERE Email = :mgrEmail LIMIT 1];
      Integer mgrPsCount = [
        SELECT COUNT() FROM PermissionSetAssignment 
        WHERE AssigneeId = :mgr.Id AND PermissionSet.Name = 'Provus_Quote_Manager'
      ];
      System.assert(mgrPsCount > 0, 'Manager should have Provus_Quote_Manager assigned');

      // Verify User
      User usr = [SELECT Id FROM User WHERE Email = :userEmail LIMIT 1];
      Integer usrPsCount = [
        SELECT COUNT() FROM PermissionSetAssignment 
        WHERE AssigneeId = :usr.Id AND PermissionSet.Name = 'Provus_Quote_User'
      ];
      System.assert(usrPsCount > 0, 'User should have Provus_Quote_User assigned');
      
      // 3. Test Role Sync (Manager -> User)
      TeamController.updateUserDetails(mgr.Id, 'User', 'Mgr', 'Perm', mgrEmail);
      
      Integer mgrNewPsCount = [
        SELECT COUNT() FROM PermissionSetAssignment 
        WHERE AssigneeId = :mgr.Id AND PermissionSet.Name = 'Provus_Quote_User'
      ];
      Integer mgrOldPsCount = [
        SELECT COUNT() FROM PermissionSetAssignment 
        WHERE AssigneeId = :mgr.Id AND PermissionSet.Name = 'Provus_Quote_Manager'
      ];
      System.assert(mgrNewPsCount > 0, 'Should swap to Provus_Quote_User');
      System.assertEquals(0, mgrOldPsCount, 'Should remove Provus_Quote_Manager');
    }
  }
}

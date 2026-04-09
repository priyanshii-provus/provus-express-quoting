public with sharing class TeamController {
  private static final Set<String> VALID_ROLES = new Set<String>{
    'Admin',
    'Manager',
    'User'
  };

  /**
   * Returns total, used, and available Salesforce license counts.
   */
  @AuraEnabled(cacheable=true)
  public static Map<String, Integer> getLicenseCounts() {
    Map<String, Integer> result = new Map<String, Integer>();
    try {
      // Find the primary Salesforce license (usually 'Salesforce' or 'Salesforce Platform')
      List<UserLicense> licenses = [
        SELECT Name, TotalLicenses, UsedLicenses
        FROM UserLicense
        WHERE Name LIKE 'Salesforce%'
        ORDER BY UsedLicenses DESC, TotalLicenses DESC
      ];

      if (!licenses.isEmpty()) {
        // Return the license with the most seats as the "Total Seats"
        UserLicense primary = licenses[0];
        Integer total = primary.TotalLicenses;
        // Manually count active users with this license for better accuracy in scratch orgs
        Integer used = [
          SELECT COUNT()
          FROM User
          WHERE
            IsActive = TRUE
            AND (Profile.UserLicense.Name = :primary.Name
            OR Profile.Name = 'System Administrator')
        ];

        result.put('total', total);
        result.put('used', used);
        result.put('available', Math.max(0, total - used));
        System.debug(
          'License Found: ' +
            primary.Name +
            ' Tot:' +
            total +
            ' Actively Used:' +
            used
        );
      } else {
        // Fallback: count active human users
        Integer humanCount = [
          SELECT COUNT()
          FROM User
          WHERE IsActive = TRUE AND UserType = 'Standard'
        ];
        result.put('total', Math.max(2, humanCount));
        result.put('used', humanCount);
        result.put('available', Math.max(0, 2 - humanCount));
      }
    } catch (Exception e) {
      result.put('total', 0);
      result.put('used', 0);
      result.put('available', 0);
    }
    return result;
  }

  /**
   * Deactivates (disables) a user. Admin only.
   */
  @AuraEnabled
  public static void deactivateUser(Id userId) {
    if (!isAdmin()) {
      throw new AuraHandledException('Only Admins can deactivate users.');
    }

    User u = [
      SELECT Name, UserType, Profile.Name
      FROM User
      WHERE Id = :userId
      LIMIT 1
    ];
    if (isProtectedUser(u)) {
      throw new AuraHandledException(
        'Cannot deactivate protected system user: ' + u.Name
      );
    }

    try {
      update new User(Id = userId, IsActive = false);
    } catch (Exception e) {
      AuraHandledException ex = new AuraHandledException(e.getMessage());
      ex.setMessage(e.getMessage());
      throw ex;
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Map<String, Object>> getUsers() {
    List<Map<String, Object>> result = new List<Map<String, Object>>();
    List<User> users = [
      SELECT
        Id,
        FirstName,
        LastName,
        Name,
        Email,
        Username,
        Express_Role__c,
        IsActive,
        LastLoginDate,
        Profile.Name,
        Profile.UserLicense.Name
      FROM User
      WHERE IsActive = TRUE AND UserType = 'Standard'
      ORDER BY Name ASC
    ];
    for (User u : users) {
      Map<String, Object> row = new Map<String, Object>();
      row.put('Id', u.Id);
      row.put('FirstName', u.FirstName);
      row.put('LastName', u.LastName);
      row.put('Name', u.Name);
      row.put('Email', u.Email);
      row.put('Username', u.Username);
      row.put(
        'Express_Role__c',
        String.isBlank(u.Express_Role__c) ? 'User' : u.Express_Role__c
      );
      row.put('IsActive', u.IsActive);
      row.put('LastLoginDate', u.LastLoginDate);
      row.put('ProfileName', u.Profile.Name);
      row.put('LicenseName', u.Profile.UserLicense.Name);
      result.add(row);
    }
    return result;
  }

  @AuraEnabled
  public static void updateUserDetails(
    Id userId,
    String newRole,
    String firstName,
    String lastName,
    String email
  ) {
    if (!VALID_ROLES.contains(newRole)) {
      throw new AuraHandledException(
        'Invalid role: ' + newRole + '. Must be Admin, Manager, or User.'
      );
    }
    if (!isAdmin()) {
      throw new AuraHandledException('Only Admins can update users.');
    }

    User u = [
      SELECT Name, UserType, Profile.Name
      FROM User
      WHERE Id = :userId
      LIMIT 1
    ];
    if (isProtectedUser(u)) {
      throw new AuraHandledException(
        'Cannot modify protected system user: ' + u.Name
      );
    }

    try {
      update new User(
        Id = userId,
        Express_Role__c = newRole,
        FirstName = firstName,
        LastName = lastName,
        Email = email
      );
    } catch (Exception e) {
      AuraHandledException ex = new AuraHandledException(e.getMessage());
      ex.setMessage(e.getMessage());
      throw ex;
    }
  }

  @AuraEnabled
  public static void createUserDetails(
    String newRole,
    String firstName,
    String lastName,
    String email,
    String username
  ) {
    if (!VALID_ROLES.contains(newRole)) {
      throw new AuraHandledException(
        'Invalid role: ' + newRole + '. Must be Admin, Manager, or User.'
      );
    }
    if (!isAdmin()) {
      throw new AuraHandledException('Only Admins can create users.');
    }

    try {
      Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
      String alias = '';
      if (String.isNotBlank(firstName) && firstName.length() >= 1) {
        alias += firstName.substring(0, 1);
      }
      if (String.isNotBlank(lastName)) {
        alias += lastName.substring(0, Math.min(lastName.length(), 6));
      }
      alias = alias.toLowerCase();

      User newUser = new User(
        FirstName = firstName,
        LastName = lastName,
        Email = email,
        Username = username,
        Alias = alias,
        TimeZoneSidKey = 'America/Los_Angeles',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        ProfileId = p.Id,
        Express_Role__c = newRole
      );
      insert newUser;
      // Send password reset / setup email so user can log in
      if (!Test.isRunningTest()) {
        System.resetPassword(newUser.Id, true);
      }
    } catch (Exception e) {
      AuraHandledException ex = new AuraHandledException(e.getMessage());
      ex.setMessage(e.getMessage());
      throw ex;
    }
  }

  @AuraEnabled
  public static void resendSetupEmail(Id userId) {
    if (!isAdmin()) {
      throw new AuraHandledException('Only Admins can resend setup emails.');
    }
    try {
      System.resetPassword(userId, true);
    } catch (Exception e) {
      AuraHandledException ex = new AuraHandledException(e.getMessage());
      ex.setMessage(e.getMessage());
      throw ex;
    }
  }

  /**
   * Wire-adapter friendly cacheable method for LWC.
   */
  @AuraEnabled(cacheable=true)
  public static String getCurrentUserRole() {
    return fetchCurrentUserRole();
  }

  /**
   * Internal non-cacheable method used by Apex callers (e.g. isAdmin).
   * Avoids the restriction that cacheable methods cannot be called
   * from within DML-containing transactions.
   */
  public static String fetchCurrentUserRole() {
    User u = [
      SELECT Express_Role__c, Profile.Name
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    if (String.isNotBlank(u.Express_Role__c)) {
      return u.Express_Role__c;
    }
    // Fallback for new orgs: System Admins are always Admins
    if (u.Profile.Name == 'System Administrator') {
      return 'Admin';
    }
    return 'User';
  }

  public static Boolean isAdmin() {
    String role = fetchCurrentUserRole();
    return role == 'Admin';
  }

  public static Boolean isManagerOrAdmin() {
    String role = fetchCurrentUserRole();
    return role == 'Admin' || role == 'Manager';
  }

  private static Boolean isProtectedUser(User u) {
    if (u == null)
      return false;
    String profileName = u.Profile.Name;
    String userType = u.UserType;

    // Block modification of core system profiles/users
    return profileName.contains('Cloud Integration') ||
      profileName.contains('Security User') ||
      userType == 'Standard' &&
      (u.Name.toLowerCase().contains('security user') ||
      u.Name.toLowerCase().contains('integration user')) ||
      userType != 'Standard';
  }
}

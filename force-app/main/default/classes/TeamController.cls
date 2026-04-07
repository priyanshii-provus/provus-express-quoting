public with sharing class TeamController {
    
    private static final Set<String> VALID_ROLES = new Set<String>{'Admin', 'Manager', 'User'};
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getUsers() {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        List<User> users = [
            SELECT Id, FirstName, LastName, Name, Email, Username, Express_Role__c, IsActive, LastLoginDate 
            FROM User 
            WHERE IsActive = true AND UserType = 'Standard'
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
            row.put('Express_Role__c', String.isBlank(u.Express_Role__c) ? 'User' : u.Express_Role__c);
            row.put('IsActive', u.IsActive);
            row.put('LastLoginDate', u.LastLoginDate);
            result.add(row);
        }
        return result;
    }
    
    @AuraEnabled
    public static void updateUserDetails(Id userId, String newRole, String firstName, String lastName, String email) {
        if (!VALID_ROLES.contains(newRole)) {
            throw new AuraHandledException('Invalid role: ' + newRole + '. Must be Admin, Manager, or User.');
        }
        if (!isAdmin()) {
            throw new AuraHandledException('Only Admins can update users.');
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
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void createUserDetails(String newRole, String firstName, String lastName, String email, String username) {
        if (!VALID_ROLES.contains(newRole)) {
            throw new AuraHandledException('Invalid role: ' + newRole + '. Must be Admin, Manager, or User.');
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

            insert new User(
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
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
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
        User u = [SELECT Express_Role__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        return String.isBlank(u.Express_Role__c) ? 'User' : u.Express_Role__c;
    }
    
    public static Boolean isAdmin() {
        String role = fetchCurrentUserRole();
        return role == 'Admin';
    }

    public static Boolean isManagerOrAdmin() {
        String role = fetchCurrentUserRole();
        return role == 'Admin' || role == 'Manager';
    }
}

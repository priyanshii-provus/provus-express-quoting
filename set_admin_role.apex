User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
u.Express_Role__c = 'Admin';
update u;
System.debug('User role updated to Admin for: ' + u.Id);

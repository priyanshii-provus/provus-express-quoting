public without sharing class AccountController {
  @AuraEnabled(cacheable=true)
  public static List<Account> getAccounts() {
    return [
      SELECT Id, Name, Industry, Phone
      FROM Account
      ORDER BY Name ASC
      LIMIT 100
    ];
  }

  @AuraEnabled
  public static void deleteAccount(Id accountId) {
    delete new Account(Id = accountId);
  }
}

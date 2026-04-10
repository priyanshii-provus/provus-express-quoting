@isTest
private class AccountControllerTest {
  @testSetup
  static void setup() {
    List<Account> accs = new List<Account>();
    for (Integer i = 0; i < 5; i++) {
      accs.add(
        new Account(
          Name = 'Test Account ' + i,
          Industry = 'Technology',
          Phone = '555-010' + i
        )
      );
    }
    insert accs;
  }

  @isTest
  static void testGetAccounts() {
    Test.startTest();
    List<Account> results = AccountController.getAccounts();
    Test.stopTest();

    System.assertEquals(5, results.size(), 'Should return exactly 5 accounts');
  }

  @isTest
  static void testDeleteAccount() {
    Account acc = [SELECT Id FROM Account LIMIT 1];

    Test.startTest();
    AccountController.deleteAccount(acc.Id);
    Test.stopTest();

    List<Account> remaining = [SELECT Id FROM Account WHERE Id = :acc.Id];
    System.assertEquals(0, remaining.size(), 'Account should be deleted');
    System.assertEquals(
      4,
      [SELECT COUNT() FROM Account],
      'Should be 4 accounts left'
    );
  }
}

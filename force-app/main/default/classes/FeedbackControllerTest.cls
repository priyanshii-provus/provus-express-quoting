@isTest
private class FeedbackControllerTest {
  @testSetup
  static void setup() {
    List<Provus_Feedback__c> feeds = new List<Provus_Feedback__c>();
    for (Integer i = 0; i < 3; i++) {
      feeds.add(
        new Provus_Feedback__c(
          Feedback_Text__c = 'Great app ' + i,
          User_Name__c = 'Test User',
          Card_Color__c = '#ffffff'
        )
      );
    }
    insert feeds;
  }

  @isTest
  static void testGetFeedbacks() {
    Test.startTest();
    List<Provus_Feedback__c> results = FeedbackController.getFeedbacks();
    Test.stopTest();

    System.assertEquals(3, results.size(), 'Should return 3 feedback records');
  }

  @isTest
  static void testSaveFeedback() {
    Test.startTest();
    FeedbackController.saveFeedback('Awesome feature!', '#ff0000');
    Test.stopTest();

    List<Provus_Feedback__c> allFeeds = [
      SELECT Id, Feedback_Text__c, Card_Color__c
      FROM Provus_Feedback__c
    ];
    Boolean found = false;
    for (Provus_Feedback__c f : allFeeds) {
      if (f.Feedback_Text__c == 'Awesome feature!') {
        found = true;
        System.assertEquals('#ff0000', f.Card_Color__c, 'Card color should match');
      }
    }
    System.assert(found, 'New feedback should be saved');
  }

  @isTest
  static void testDeleteFeedback() {
    Provus_Feedback__c feed = [
      SELECT Id
      FROM Provus_Feedback__c
      LIMIT 1
    ];

    Test.startTest();
    FeedbackController.deleteFeedback(feed.Id);
    Test.stopTest();

    List<Provus_Feedback__c> remaining = [
      SELECT Id
      FROM Provus_Feedback__c
      WHERE Id = :feed.Id
    ];
    System.assertEquals(0, remaining.size(), 'Feedback should be deleted');
  }

  @isTest
  static void testGetCurrentUserName() {
    Test.startTest();
    String name = FeedbackController.getCurrentUserName();
    Test.stopTest();

    System.assertEquals(UserInfo.getName(), name, 'Should return context user name');
  }
}

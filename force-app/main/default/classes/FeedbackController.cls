public with sharing class FeedbackController {
  @AuraEnabled(cacheable=true)
  public static List<Provus_Feedback__c> getFeedbacks() {
    return [
      SELECT Id, Feedback_Text__c, User_Name__c, Card_Color__c, CreatedDate
      FROM Provus_Feedback__c
      ORDER BY CreatedDate DESC
      LIMIT 100
    ];
  }

  @AuraEnabled
  public static void saveFeedback(String text, String color) {
    Provus_Feedback__c feedback = new Provus_Feedback__c();
    feedback.Feedback_Text__c = text;
    feedback.User_Name__c = UserInfo.getName();
    feedback.Card_Color__c = color;
    insert feedback;
  }

  @AuraEnabled
  public static void deleteFeedback(Id feedbackId) {
    delete [SELECT Id FROM Provus_Feedback__c WHERE Id = :feedbackId];
  }

  @AuraEnabled(cacheable=true)
  public static String getCurrentUserName() {
    return UserInfo.getName();
  }
}

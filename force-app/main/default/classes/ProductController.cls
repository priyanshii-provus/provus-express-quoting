public without sharing class ProductController {
  @AuraEnabled(cacheable=true)
  public static List<Product2> getProducts(Boolean activeOnly) {
    return ProductSelector.getProducts(activeOnly);
  }

  @AuraEnabled
  public static Product2 getProductById(Id productId) {
    return ProductSelector.getProductById(productId);
  }

  @AuraEnabled
  public static Product2 createProduct(
    String name,
    String productCode,
    String description,
    String family,
    Decimal cost,
    Decimal price
  ) {
    return ProductService.createProduct(name, productCode, description, family, cost, price);
  }

  @AuraEnabled
  public static Product2 updateProduct(
    Id productId,
    String name,
    String productCode,
    String description,
    String family,
    Boolean isActive
  ) {
    return ProductService.updateProduct(productId, name, productCode, description, family, isActive);
  }

  @AuraEnabled
  public static void deleteProduct(Id productId) {
    ProductService.deleteProduct(productId);
  }

  @AuraEnabled
  public static void updateProducts(List<Product2> products) {
    ProductService.updateProducts(products);
  }

  @AuraEnabled(cacheable=true)
  public static List<PricebookEntry> getPricebookEntries(Id pricebookId) {
    return ProductSelector.getPricebookEntries(pricebookId);
  }

  @AuraEnabled
  public static PricebookEntry createPricebookEntry(
    Id product2Id,
    Id pricebook2Id,
    Decimal unitPrice
  ) {
    return ProductService.createPricebookEntry(product2Id, pricebook2Id, unitPrice);
  }

  @AuraEnabled
  public static Integer importProducts(List<Map<String, String>> products) {
    return ProductService.importProducts(products);
  }
}

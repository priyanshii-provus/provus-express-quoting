public with sharing class ProductController {
    
    @AuraEnabled(cacheable=true)
    public static List<Product2> getProducts(Boolean activeOnly) {
        String query = 'SELECT Id, Name, ProductCode, Description, Family, IsActive, ' +
                      'CreatedDate, LastModifiedDate ' +
                      'FROM Product2';
        
        if (activeOnly != null && activeOnly) {
            query += ' WHERE IsActive = true';
        }
        
        query += ' ORDER BY Name ASC';
        
        return Database.query(query);
    }
    
    @AuraEnabled
    public static Product2 getProductById(Id productId) {
        return [SELECT Id, Name, ProductCode, Description, Family, IsActive,
                CreatedDate, LastModifiedDate
                FROM Product2 WHERE Id = :productId];
    }
    
    @AuraEnabled
    public static Product2 createProduct(String name, String productCode, 
                                          String description, String family) {
        Product2 product = new Product2(
            Name = name,
            ProductCode = productCode,
            Description = description,
            Family = family,
            IsActive = true
        );
        insert product;
        return product;
    }
    
    @AuraEnabled
    public static Product2 updateProduct(Id productId, String name, String productCode,
                                          String description, String family, Boolean isActive) {
        Product2 product = new Product2(
            Id = productId,
            Name = name,
            ProductCode = productCode,
            Description = description,
            Family = family,
            IsActive = isActive
        );
        update product;
        return getProductById(productId);
    }
    
    @AuraEnabled
    public static void deleteProduct(Id productId) {
        delete new Product2(Id = productId);
    }
    
    @AuraEnabled
    public static void updateProducts(List<Product2> products) {
        update products;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<PricebookEntry> getPricebookEntries(Id pricebookId) {
        if (pricebookId == null) {
            try {
                pricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
            } catch (Exception e) {
                pricebookId = Test.getStandardPricebookId();
            }
        }
        return [SELECT Id, Product2Id, Product2.Name, Product2.ProductCode, 
                Product2.Family, UnitPrice, IsActive
                FROM PricebookEntry 
                WHERE Pricebook2Id = :pricebookId AND IsActive = true
                ORDER BY Product2.Name ASC];
    }
    
    @AuraEnabled
    public static PricebookEntry createPricebookEntry(Id product2Id, Id pricebook2Id, 
                                                       Decimal unitPrice) {
        if (pricebook2Id == null) {
            try {
                pricebook2Id = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
            } catch (Exception e) {
                pricebook2Id = Test.getStandardPricebookId();
            }
        }
        PricebookEntry pbe = new PricebookEntry(
            Product2Id = product2Id,
            Pricebook2Id = pricebook2Id,
            UnitPrice = unitPrice,
            IsActive = true
        );
        insert pbe;
        return pbe;
    }
}

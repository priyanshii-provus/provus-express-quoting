@isTest
private class ProductSelectorTest {
    @TestSetup
    static void setup() {
        Product2 activeProd = new Product2(Name = 'Test Product Active', ProductCode = 'TPA1', IsActive = true, Family = 'Software');
        Product2 inactiveProd = new Product2(Name = 'Test Product Inactive', ProductCode = 'TPI1', IsActive = false, Family = 'Hardware');
        insert new List<Product2>{activeProd, inactiveProd};

        Id stdPbId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = stdPbId, Product2Id = activeProd.Id, UnitPrice = 100, IsActive = true);
        insert pbe;
    }

    @isTest
    static void testGetProducts() {
        Test.startTest();
        List<Product2> allProds = ProductSelector.getProducts(false);
        List<Product2> activeProds = ProductSelector.getProducts(true);
        Test.stopTest();
        
        System.assertEquals(2, allProds.size(), 'Should return all standard products excluding placeholders');
        System.assertEquals(1, activeProds.size(), 'Should return only active standard products excluding placeholders');
    }

    @isTest
    static void testGetProductById() {
        Product2 prod = [SELECT Id FROM Product2 WHERE Name = 'Test Product Active' LIMIT 1];
        
        Test.startTest();
        Product2 result = ProductSelector.getProductById(prod.Id);
        Test.stopTest();
        
        System.assertEquals(prod.Id, result.Id, 'Should return the correct product by ID');
    }

    @isTest
    static void testGetPricebookEntries() {
        Id stdPbId = Test.getStandardPricebookId();
        
        Test.startTest();
        List<PricebookEntry> entries = ProductSelector.getPricebookEntries(stdPbId);
        List<PricebookEntry> fallbackEntries = ProductSelector.getPricebookEntries(null);
        Test.stopTest();
        
        System.assert(entries.size() > 0, 'Should return pricebook entries for standard pricebook');
        System.assert(fallbackEntries.size() > 0, 'Fallback standard pricebook should also return entries');
    }
}

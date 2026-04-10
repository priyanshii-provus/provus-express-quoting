@isTest
private class ProductServiceTest {
    @TestSetup
    static void setup() {
        Product2 activeProd = new Product2(Name = 'Test Product Active', ProductCode = 'TPA1', IsActive = true, Family = 'Software');
        insert activeProd;
        Id stdPbId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = stdPbId, Product2Id = activeProd.Id, UnitPrice = 100, IsActive = true);
        insert pbe;
    }

    @isTest
    static void testCreateProduct() {
        Test.startTest();
        Product2 newProd = ProductService.createProduct('New Test Prod', 'NTP1', 'Description', 'Hardware', 0, 150.0);
        Test.stopTest();
        
        System.assertNotEquals(null, newProd.Id, 'Product should be inserted and have an ID');
        System.assertEquals('New Test Prod', newProd.Name, 'Product name should match');
        // Validate PricebookEntry creation
        List<PricebookEntry> pbes = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Product2Id = :newProd.Id];
        System.assertEquals(1, pbes.size(), 'Pricebook entry should be created automatically');
        System.assertEquals(150.0, pbes[0].UnitPrice, 'Unit price should match the initial price provided');
    }

    @isTest
    static void testUpdateProduct() {
        Product2 prod = [SELECT Id FROM Product2 WHERE Name = 'Test Product Active' LIMIT 1];
        
        Test.startTest();
        Product2 updatedProd = ProductService.updateProduct(prod.Id, 'Updated Test Prod', 'UTP1', 'Updated Desc', 'Software', false);
        Test.stopTest();
        
        System.assertEquals('Updated Test Prod', updatedProd.Name, 'Product name should be updated');
        System.assertEquals(false, updatedProd.IsActive, 'Product should be deactivated');
    }
}

@isTest
private class ProductControllerTest {

    @testSetup
    static void setup() {
        // Use factory which correctly handles pricebook in tests
        Id pricebookId = Test.getStandardPricebookId();

        Product2 activeProd = new Product2(Name = 'Active Prod', ProductCode = 'P1', IsActive = true);
        Product2 inactiveProd = new Product2(Name = 'Inactive Prod', ProductCode = 'P2', IsActive = false);
        insert new List<Product2>{activeProd, inactiveProd};

        // Only active products can have PricebookEntry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = activeProd.Id,
            UnitPrice = 500,
            IsActive = true
        );
        insert pbe;
    }

    @isTest
    static void testGetAllProducts() {
        Test.startTest();
        List<Product2> all = ProductController.getProducts(false);
        Test.stopTest();
        System.assertEquals(2, all.size(), 'Should return both products');
    }

    @isTest
    static void testGetActiveProducts() {
        Test.startTest();
        List<Product2> active = ProductController.getProducts(true);
        Test.stopTest();
        System.assertEquals(1, active.size(), 'Should return only the active product');
        System.assertEquals('Active Prod', active[0].Name, 'Active product name should match');
    }

    @isTest
    static void testGetProductById() {
        Product2 prod = [SELECT Id FROM Product2 WHERE Name = 'Active Prod' LIMIT 1];
        Test.startTest();
        Product2 fetched = ProductController.getProductById(prod.Id);
        Test.stopTest();
        System.assertEquals('Active Prod', fetched.Name, 'Should retrieve the correct product');
    }

    @isTest
    static void testCreateProduct() {
        Test.startTest();
        Product2 created = ProductController.createProduct('New Product', 'NP001', 'A new product', 'Software');
        Test.stopTest();
        System.assertNotEquals(null, created.Id, 'Product should be created');
        System.assertEquals(true, created.IsActive, 'Should be active by default');
    }

    @isTest
    static void testUpdateProduct() {
        Product2 prod = [SELECT Id FROM Product2 WHERE Name = 'Active Prod' LIMIT 1];
        Test.startTest();
        Product2 updated = ProductController.updateProduct(prod.Id, 'Renamed Prod', 'RP001', 'New Desc', 'Hardware', false);
        Test.stopTest();
        System.assertEquals('Renamed Prod', updated.Name, 'Name should be updated');
        System.assertEquals(false, updated.IsActive, 'Product should be deactivated');
    }

    @isTest
    static void testDeleteProduct() {
        // Insert a fresh one so we can safely delete without breaking the pricebook entry
        Product2 temp = new Product2(Name = 'Temp Prod', IsActive = true);
        insert temp;

        Test.startTest();
        ProductController.deleteProduct(temp.Id);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Product2 WHERE Id = :temp.Id], 'Product should be deleted');
    }

    @isTest
    static void testGetPricebookEntries() {
        Test.startTest();
        List<PricebookEntry> entries = ProductController.getPricebookEntries(null); // null falls back to standard pricebook
        Test.stopTest();
        System.assertEquals(1, entries.size(), 'Should return 1 pricebook entry');
        System.assertEquals(500.0, entries[0].UnitPrice, 'Unit price should match');
    }

    @isTest
    static void testCreatePricebookEntry() {
        Product2 inactiveProd = [SELECT Id FROM Product2 WHERE Name = 'Inactive Prod' LIMIT 1];
        // Make it active so it can be in a pricebook
        inactiveProd.IsActive = true;
        update inactiveProd;

        Test.startTest();
        PricebookEntry pbe = ProductController.createPricebookEntry(inactiveProd.Id, null, 1500);
        Test.stopTest();

        System.assertNotEquals(null, pbe.Id, 'PricebookEntry should be created');
        System.assertEquals(1500, pbe.UnitPrice, 'Unit price should be 1500');
    }
}

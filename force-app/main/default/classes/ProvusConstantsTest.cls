@isTest
private class ProvusConstantsTest {
    @isTest
    static void testConstants() {
        // Just instantiate to ensure 100% test coverage of the class structure
        ProvusConstants constantsInstance = new ProvusConstants();
        
        // Assert that at least some key constants contain expected values
        System.assertEquals('Draft', ProvusConstants.QUOTE_STATUS_DRAFT, 'Expected Draft status');
        System.assertEquals('Submitted', ProvusConstants.QUOTE_STATUS_SUBMITTED, 'Expected Submitted status');
        System.assertEquals('Approved', ProvusConstants.QUOTE_STATUS_APPROVED, 'Expected Approved status');
        System.assertEquals('Rejected', ProvusConstants.QUOTE_STATUS_REJECTED, 'Expected Rejected status');
        System.assertEquals('Pending Approval', ProvusConstants.QUOTE_STATUS_PENDING, 'Expected Pending status');
        System.assertEquals('Needs Review', ProvusConstants.QUOTE_STATUS_NEEDS_REVIEW, 'Expected Needs Review status');
        
        System.assertEquals('Product', ProvusConstants.ITEM_TYPE_PRODUCT, 'Expected Product item type');
        System.assertEquals('Labor', ProvusConstants.ITEM_TYPE_LABOR, 'Expected Labor item type');
        System.assertEquals('Add-on', ProvusConstants.ITEM_TYPE_ADDON, 'Expected Add-on item type');
    }
}

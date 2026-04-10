public inherited sharing class ProductSelector {
  public static List<Product2> getProducts(Boolean activeOnly) {
    String query =
      'SELECT Id, Name, ProductCode, Description, Family, IsActive, ' +
      'CreatedDate, LastModifiedDate ' +
      'FROM Product2';

    if (activeOnly != null && activeOnly) {
      query += ' WHERE IsActive = true AND Name != \'Resource Placeholder\'';
    } else {
      query += ' WHERE Name != \'Resource Placeholder\'';
    }
    query += ' ORDER BY Name ASC';
    return Database.query(query);
  }

  public static Product2 getProductById(Id productId) {
    return [
      SELECT
        Id,
        Name,
        ProductCode,
        Description,
        Family,
        IsActive,
        CreatedDate,
        LastModifiedDate
      FROM Product2
      WHERE Id = :productId
    ];
  }

  public static List<PricebookEntry> getPricebookEntries(Id pricebookId) {
    return [
      SELECT
        Id,
        Product2Id,
        Product2.Name,
        Product2.ProductCode,
        Product2.Family,
        UnitPrice,
        IsActive
      FROM PricebookEntry
      WHERE
        Pricebook2Id = :pricebookId
        AND IsActive = TRUE
        AND Product2.Name != 'Resource Placeholder'
      ORDER BY Product2.Name ASC
    ];
  }
}

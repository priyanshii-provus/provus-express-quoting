public inherited sharing class ProductService {

  public static Product2 createProduct(
    String name,
    String productCode,
    String description,
    String family,
    Decimal cost,
    Decimal price
  ) {
    Product2 product = new Product2(
      Name = name,
      ProductCode = productCode,
      Description = description,
      Family = family,
      IsActive = true,
      Cost__c = cost
    );
    insert product;

    if (price != null) {
      createPricebookEntry(product.Id, null, price);
    }

    return product;
  }

  public static Product2 updateProduct(
    Id productId,
    String name,
    String productCode,
    String description,
    String family,
    Boolean isActive
  ) {
    Product2 product = new Product2(
      Id = productId,
      Name = name,
      ProductCode = productCode,
      Description = description,
      Family = family,
      IsActive = isActive
    );
    update product;
    return ProductSelector.getProductById(productId);
  }

  public static void deleteProduct(Id productId) {
    delete new Product2(Id = productId);
  }

  public static void updateProducts(List<Product2> products) {
    update products;
  }

  public static PricebookEntry createPricebookEntry(
    Id product2Id,
    Id pricebook2Id,
    Decimal unitPrice
  ) {
    if (pricebook2Id == null) {
      try {
        pricebook2Id = [
          SELECT Id
          FROM Pricebook2
          WHERE IsStandard = TRUE
          LIMIT 1
        ].Id;
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

  public static Id getStandardPricebookIdSafe() {
    Id pbId;
    try {
      pbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;
    } catch (Exception e) {
      pbId = Test.getStandardPricebookId();
    }
    return pbId;
  }

  public static Integer importProducts(List<Map<String, String>> products) {
    List<Product2> toInsert = new List<Product2>();
    List<Decimal> prices = new List<Decimal>();

    for (Map<String, String> row : products) {
      String prodName = row.get('Name');
      if (String.isBlank(prodName)) continue;

      Product2 p = new Product2();
      p.Name = prodName.trim();

      String descVal = row.get('Description');
      if (String.isNotBlank(descVal)) p.Description = descVal.trim();

      String code = row.get('ProductCode');
      if (String.isNotBlank(code)) p.ProductCode = code.trim();

      String family = row.get('Family');
      if (String.isNotBlank(family)) p.Family = family.trim();

      String costStr = row.get('Cost');
      if (String.isNotBlank(costStr)) {
        try { p.Cost__c = Decimal.valueOf(costStr.trim()); } catch (Exception e) { p.Cost__c = 0; }
      }

      String isActive = row.get('Is_Active');
      if (String.isNotBlank(isActive)) {
        p.IsActive = isActive.trim().equalsIgnoreCase('true');
      } else {
        p.IsActive = true;
      }

      Decimal price = 0;
      String priceStr = row.get('Price');
      if (String.isNotBlank(priceStr)) {
        try { price = Decimal.valueOf(priceStr.trim()); } catch (Exception e) { price = 0; }
      }

      toInsert.add(p);
      prices.add(price);
    }

    if (!toInsert.isEmpty()) {
      insert toInsert;
      Id pbId = getStandardPricebookIdSafe();
      List<PricebookEntry> pbes = new List<PricebookEntry>();
      for (Integer i = 0; i < toInsert.size(); i++) {
        pbes.add(new PricebookEntry(
          Product2Id = toInsert[i].Id,
          Pricebook2Id = pbId,
          UnitPrice = prices[i],
          IsActive = true
        ));
      }
      insert pbes;
    }
    return toInsert.size();
  }
}

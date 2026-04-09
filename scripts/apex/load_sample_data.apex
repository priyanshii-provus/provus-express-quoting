/**
 * Populates a fresh scratch org with demo data for Provus Express Quoting.
 */

// 1. Company Settings
Provus_Company_Settings__c settings = new Provus_Company_Settings__c(
    Company_Name__c = 'Provus Demo Corp',
    Address_Line1__c = '123 Innovation Way',
    City__c = 'San Francisco',
    State__c = 'CA',
    Country__c = 'USA',
    Website__c = 'https://www.provusdemo.com',
    Industry__c = 'Technology',
    Currency_Code__c = 'USD'
);
insert settings;

// 2. Account & Opportunity
Account acc = new Account(Name = 'Sample Customer Account', Industry = 'Technology');
insert acc;

Opportunity opp = new Opportunity(
    Name = 'Sample Quoting Opportunity',
    StageName = 'Prospecting',
    CloseDate = Date.today().addMonths(3),
    AccountId = acc.Id
);
insert opp;

// 3. Products & Pricebook Entries
Id standardPbId = Test.isRunningTest() ? Test.getStandardPricebookId() : [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;

Product2 prod1 = new Product2(Name = 'Enterprise Software License', Family = 'Software', IsActive = true, ProductCode = 'ESL-001');
Product2 prod2 = new Product2(Name = 'Cloud Storage Package', Family = 'SaaS', IsActive = true, ProductCode = 'CSP-001');
insert new List<Product2>{prod1, prod2};

PricebookEntry pbe1 = new PricebookEntry(Pricebook2Id = standardPbId, Product2Id = prod1.Id, UnitPrice = 1000, IsActive = true);
PricebookEntry pbe2 = new PricebookEntry(Pricebook2Id = standardPbId, Product2Id = prod2.Id, UnitPrice = 500, IsActive = true);
insert new List<PricebookEntry>{pbe1, pbe2};

// 4. Resource Roles
Resource_Role__c role1 = new Resource_Role__c(Name = 'Project Manager', Price__c = 150, Cost__c = 100, Active__c = true, Location__c = 'Onshore', Billing_Unit__c = 'Hour');
Resource_Role__c role2 = new Resource_Role__c(Name = 'Software Engineer', Price__c = 120, Cost__c = 80, Active__c = true, Location__c = 'Onshore', Billing_Unit__c = 'Hour');
Resource_Role__c role3 = new Resource_Role__c(Name = 'QA Engineer', Price__c = 90, Cost__c = 60, Active__c = true, Location__c = 'Offshore', Billing_Unit__c = 'Hour');
insert new List<Resource_Role__c>{role1, role2, role3};

// 5. Add-ons
Add_on__c addon1 = new Add_on__c(Name = 'Premium Support 24/7', Price__c = 500, Cost__c = 200, Active__c = true, Billing_Unit__c = 'Month', Description__c = 'Round-the-clock priority support');
Add_on__c addon2 = new Add_on__c(Name = 'Training Workshop', Price__c = 1500, Cost__c = 500, Active__c = true, Billing_Unit__c = 'One-time', Description__c = 'Onsite product training for up to 10 people');
insert new List<Add_on__c>{addon1, addon2};

System.debug('Demo data successfully loaded!');

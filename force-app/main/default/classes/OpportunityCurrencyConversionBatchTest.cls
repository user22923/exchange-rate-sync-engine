@isTest
private class OpportunityCurrencyConversionBatchTest {

    @isTest
    static void testBatchConvertsOpportunityAmountsUsingSyncedRates() {
        insert TestDataFactory.buildCurrencyRate('EUR', 0.92);
        insert TestDataFactory.buildOpportunity('Deal in Euros', 92, 'EUR');

        Test.startTest();
        Database.executeBatch(new OpportunityCurrencyConversionBatch());
        Test.stopTest();

        Opportunity converted = [SELECT Converted_Amount_USD__c FROM Opportunity WHERE Name = 'Deal in Euros'];
        Assert.areEqual(100, converted.Converted_Amount_USD__c, '92 EUR at a rate of 0.92 should convert to 100 USD.');
    }

    @isTest
    static void testBatchSkipsOpportunitiesWithNoMatchingRate() {
        insert TestDataFactory.buildCurrencyRate('EUR', 0.92);
        insert TestDataFactory.buildOpportunity('Deal in Unknown Currency', 500, 'XYZ');

        Test.startTest();
        Database.executeBatch(new OpportunityCurrencyConversionBatch());
        Test.stopTest();

        Opportunity unconverted = [
            SELECT Converted_Amount_USD__c
            FROM Opportunity
            WHERE Name = 'Deal in Unknown Currency'
        ];
        Assert.isNull(
            unconverted.Converted_Amount_USD__c,
            'An opportunity whose currency has no matching Currency_Rate__c must be left unconverted.'
        );

        Integration_Sync_Log__c log = [
            SELECT Message__c
            FROM Integration_Sync_Log__c
            WHERE Integration_Name__c = 'Opportunity Currency Conversion'
        ];
        Assert.isTrue(log.Message__c.contains('skipped 1'), 'The finish() summary should report the skipped count.');
    }

    @isTest
    static void testBatchIgnoresOpportunitiesMissingCurrencyOrAmount() {
        insert TestDataFactory.buildCurrencyRate('EUR', 0.92);
        insert new Opportunity(
            Name = 'No Currency Set',
            StageName = 'Prospecting',
            CloseDate = Date.today().addMonths(1)
        );

        Test.startTest();
        Database.executeBatch(new OpportunityCurrencyConversionBatch());
        Test.stopTest();

        Integration_Sync_Log__c log = [
            SELECT Message__c
            FROM Integration_Sync_Log__c
            WHERE Integration_Name__c = 'Opportunity Currency Conversion'
        ];
        Assert.isTrue(
            log.Message__c.contains('Converted 0'),
            'An opportunity with no Amount/Transaction_Currency__c should never enter batch scope.'
        );
    }
}

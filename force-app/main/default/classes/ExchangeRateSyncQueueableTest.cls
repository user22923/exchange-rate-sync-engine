@isTest
private class ExchangeRateSyncQueueableTest {

    @isTest
    static void testSuccessfulSyncUpsertsRatesLogsAndChainsConversionBatch() {
        insert TestDataFactory.buildOpportunity('Deal in Euros', 92, 'EUR');
        Test.setMock(HttpCalloutMock.class, new ExchangeRateApiSuccessMock());

        Test.startTest();
        System.enqueueJob(new ExchangeRateSyncQueueable());
        Test.stopTest();

        List<Currency_Rate__c> rates = [SELECT Currency_Code__c, Rate_To_USD__c FROM Currency_Rate__c];
        Assert.areEqual(4, rates.size(), 'All rates from the mocked response should be upserted.');

        List<Integration_Sync_Log__c> logs = [
            SELECT Status__c, Message__c
            FROM Integration_Sync_Log__c
            WHERE Integration_Name__c = 'Exchange Rate Sync'
        ];
        Assert.areEqual(1, logs.size(), 'One sync log should be written for the run.');
        Assert.areEqual('Success', logs[0].Status__c, 'A successful sync should log Success.');

        Opportunity converted = [SELECT Converted_Amount_USD__c FROM Opportunity WHERE Name = 'Deal in Euros'];
        Assert.areEqual(
            100,
            converted.Converted_Amount_USD__c,
            'The chained OpportunityCurrencyConversionBatch should have converted the EUR opportunity to USD (92 / 0.92 = 100).'
        );
    }

    @isTest
    static void testFailedSyncLogsFailureAndSkipsRatesAndBatch() {
        Test.setMock(HttpCalloutMock.class, new ExchangeRateApiFailureMock());

        Test.startTest();
        System.enqueueJob(new ExchangeRateSyncQueueable());
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM Currency_Rate__c], 'A failed callout must not upsert any rates.');

        List<Integration_Sync_Log__c> logs = [
            SELECT Status__c, Message__c
            FROM Integration_Sync_Log__c
            WHERE Integration_Name__c = 'Exchange Rate Sync'
        ];
        Assert.areEqual(1, logs.size(), 'One sync log should be written even when the sync fails.');
        Assert.areEqual('Failed', logs[0].Status__c, 'A failed callout must log Failed, not throw unhandled.');
        Assert.isNotNull(logs[0].Message__c, 'The failure log should capture the error message.');
    }
}

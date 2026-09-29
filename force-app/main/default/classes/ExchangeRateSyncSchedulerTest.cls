@isTest
private class ExchangeRateSyncSchedulerTest {

    @isTest
    static void testScheduledExecutionEnqueuesSync() {
        Test.setMock(HttpCalloutMock.class, new ExchangeRateApiSuccessMock());

        Test.startTest();
        new ExchangeRateSyncScheduler().execute(null);
        Test.stopTest();

        List<Integration_Sync_Log__c> logs = [
            SELECT Status__c
            FROM Integration_Sync_Log__c
            WHERE Integration_Name__c = 'Exchange Rate Sync'
        ];
        Assert.areEqual(1, logs.size(), 'Scheduling and firing the job should enqueue and run the sync exactly once.');
        Assert.areEqual('Success', logs[0].Status__c, 'The mocked callout should resolve as a successful sync.');
    }

    @isTest
    static void testCanBeScheduledWithCronExpression() {
        Test.startTest();
        String jobId = System.schedule('Nightly Exchange Rate Sync Test', '0 0 2 * * ?', new ExchangeRateSyncScheduler());
        Test.stopTest();

        CronTrigger job = [SELECT CronExpression, NextFireTime FROM CronTrigger WHERE Id = :jobId];
        Assert.areEqual('0 0 2 * * ?', job.CronExpression, 'The job should be registered with the requested cron schedule.');
        Assert.isNotNull(job.NextFireTime, 'A scheduled job should have a next fire time.');
    }
}

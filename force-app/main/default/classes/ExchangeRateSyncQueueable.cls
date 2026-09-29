/**
 * Orchestrates one exchange rate sync: calls the Exchange Rate API, upserts
 * Currency_Rate__c records, writes an Integration_Sync_Log__c entry either way, and —
 * only on success — chains into OpportunityCurrencyConversionBatch so downstream
 * Opportunity conversions always run against freshly synced rates.
 *
 * Runs as a Queueable (rather than calling out directly from ExchangeRateSyncScheduler)
 * so the callout, the DML, and the batch kick-off are isolated in their own async
 * transaction with their own governor limits.
 */
public with sharing class ExchangeRateSyncQueueable implements Queueable, Database.AllowsCallouts {

    private static final String INTEGRATION_NAME = 'Exchange Rate Sync';

    public void execute(QueueableContext context) {
        try {
            Map<String, Decimal> ratesToUsd = ExchangeRateClient.fetchLatestRatesToUsd();
            upsertCurrencyRates(ratesToUsd);
            logOutcome('Success', 'Synced ' + ratesToUsd.size() + ' currency rates.');
            Database.executeBatch(new OpportunityCurrencyConversionBatch());
        } catch (Exception ex) {
            logOutcome('Failed', ex.getMessage());
        }
    }

    private void upsertCurrencyRates(Map<String, Decimal> ratesToUsd) {
        DateTime syncedAt = System.now();
        List<Currency_Rate__c> ratesToUpsert = new List<Currency_Rate__c>();

        for (String currencyCode : ratesToUsd.keySet()) {
            ratesToUpsert.add(new Currency_Rate__c(
                Currency_Code__c = currencyCode,
                Rate_To_USD__c = ratesToUsd.get(currencyCode),
                Last_Synced__c = syncedAt
            ));
        }

        upsert ratesToUpsert Currency_Code__c;
    }

    private void logOutcome(String status, String message) {
        insert new Integration_Sync_Log__c(
            Integration_Name__c = INTEGRATION_NAME,
            Status__c = status,
            Message__c = message
        );
    }
}

/**
 * Nightly entry point: hands off to ExchangeRateSyncQueueable so the callout runs in
 * its own async transaction. Schedule with, for example:
 *
 *   System.schedule('Nightly Exchange Rate Sync', '0 0 2 * * ?', new ExchangeRateSyncScheduler());
 */
public with sharing class ExchangeRateSyncScheduler implements Schedulable {

    public void execute(SchedulableContext context) {
        System.enqueueJob(new ExchangeRateSyncQueueable());
    }
}

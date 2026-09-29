# Exchange Rate Sync Engine

A Salesforce integration/async Apex project: a scheduled pipeline that syncs live
currency exchange rates from a public REST API into Salesforce, then bulk-converts
every Opportunity's `Amount` to USD using those rates.

No third-party middleware — a Named Credential, a small HTTP client, and three
cooperating async Apex jobs.

## Pipeline

```
ExchangeRateSyncScheduler (Schedulable)
  → System.enqueueJob(ExchangeRateSyncQueueable)
      → ExchangeRateClient.fetchLatestRatesToUsd()   [HTTP callout via Named Credential]
      → upsert Currency_Rate__c (keyed on Currency_Code__c)
      → insert Integration_Sync_Log__c (Success/Failed either way)
      → Database.executeBatch(OpportunityCurrencyConversionBatch)   [only on success]
          → converts every Opportunity.Amount to Converted_Amount_USD__c
          → insert Integration_Sync_Log__c summary
```

- **`ExchangeRateSyncScheduler`** — the nightly entry point. Its only job is to enqueue
  the Queueable, so the callout runs in its own async transaction with its own
  governor limits.
- **`ExchangeRateSyncQueueable`** — orchestrates one sync: calls the API, upserts
  rates, always logs the outcome, and — only when the sync succeeded — chains into the
  conversion batch so it never runs against stale or partial rate data.
- **`ExchangeRateClient`** — the only class that knows about the HTTP/JSON wire
  format. Throws `ExchangeRateClient.ExchangeRateException` on a non-200 response or a
  200 with a non-success payload, so callers never have to parse errors themselves.
- **`OpportunityCurrencyConversionBatch`** — Batch Apex (not a trigger) because this
  is a scheduled, org-wide recalculation over a potentially large Opportunity volume.
  Loads all `Currency_Rate__c` once in `start()` (cached via `Database.Stateful`), then
  converts each scope chunk, skipping — not failing — Opportunities whose currency has
  no synced rate.
- **`Integration_Sync_Log__c`** — a lightweight, queryable audit trail for both stages
  of the pipeline, so a failed sync is visible without digging through debug logs.

## Why a legacy-format Named Credential

The endpoint (`open.er-api.com`, a free public exchange-rate API with no API key) needs
no authentication. Salesforce's newer "Enhanced" Named Credential format
(`namedCredentialType: SecuredEndpoint`) requires an External Credential, and External
Credentials don't support a `NoAuthentication` protocol — so this uses the legacy
Named Credential format instead (`principalType: Anonymous`, `protocol:
NoAuthentication`), which supports genuinely anonymous callouts directly.

## Testing

All callouts are mocked (`HttpCalloutMock`) — no test hits the real API.

- **`ExchangeRateClientTest`** — successful parse, HTTP-error response, and a 200
  response whose payload itself reports failure.
- **`ExchangeRateSyncQueueableTest`** — a successful run (rates upserted, log written,
  conversion batch chained and actually converts a seeded Opportunity) and a failed
  run (no rates written, failure logged, batch never chained).
- **`OpportunityCurrencyConversionBatchTest`** — correct conversion math, an
  Opportunity whose currency has no matching rate (skipped, not failed), and an
  Opportunity missing `Amount`/`Transaction_Currency__c` (excluded from batch scope
  entirely).
- **`ExchangeRateSyncSchedulerTest`** — the scheduler enqueues and the sync actually
  runs, plus a check that it registers correctly with `System.schedule`.

96% org-wide coverage. Run with:

```bash
sf apex run test --target-org <alias> --class-names ExchangeRateClientTest --class-names ExchangeRateSyncQueueableTest --class-names OpportunityCurrencyConversionBatchTest --class-names ExchangeRateSyncSchedulerTest --code-coverage --wait 10
```

## Deploying

```bash
sf project deploy start --target-org <alias> --source-dir force-app
sf org assign permset --target-org <alias> --name Exchange_Rate_Sync_Access
```

Run a sync once, manually:

```bash
sf apex run --target-org <alias> --file - <<< "System.enqueueJob(new ExchangeRateSyncQueueable());"
```

Or schedule it to run nightly at 2 AM:

```bash
sf apex run --target-org <alias> --file - <<< "System.schedule('Nightly Exchange Rate Sync', '0 0 2 * * ?', new ExchangeRateSyncScheduler());"
```

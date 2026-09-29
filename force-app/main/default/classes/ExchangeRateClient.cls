/**
 * Thin HTTP client for the Exchange Rate API named credential. Isolates callout
 * mechanics (endpoint, status handling, JSON parsing) from the async orchestration in
 * ExchangeRateSyncQueueable so that orchestration logic can be tested independently of
 * the wire format.
 */
public with sharing class ExchangeRateClient {

    private static final String NAMED_CREDENTIAL = 'callout:Exchange_Rate_API';
    private static final String LATEST_RATES_PATH = '/v6/latest/USD';

    public class ExchangeRateException extends Exception {}

    public static Map<String, Decimal> fetchLatestRatesToUsd() {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(NAMED_CREDENTIAL + LATEST_RATES_PATH);
        request.setMethod('GET');
        request.setTimeout(20000);

        Http http = new Http();
        HttpResponse response = http.send(request);

        if (response.getStatusCode() != 200) {
            throw new ExchangeRateException(
                'Exchange rate API returned HTTP ' + response.getStatusCode() + ': ' + response.getStatus()
            );
        }

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        if (payload.get('result') != 'success') {
            throw new ExchangeRateException('Exchange rate API reported a non-success result: ' + response.getBody());
        }

        Map<String, Object> rawRates = (Map<String, Object>) payload.get('rates');
        if (rawRates == null || rawRates.isEmpty()) {
            throw new ExchangeRateException('Exchange rate API response did not include any rates.');
        }

        Map<String, Decimal> rates = new Map<String, Decimal>();
        for (String currencyCode : rawRates.keySet()) {
            rates.put(currencyCode, (Decimal) rawRates.get(currencyCode));
        }
        return rates;
    }
}

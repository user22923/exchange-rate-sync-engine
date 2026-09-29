@isTest
private class ExchangeRateClientTest {

    @isTest
    static void testFetchLatestRatesToUsdParsesSuccessResponse() {
        Test.setMock(HttpCalloutMock.class, new ExchangeRateApiSuccessMock());

        Test.startTest();
        Map<String, Decimal> rates = ExchangeRateClient.fetchLatestRatesToUsd();
        Test.stopTest();

        Assert.areEqual(4, rates.size(), 'Should parse every currency in the mocked response.');
        Assert.areEqual(0.92, rates.get('EUR'), 'EUR rate should be parsed correctly.');
        Assert.areEqual(1, rates.get('USD'), 'USD rate should be parsed correctly.');
    }

    @isTest
    static void testFetchLatestRatesToUsdThrowsOnHttpError() {
        Test.setMock(HttpCalloutMock.class, new ExchangeRateApiFailureMock());

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ExchangeRateClient.fetchLatestRatesToUsd();
        } catch (ExchangeRateClient.ExchangeRateException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'A non-200 response must raise ExchangeRateException.');
    }

    @isTest
    static void testFetchLatestRatesToUsdThrowsOnNonSuccessResult() {
        Test.setMock(HttpCalloutMock.class, new ExchangeRateApiMalformedMock());

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ExchangeRateClient.fetchLatestRatesToUsd();
        } catch (ExchangeRateClient.ExchangeRateException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(
            exceptionThrown,
            'An HTTP 200 response whose payload reports result != success must still raise ExchangeRateException.'
        );
    }
}

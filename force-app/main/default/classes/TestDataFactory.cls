@isTest
public class TestDataFactory {

    public static Currency_Rate__c buildCurrencyRate(String currencyCode, Decimal rateToUsd) {
        return new Currency_Rate__c(
            Currency_Code__c = currencyCode,
            Rate_To_USD__c = rateToUsd,
            Last_Synced__c = System.now()
        );
    }

    public static Opportunity buildOpportunity(String name, Decimal amount, String currencyCode) {
        return new Opportunity(
            Name = name,
            Amount = amount,
            Transaction_Currency__c = currencyCode,
            StageName = 'Prospecting',
            CloseDate = Date.today().addMonths(1)
        );
    }
}

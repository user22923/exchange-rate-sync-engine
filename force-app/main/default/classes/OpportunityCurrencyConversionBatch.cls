/**
 * Bulk-converts every Opportunity's Amount into USD using the most recently synced
 * Currency_Rate__c records. Runs as Batch Apex (rather than a trigger) because it's a
 * scheduled, org-wide recalculation over a potentially large Opportunity volume, not a
 * reaction to a single record change.
 */
public with sharing class OpportunityCurrencyConversionBatch implements Database.Batchable<SObject>, Database.Stateful {

    private Map<String, Decimal> rateByCurrencyCode;
    private Integer convertedCount = 0;
    private Integer skippedCount = 0;

    public Database.QueryLocator start(Database.BatchableContext context) {
        rateByCurrencyCode = new Map<String, Decimal>();
        for (Currency_Rate__c rate : [SELECT Currency_Code__c, Rate_To_USD__c FROM Currency_Rate__c WITH USER_MODE]) {
            if (rate.Rate_To_USD__c != null && rate.Rate_To_USD__c != 0) {
                rateByCurrencyCode.put(rate.Currency_Code__c, rate.Rate_To_USD__c);
            }
        }

        return Database.getQueryLocator([
            SELECT Id, Amount, Transaction_Currency__c
            FROM Opportunity
            WHERE Amount != null AND Transaction_Currency__c != null
            WITH USER_MODE
        ]);
    }

    public void execute(Database.BatchableContext context, List<Opportunity> scope) {
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

        for (Opportunity opp : scope) {
            Decimal rate = rateByCurrencyCode.get(opp.Transaction_Currency__c);
            if (rate == null) {
                skippedCount++;
                continue;
            }
            opportunitiesToUpdate.add(new Opportunity(
                Id = opp.Id,
                Converted_Amount_USD__c = (opp.Amount / rate).setScale(2)
            ));
            convertedCount++;
        }

        if (!opportunitiesToUpdate.isEmpty()) {
            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, opportunitiesToUpdate);
            update decision.getRecords();
        }
    }

    public void finish(Database.BatchableContext context) {
        insert new Integration_Sync_Log__c(
            Integration_Name__c = 'Opportunity Currency Conversion',
            Status__c = 'Success',
            Message__c = 'Converted ' + convertedCount + ' opportunities; skipped ' + skippedCount +
                ' with no matching Currency_Rate__c.'
        );
    }
}

public class ClaimTriggerHandler {
    public static void updateClaimFields(
        // Pass in new/updated Claims (newClaims) and old/pre-update Claims (oldClaimsMap)
        // Pass in System.TriggerOperation operation type to dictate logic for before insert versus before update
        List<Claim__c> newClaims,
        Map<Id,Claim__c> oldClaimsMap,
        System.TriggerOperation operationType
    ) {
        // The company-defined dollar amount to classify a Claim as high value
        // Store this value in a variable to make it easy to update if business requirements change; this is preferable to hardcoding
        Decimal highValueSettlementAmount = 15000;

        if(operationType == System.TriggerOperation.BEFORE_INSERT || operationType == System.TriggerOperation.BEFORE_UPDATE) {
            for(Claim__c newClaim : newClaims) {
                // Confirm Incident Date is not in the future and Incident Date is not after Date Filed (you cannot file a report for an incident that hasn't occurred yet!)
                if(newClaim.Incident_Date__c <= Date.today() && newClaim.Incident_Date__c < newClaim.Date_Filed__c) {

                    // Check if Status field on Claim has been updated and also confirm the records that were updated exist (oldClaimsMap != null)
                    if(oldClaimsMap != null && oldClaimsMap.containsKey(newClaim.Id) && newClaim.Status__c != oldClaimsMap.get(newClaim.Id).Status__c) {

                        // If Claim is Settled and Settlement Amount > 0 and Settlement Date is blank, set Settlement Date to today
                        if(newClaim.Status__c == 'Settled' && newClaim.Settlement_Date__c == null && newClaim.Settlement_Amount__c > 0 && newClaim.Settlement_Amount__c != null) {
                            newClaim.Settlement_Date__c = Date.today();
                        }

                        // If Claim is Settled and Settlement Amount <= 0, display an error for user to correct Settlement Amount (a settled claim cannot have a zero or negative payout!)
                        else if(newClaim.Status__c == 'Settled' && newClaim.Settlement_Amount__c <= 0) {
                            newClaim.addError('Settlement Amount must be greater than zero before Claim is marked as Settled.');
                        }

                        // If Claim is Denied or in any other Status that is not Settled, and Settlement Amount != 0, set Settlement Amount to 0 (there is no payout if your claim is denied!)
                        else if((newClaim.Status__c == 'Denied' || newClaim.Status__c != 'Settled') && newClaim.Settlement_Amount__c != 0) {
                            newClaim.Settlement_Amount__c = 0;
                        }
                    }

                    // If Status field on Claim has not been updated and Status = Denied or Settled, then Days Open = Date Filed - Incident Date. If Status = Denied, then Settlement Amount = 0
                    else if(newClaim.Status__c == 'Denied' || newClaim.Status__c == 'Settled') {
                        newClaim.Days_Open__c = newClaim.Incident_Date__c.daysBetween(newClaim.Date_Filed__c);
                        if(newClaim.Status__c == 'Denied') {
                            newClaim.Settlement_Amount__c = 0;
                        }
                    }

                    // If Claim is still open and Status field has not been updated, Days Open = number of days between today and Incident Date
                    else if(newClaim.Status__c != 'Settled' && newClaim.Status__c != 'Denied') {
                        newClaim.Days_Open__c = newClaim.Incident_Date__c.daysBetween(Date.today());
                    }
                }

                // If the Incident Date is in the future OR after the Date Filed, display an error message informing the user of what is wrong
                else if(newClaim.Incident_Date__c > Date.today() || newClaim.Incident_Date__c > newClaim.Date_Filed__c) {
                    newClaim.addError('Incident Date must not be in the future. Incident Date cannot be later than Date Filed.');
                }

                // Check if Settlement Amount on Claim has been updated
                if(oldClaimsMap != null && newClaim.Settlement_Amount__c != oldClaimsMap.get(newClaim.Id).Settlement_Amount__c) {

                    // If Settlement Amount equals or exceeds the set threshold, set Is High Value to true
                    if(newClaim.Settlement_Amount__c >= highValueSettlementAmount) {
                        newClaim.Is_High_Value__c = true;
                    }

                    // If Settlement Amount is below the set threshold OR the Claim is Denied, set Is High Value to false
                    else if(newClaim.Settlement_Amount__c < highValueSettlementAmount || newClaim.Status__c == 'Denied') {
                        newClaim.Is_High_Value__c = false;
                    }
                }
            }
        }
    }
}
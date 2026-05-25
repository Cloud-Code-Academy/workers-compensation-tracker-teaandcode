public class ClaimTriggerHandler {
    public static void updateClaimFields(
        List<Claim__c> newClaims,
        Map<Id,Claim__c> oldClaimsMap,
        System.TriggerOperation operationType
    ) {
        // The company-defined dollar amount to classify a Claim as high value
        Decimal highValueSettlementAmount = 15000;

        for(Claim__c newClaim : newClaims) {
            // Confirm Incident Date is not in the future and Incident Date is not after Date Filed
            if(newClaim.Incident_Date__c <= Date.today() && newClaim.Incident_Date__c < newClaim.Date_Filed__c) {
                // Check if Status field on Claim has been updated
                if(oldClaimsMap != null && oldClaimsMap.containsKey(newClaim.Id) && newClaim.Status__c != oldClaimsMap.get(newClaim.Id).Status__c) {
                    if(newClaim.Status__c == 'Settled' && newClaim.Settlement_Date__c == null && newClaim.Settlement_Amount__c > 0 && newClaim.Settlement_Amount__c != null) {
                        newClaim.Settlement_Date__c = Date.today();
                    }
                    else if(newClaim.Status__c == 'Settled' && newClaim.Settlement_Amount__c <= 0) {
                        newClaim.addError('Settlement Amount must be greater than zero before Claim is marked as Settled.');
                    }
                    else if(newClaim.Status__c == 'Denied' && newClaim.Settlement_Amount__c != 0) {
                        newClaim.Settlement_Amount__c = 0;
                    }
                }
                // If the Claim is Settled or Denied, Days Open = Date Filed - Incident Date
                else if(newClaim.Status__c == 'Settled' || newClaim.Status__c == 'Denied') {
                    newClaim.Days_Open__c = newClaim.Incident_Date__c.daysBetween(newClaim.Date_Filed__c);
                }
                // If the Claim is still open, Days Open = number of days between today and Incident Date
                else if(newClaim.Status__c != 'Settled' && newClaim.Status__c != 'Denied') {
                    newClaim.Days_Open__c = newClaim.Incident_Date__c.daysBetween(Date.today());
                }
            }
            // If the Incident Date is incorrect, display an error message to the user with the acceptable criteria
            else {
                newClaim.addError('Incident Date must not be in the future. Incident Date cannot be later than Date Filed.');
            }

            // Check if Settlement Amount on Claim has been updated
            if(oldClaimsMap != null && newClaim.Settlement_Amount__c != oldClaimsMap.get(newClaim.Id).Settlement_Amount__c) {
                if(newClaim.Settlement_Amount__c >= highValueSettlementAmount) {
                    newClaim.Is_High_Value__c = true;
                }
                else if(newClaim.Settlement_Amount__c < highValueSettlementAmount || newClaim.Status__c == 'Denied') {
                    newClaim.Is_High_Value__c = false;
                }
            }
        }
    }
}
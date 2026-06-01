trigger ClaimTrigger on Claim__c (before insert, before update) {
    ClaimTriggerHandler.updateClaimFields(Trigger.new, Trigger.oldMap, Trigger.operationType);
}
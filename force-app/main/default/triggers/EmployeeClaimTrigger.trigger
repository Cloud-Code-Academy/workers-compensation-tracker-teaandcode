trigger EmployeeClaimTrigger on Employee_Claim__c (after insert, after update, after delete, after undelete) {
    EmployeeClaimTriggerHandler.updateRiskLevel(Trigger.new, Trigger.old, Trigger.operationType);
}
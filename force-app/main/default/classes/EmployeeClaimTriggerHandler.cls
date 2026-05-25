public class EmployeeClaimTriggerHandler {
    public static void updateRiskLevel(
        // Pass in new/updated Employee Claims and old/deleted/undeleted Employee Claims
        // Pass in System.TriggerOperation operation type to dictate logic for insert/update versus delete/undelete
        List<Employee_Claim__c> newClaims,
        List<Employee_Claim__c> oldClaims,
        System.TriggerOperation operationType
    ) {
        // Risk thresholds - update as needed
        Decimal standard = 5000;
        Decimal medium = 10000;
        Decimal high = 20000;

        // Store the Employee Ids associated with new or old Employee Claims while avoiding duplicates
        Set<Id> employeeIds = new Set<Id>();

        // Populate the employeeIds set from the newClaims or oldClaims list depending on operation type
        System.debug('Operation Type: ' + operationType);
        if(operationType == System.TriggerOperation.AFTER_INSERT || operationType == System.TriggerOperation.AFTER_UPDATE) {
            for(Employee_Claim__c newClaim : newClaims) {
                employeeIds.add(newClaim.Employee__c);
            }
        }
        else if(operationType == System.TriggerOperation.AFTER_DELETE) {
            for(Employee_Claim__c oldClaim : oldClaims) {
                employeeIds.add(oldClaim.Employee__c);
            }
        }
        else if(operationType == System.TriggerOperation.AFTER_UNDELETE) {
            List<Employee_Claim__c> undeletedClaims = [SELECT Id, Employee__c FROM Employee_Claim__c WHERE Id IN :newClaims];
            for(Employee_Claim__c undeletedClaim : undeletedClaims) {
                employeeIds.add(undeletedClaim.Employee__c);
            }
        }
        System.debug('First block end');

        // This query returns all Employee Claims associated with employees whose Ids are in the employeeIds set, grouped by employee and provider, with the total amount per provider for each employee
        // Example: Oliver might have $500 in claims with Liberty Mutual and $100 in claims with Zurich
        List<AggregateResult> claimsByEmployeeAndProvider = [SELECT Employee__c, Claim__r.Insurance_Provider__c, SUM(Claim__r.Settlement_Amount__c) totalAmount FROM Employee_Claim__c WHERE Employee__c IN :employeeIds GROUP BY Employee__c, Claim__r.Insurance_Provider__c];

        Map<Id,Map<Id,Decimal>> employeeTotalByInsuranceProvider = new Map<Id,Map<Id,Decimal>>();
        // Loop through the AggregateResult list and populate the employeeTotalByInsuranceProvider map
        for(AggregateResult ar : claimsByEmployeeAndProvider) {
            Id employeeId = (Id)ar.get('Employee__c');
            Id providerId = (Id)ar.get('Insurance_Provider__c');
            Decimal totalAmount = (Decimal)ar.get('totalAmount');
            if(totalAmount == null) {
                totalAmount = 0;
            }
            if(!employeeTotalByInsuranceProvider.containsKey(employeeId)) {
                employeeTotalByInsuranceProvider.put(employeeId, new Map<Id,Decimal>{providerId => totalAmount});
            }
            else {
                employeeTotalByInsuranceProvider.get(employeeId).put(providerId, totalAmount);
            }
        }

        List<AggregateResult> totalClaimsAndAmountsByEmployee = [SELECT Employee__c, COUNT(Employee__r.Total_Claims__c) totalClaims, SUM(Employee__r.Total_Settlement_Amount__c) totalSettlementAmount FROM Employee_Claim__c WHERE Employee__c IN :employeeIds GROUP BY Employee__c];

        Map<Id,Integer> claimCounts = new Map<Id,Integer>();
        Map<Id,Decimal> settlementTotals = new Map<Id,Decimal>();

        for(AggregateResult ar : totalClaimsAndAmountsByEmployee) {
            Id employeeId = (Id)ar.get('Employee__c');
            Integer numberOfClaims = (Integer)ar.get('totalClaims');
            Decimal totalSettlementAmount = (Decimal)ar.get('totalSettlementAmount');
            if(!claimCounts.containsKey(employeeId)) {
                claimCounts.put(employeeId, numberOfClaims);
            }
            if(!settlementTotals.containsKey(employeeId)) {
                settlementTotals.put(employeeId, totalSettlementAmount);
            }
        }

        // Build a list of Employees based on the original employeeIds set to update Risk Levels
        // List<Employee__c> employeesWithRiskLevels = [SELECT Id, Risk_Level__c FROM Employee__c WHERE Id IN :employeeIds];

        // Build a list of Employees based on the original employeeIds set to update Risk Level, Total Claims, Total Settlement Amount
        List<Employee__c> employeesToUpdate = [SELECT Id, Risk_Level__c, Total_Claims__c, Total_Settlement_Amount__c FROM Employee__c WHERE Id IN :employeeIds];

        // Loop through the list of Employees
        for(Employee__c employee : employeesToUpdate) {
            // If the employee is in the employeeTotalByInsuranceProvider map, retrieve the inner map containing the employee's related providers and totals
            if(employeeTotalByInsuranceProvider.containsKey(employee.Id)) {
                // The providersAndTotals map will store the inner map<Id,Decimal> from the employeeTotalByInsuranceProvider map
                Map<Id,Decimal> providersAndTotals = employeeTotalByInsuranceProvider.get(employee.Id);
                // Extract the unduplicated provider Ids from the providersAndTotals map
                Set<Id> providerIds = providersAndTotals.keySet();
                if(!providerIds.isEmpty()) {
                    for(Id providerId : providerIds) {
                        Decimal totalAmount = providersAndTotals.get(providerId);
                        if(totalAmount > medium) {
                            employee.Risk_Level__c = 'High Risk';
                        }
                        else if(totalAmount > standard && totalAmount <= medium) {
                            employee.Risk_Level__c = 'Medium Risk';
                        }
                        else {
                            employee.Risk_Level__c = 'Standard';
                        }
                    }
                }
            }

            // If the employee is in the claimCounts map, update their Total Claims field using the map value
            if(claimCounts.containsKey(employee.Id)) {
                employee.Total_Claims__c = claimCounts.get(employee.Id);
            }

            // If the employee is in the settlementTotals map, update their Total Settlement Amount field using the map value
            if(settlementTotals.containsKey(employee.Id)) {
                employee.Total_Settlement_Amount__c = settlementTotals.get(employee.Id);
            }
        }

        System.debug('Updated risk level ran');
        // update employeesWithRiskLevels;
        update employeesToUpdate;
    } 
}
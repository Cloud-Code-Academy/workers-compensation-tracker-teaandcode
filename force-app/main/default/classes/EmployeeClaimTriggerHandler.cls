public class EmployeeClaimTriggerHandler {
    public static void updateRiskLevel(
        // Pass in new/updated Employee Claims and old/deleted/undeleted Employee Claims
        // Pass in System.TriggerOperation operation type to dictate logic for insert/update versus delete/undelete
        List<Employee_Claim__c> newClaims,
        List<Employee_Claim__c> oldClaims,
        System.TriggerOperation operationType
    ) {
        // Risk thresholds - determined by company; update as needed
        Decimal standard = 5000;
        Decimal medium = 10000;
        Decimal high = 20000;

        // Store the Employee Ids associated with new or old Employee Claims while avoiding duplicates
        Set<Id> employeeIds = new Set<Id>();

        // Uncomment the System.debug line below if you want to test the operationType
        // System.debug('Operation Type: ' + operationType);

        // Populate the employeeIds set from the newClaims or oldClaims list depending on operation type
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
        
        // Uncomment this System.debug line if you want to test whether the code above this line ran successfully
        // System.debug('First block end');

        // This query returns all Employee Claims associated with employees whose Ids are in the employeeIds set, grouped by employee and provider, with the total amount per provider for each employee
        // Example: Oliver might have $500 in claims with Liberty Mutual and $100 in claims with Zurich
        List<AggregateResult> claimsByEmployeeAndProvider = [SELECT Employee__c, Claim__r.Insurance_Provider__c, SUM(Claim__r.Settlement_Amount__c) totalAmount FROM Employee_Claim__c WHERE Employee__c IN :employeeIds GROUP BY Employee__c, Claim__r.Insurance_Provider__c];

        // Create a map where the key is the Employee Id and the value is an inner map consisting of Insurance Provider Id (key) and total Settlement Amount by provider (value)
        Map<Id,Map<Id,Decimal>> employeeTotalByInsuranceProvider = new Map<Id,Map<Id,Decimal>>();

        // Loop through the AggregateResult list and populate the employeeTotalByInsuranceProvider map
        for(AggregateResult ar : claimsByEmployeeAndProvider) {
            Id employeeId = (Id)ar.get('Employee__c');
            Id providerId = (Id)ar.get('Insurance_Provider__c');
            Decimal cumulativeSettlementAmount = (Decimal)ar.get('totalAmount');
            
            if(cumulativeSettlementAmount == null) {
                cumulativeSettlementAmount = 0;
            }
            
            if(!employeeTotalByInsuranceProvider.containsKey(employeeId)) {
                employeeTotalByInsuranceProvider.put(employeeId, new Map<Id,Decimal>{providerId => cumulativeSettlementAmount});
            }

            else {
                employeeTotalByInsuranceProvider.get(employeeId).put(providerId, cumulativeSettlementAmount);
            }
        }

        /*
        // Query for Employee Claim records using AggregateResult to calculate the total number of Claims and cumulative Settlement Amount for each Employee
        List<AggregateResult> totalClaimsAndAmountsByEmployee = [SELECT Employee__c, COUNT(Id) totalClaims, SUM(Claim__r.Settlement_Amount__c) totalSettlementAmount FROM Employee_Claim__c WHERE Employee__c IN :employeeIds GROUP BY Employee__c];

        Map<Id,Integer> claimCounts = new Map<Id,Integer>();
        Map<Id,Decimal> settlementTotals = new Map<Id,Decimal>();

        for(AggregateResult ar : totalClaimsAndAmountsByEmployee) {
            Id employeeId = (Id)ar.get('Employee__c');
            Integer numberOfClaims = (Integer)ar.get('totalClaims');
            Decimal sumOfSettlementAmount = (Decimal)ar.get('totalSettlementAmount');
            if(!claimCounts.containsKey(employeeId)) {
                claimCounts.put(employeeId, numberOfClaims);
            }
            if(!settlementTotals.containsKey(employeeId)) {
                settlementTotals.put(employeeId, sumOfSettlementAmount);
            }
        }
        */

        // Build a list of Employees based on the original employeeIds set to update Risk Level
        List<Employee__c> employeesToUpdate = [SELECT Id, Risk_Level__c FROM Employee__c WHERE Id IN :employeeIds];

        // Loop through the list of Employees
        for(Employee__c employee : employeesToUpdate) {
            /*
            // If the employee is in the claimCounts map, update their Total Claims field using the map value
            if(claimCounts.containsKey(employee.Id)) {
                employee.Total_Claims__c = claimCounts.get(employee.Id);
            }

            // If the employee is in the settlementTotals map, update their Total Settlement Amount field using the map value
            if(settlementTotals.containsKey(employee.Id)) {
                employee.Total_Settlement_Amount__c = settlementTotals.get(employee.Id);
            }
            */

            // If the employee is in the employeeTotalByInsuranceProvider map, retrieve the inner map containing the employee's related providers and totals
            if(employeeTotalByInsuranceProvider.containsKey(employee.Id)) {
                // The providersAndTotals map will store the inner map<Id,Decimal> from the employeeTotalByInsuranceProvider map
                Map<Id,Decimal> providersAndTotals = employeeTotalByInsuranceProvider.get(employee.Id);
                // Extract the unduplicated provider Ids from the providersAndTotals map
                Set<Id> providerIds = providersAndTotals.keySet();
                if(!providerIds.isEmpty()) {
                    for(Id providerId : providerIds) {
                        Decimal totalAmount = providersAndTotals.get(providerId);
                        // If totalAmount is greater than or equal to $20K, Risk Level = High Risk
                        if(totalAmount >= high) {
                            employee.Risk_Level__c = 'High Risk';
                        }
                        // If totalAmount is less than $20K but greater than or equal to $10K, Risk Level = Medium Risk
                        else if(totalAmount >= medium && totalAmount < high) {
                            employee.Risk_Level__c = 'Medium Risk';
                        }
                        // If totalAmount is less than $10K, Risk Level = Standard
                        else {
                            employee.Risk_Level__c = 'Standard';
                        }
                    }
                }
            }
        }

        updateClaimCountsAndSettlementAmount(employeeIds);

        // Uncomment this System.debug line if you want to test the code without running an actual DML operation
        // System.debug('Updated risk level ran');
        
        update employeesToUpdate;
    } 

    private static void updateClaimCountsAndSettlementAmount(Set<Id> employeeIds) {
        List<Employee__c> employeesToUpdate = [SELECT Id, Total_Claims__c, Total_Settlement_Amount__c FROM Employee__c WHERE Id IN :employeeIds];

        List<AggregateResult> totalClaimsAndAmountsByEmployee = [SELECT Employee__c, COUNT(Id) totalClaims, SUM(Claim__r.Settlement_Amount__c) totalSettlementAmount FROM Employee_Claim__c WHERE Employee__c IN :employeeIds GROUP BY Employee__c];

        Map<Id,Integer> claimCounts = new Map<Id,Integer>();
        Map<Id,Decimal> settlementTotals = new Map<Id,Decimal>();

        for(AggregateResult ar : totalClaimsAndAmountsByEmployee) {
            Id employeeId = (Id)ar.get('Employee__c');
            Integer numberOfClaims = (Integer)ar.get('totalClaims');
            Decimal sumOfSettlementAmount = (Decimal)ar.get('totalSettlementAmount');
            if(!claimCounts.containsKey(employeeId)) {
                claimCounts.put(employeeId, numberOfClaims);
            }
            if(!settlementTotals.containsKey(employeeId)) {
                settlementTotals.put(employeeId, sumOfSettlementAmount);
            }
        }

        for(Employee__c employee : employeesToUpdate) {
            // If the employee is in the claimCounts map, update their Total Claims field using the map value
            if(claimCounts.containsKey(employee.Id)) {
                employee.Total_Claims__c = claimCounts.get(employee.Id);
            }

            // If the employee is in the settlementTotals map, update their Total Settlement Amount field using the map value
            if(settlementTotals.containsKey(employee.Id)) {
                employee.Total_Settlement_Amount__c = settlementTotals.get(employee.Id);
            }
        }

        update employeesToUpdate;
    }
}
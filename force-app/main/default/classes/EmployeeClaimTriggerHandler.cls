public class EmployeeClaimTriggerHandler {
    public static void updateRiskLevel(
        // Pass in new/updated Employee Claims and old/deleted/undeleted Employee Claims
        // Pass in System.TriggerOperation operation type to dictate logic for insert/update versus delete/undelete
        List<Employee_Claim__c> newClaims,
        List<Employee_Claim__c> oldClaims,
        System.TriggerOperation operationType
    ) {
        // Risk thresholds - determined by company; update as needed
        // Standard is < 10000
        // Medium is >= 10000 but < 20000
        // High is >= 20000
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
        List<AggregateResult> claimsByEmployeeAndProvider = [SELECT Employee__c, Claim__r.Insurance_Provider__c providerId, SUM(Claim__r.Settlement_Amount__c) totalAmount FROM Employee_Claim__c WHERE Employee__c IN :employeeIds GROUP BY Employee__c, Claim__r.Insurance_Provider__c];

        // Create a map where the key is the Employee Id and the value is an inner map consisting of Insurance Provider Id (key) and total Settlement Amount by provider (value)
        Map<Id,Map<Id,Decimal>> employeeTotalByInsuranceProvider = new Map<Id,Map<Id,Decimal>>();

        // Loop through the AggregateResult list and populate the employeeTotalByInsuranceProvider map
        for(AggregateResult ar : claimsByEmployeeAndProvider) {
            Id employeeId = (Id)ar.get('Employee__c');
            Id providerId = (Id)ar.get('providerId');
            Decimal cumulativeSettlementAmount = (Decimal)ar.get('totalAmount');
            
            if(cumulativeSettlementAmount == null) {
                cumulativeSettlementAmount = 0;
            }
            
            // If the employee is not yet in the employeeTotalByInsuranceProvider map, add their Id as a key and a map of the current provider and total payout amount for that provider as the value
            if(!employeeTotalByInsuranceProvider.containsKey(employeeId)) {
                employeeTotalByInsuranceProvider.put(employeeId, new Map<Id,Decimal>{providerId => cumulativeSettlementAmount});
            }

            // If the employee is already in the employeeTotalByInsuranceProvider map, retrieve their Id (key) and put the current provider and their total payout amount into the map (value)
            // This covers the scenario if an employee has multiple claims across different providers
            else {
                employeeTotalByInsuranceProvider.get(employeeId).put(providerId, cumulativeSettlementAmount);
            }
        }

        // Uncomment the System.debug statements below if you need to test whether the aggregate SOQL query and map are populated
        // System.debug('claimsByEmployeeAndProvider=' + claimsByEmployeeAndProvider);
        // System.debug('employeeTotalByInsuranceProvider=' + employeeTotalByInsuranceProvider);

        
        // Query for Employee Claim records using AggregateResult to calculate the total number of Claims and cumulative Settlement Amount for each Employee
        List<AggregateResult> totalClaimsAndAmountsByEmployee = [SELECT Employee__c, COUNT(Id) totalClaims, SUM(Claim__r.Settlement_Amount__c) totalSettlementAmount FROM Employee_Claim__c WHERE Employee__c IN :employeeIds GROUP BY Employee__c];

        // Create a map of employee Ids (key) and number of claims for each employee (value)
        Map<Id,Integer> claimCounts = new Map<Id,Integer>();

        // Create a map of employee Ids (key) and cumulative Settlement Amount for each employee (value)
        Map<Id,Decimal> settlementTotals = new Map<Id,Decimal>();

        // Loop through the results of the aggregate SOQL query to populate the claimCounts and settlementTotals maps declared above
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

        // Build a list of Employees based on the original employeeIds set to update Risk Level
        List<Employee__c> employeesToUpdate = [SELECT Id, Risk_Level__c, Total_Claims__c, Total_Settlement_Amount__c FROM Employee__c WHERE Id IN :employeeIds];

        // Loop through the list of Employees
        for(Employee__c employee : employeesToUpdate) {

            // Set Total Claims and Total Settlement Amount to 0 so that these field values reset if all Employee Claim records are deleted for a given Employee
            employee.Total_Claims__c = 0;
            employee.Total_Settlement_Amount__c = 0;
            
            // If the employee is in the claimCounts map, update their Total Claims field using the map value
            if(claimCounts.containsKey(employee.Id)) {
                employee.Total_Claims__c = claimCounts.get(employee.Id);
            }

            // If the employee is in the settlementTotals map, update their Total Settlement Amount field using the map value
            if(settlementTotals.containsKey(employee.Id)) {
                employee.Total_Settlement_Amount__c = settlementTotals.get(employee.Id);
            }

            // Set Risk Level to Standard, the default, so it will remain this way if the employee does not meet high or medium thresholds
            employee.Risk_Level__c = 'Standard';

            // If the employee is in the employeeTotalByInsuranceProvider map, retrieve the inner map containing the employee's related providers and totals
            if(employeeTotalByInsuranceProvider.containsKey(employee.Id)) {

                // The providersAndTotals map will store the inner map<Id,Decimal> from the employeeTotalByInsuranceProvider map
                Map<Id,Decimal> providersAndTotals = employeeTotalByInsuranceProvider.get(employee.Id);

                // Uncomment the System.debug below to check if providersAndTotals map is correctly populated
                // System.debug('Employee=' + employee.Id + ' Provider Totals=' + providersAndTotals);

                // Initialize riskLevel variable to Standard, which will be the default Risk Level if the medium and high thresholds are not met
                String riskLevel = 'Standard';

                // Loop through the providersAndTotals map to set the Risk Level on Employee
                for(Decimal totalAmount : providersAndTotals.values()) {

                    // Do the High Risk check first, because if an Employee meets the threshold for High Risk, they won't be any other Risk Level
                    if(totalAmount >= high) {
                        riskLevel = 'High Risk';
                        break;
                    }

                    // If the Employee is not High Risk, check if they meet the threshold for Medium Risk
                    if(totalAmount >= medium) {
                        riskLevel = 'Medium Risk';
                    }
                }

                // Set the Employee's Risk Level to whichever value is determined via the if conditions above, or the default Standard value
                employee.Risk_Level__c = riskLevel;

                // Uncomment the System.debug below to test if the riskLevel is correctly updated
                // System.debug('Employee=' + employee.Id + ' Calculated Risk=' + riskLevel);

            }
        }

        // Uncomment this System.debug line if you want to test the code without running an actual DML operation
        // System.debug('Updated risk level ran');

        // Uncomment the code below to test if Total Claims, Total Settlement Amount, and Risk Level fields updated correctly
        /*
        for(Employee__c emp : employeesToUpdate) {
            System.debug('Employee=' + emp.Id + ', Claims=' + emp.Total_Claims__c + ', Settlement=' + emp.Total_Settlement_Amount__c + ', Risk=' + emp.Risk_Level__c);
        }
        */

        // DML to update the Risk Level, Total Claims, and Total Settlement Amount fields on the Employee records
        update employeesToUpdate;
    }
}
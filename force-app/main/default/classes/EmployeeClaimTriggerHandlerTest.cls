@isTest
private class EmployeeClaimTriggerHandlerTest {
    public static List<Employee_Claim__c> employeeClaims = new List<Employee_Claim__c>();
    public static List<Claim__c> testClaimsList = new List<Claim__c>();
    
    @TestSetup
    static void createTestData(){

        // Create test Accounts to represent Insurance Providers
        List<Account> testProvidersList = new List<Account>();

        for(Integer i = 0; i < 10; i++) {
            Account testProvider = new Account();
            testProvider.Name = 'Test Provider ' + i;
            testProvidersList.add(testProvider);
        }

        insert testProvidersList;

        Integer providerCounter = 0;
        Integer providerMaxCounter = 10;

        // Create test Employees
        List<Employee__c> testEmployeesList = new List<Employee__c>();

        for(Integer i = 0; i < 50; i++) {
            Employee__c testEmployee = new Employee__c();
            testEmployee.Name = 'Test Person ' + i;
            testEmployeesList.add(testEmployee);
        }

        insert testEmployeesList;

        Integer employeeCounter = 0;
        Integer employeeMaxCounter = 50;

        // Create test Claims
        for(Integer i = 0; i < 100; i++) {
            Claim__c testClaim = new Claim__c();
            testClaim.Name = 'My Test Claim ' + i;
            testClaim.Settlement_Amount__c = 2000;
            if(providerCounter < providerMaxCounter) {
                testClaim.Insurance_Provider__c = testProvidersList.get(providerCounter).Id;
                providerCounter++;
            }
            if(providerCounter == providerMaxCounter) {
                providerCounter = 0;
            }
            testClaimsList.add(testClaim);
        }

        insert testClaimsList;

        Integer claimCounter = 0;
        Integer claimMaxCounter = 100;

        // Create test Employee Claims
        for(Integer i = 0; i < 200; i++) {
            Employee_Claim__c testEmployeeClaim = new Employee_Claim__c();
            testEmployeeClaim.Name = 'My Test EC ' + i;
            if(employeeCounter < employeeMaxCounter) {
                testEmployeeClaim.Employee__c = testEmployeesList.get(employeeCounter).Id;
                employeeCounter++;
            }
            if(employeeCounter == employeeMaxCounter) {
                employeeCounter = 0;
            }
            if(claimCounter < claimMaxCounter) {
                testEmployeeClaim.Claim__c = testClaimsList.get(claimCounter).Id;
                claimCounter++;
            }
            if(claimCounter == claimMaxCounter) {
                claimCounter = 0;
            }
            employeeClaims.add(testEmployeeClaim);
        }

        insert employeeClaims;
    }

    @isTest
    static void testEmployeeClaimTriggerHandler_updateRiskLevelOnInsert() {
        List<Employee_Claim__c> newClaims = [SELECT Id, Employee__c, Claim__r.Insurance_Provider__c, Claim__r.Settlement_Amount__c FROM Employee_Claim__c WHERE NAME LIKE '%Test%'];
        List<Employee_Claim__c> oldClaims = new List<Employee_Claim__c>();

        Test.startTest();
        EmployeeClaimTriggerHandler.updateRiskLevel(newClaims, oldClaims, System.TriggerOperation.AFTER_INSERT);
        Test.stopTest();

        Set<Id> employeeIds = new Set<Id>();
        
        List<Employee_Claim__c> updatedClaims = [SELECT Id, Employee__c, Claim__r.Insurance_Provider__c, Claim__r.Settlement_Amount__c, Employee__r.Total_Claims__c, Employee__r.Total_Settlement_Amount__c FROM Employee_Claim__c WHERE Id IN :newClaims];
        for(Employee_Claim__c updatedClaim : updatedClaims) {
            employeeIds.add(updatedClaim.Employee__c);
        }

        List<Employee__c> updatedEmployees = [SELECT Id, Risk_Level__c FROM Employee__c WHERE Id IN :employeeIds];
        for(Employee__c updatedEmployee : updatedEmployees) {
            Assert.areEqual('Standard', updatedEmployee.Risk_Level__c);
        }
    }

    /*
    @isTest
    static void testEmployeeClaimTriggerHandler_updateRiskLevelOnUpdate() {

        for(Claim__c claim : testClaimsList) {
            claim.Settlement_Amount__c = 15000;
        }

        update testClaimsList;

        List<Employee_Claim__c> newClaims = [SELECT Id, Employee__c, Claim__r.Insurance_Provider__c, Claim__r.Settlement_Amount__c FROM Employee_Claim__c WHERE NAME LIKE '%Test%'];
        List<Employee_Claim__c> oldClaims = [SELECT Id, Employee__c, Claim__r.Insurance_Provider__c, Claim__r.Settlement_Amount__c FROM Employee_Claim__c WHERE NAME LIKE '%Test%'];

        update newClaims;

        Test.startTest();
        EmployeeClaimTriggerHandler.updateRiskLevel(newClaims, oldClaims, System.TriggerOperation.AFTER_UPDATE);
        Test.stopTest();

        Set<Id> employeeIds = new Set<Id>();
        
        List<Employee_Claim__c> updatedClaims = [SELECT Id, Employee__c, Claim__r.Insurance_Provider__c, Claim__r.Settlement_Amount__c, Employee__r.Total_Claims__c, Employee__r.Total_Settlement_Amount__c FROM Employee_Claim__c WHERE Id IN :newClaims];
        for(Employee_Claim__c updatedClaim : updatedClaims) {
            employeeIds.add(updatedClaim.Employee__c);
        }

        List<Employee__c> updatedEmployees = [SELECT Id, Risk_Level__c FROM Employee__c WHERE Id IN :employeeIds];
        for(Employee__c updatedEmployee : updatedEmployees) {
            Assert.areEqual('Medium Risk', updatedEmployee.Risk_Level__c);
        }
    }
    */
}
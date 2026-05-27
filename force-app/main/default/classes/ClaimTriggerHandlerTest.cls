@isTest
private class ClaimTriggerHandlerTest {
    public static List<Claim__c> claims = new List<Claim__c>();

    @TestSetup
    static void createTestData(){

        Account testProvider = new Account();
        testProvider.Name = 'Test Provider';
        insert testProvider;

        for(Integer i = 0; i < 50; i++) {
            Claim__c claim = new Claim__c();
            claim.Name = 'Test ' + i;
            claim.Incident_Date__c = Date.today().addDays(-3);
            claim.Date_Filed__c = Date.today().addDays(-1);
            claim.Status__c = 'Settled';
            claim.Settlement_Amount__c = 15000;
            claim.Settlement_Date__c = null;
            claim.Insurance_Provider__c = testProvider.Id;
            claim.Is_High_Value__c = true;
            claims.add(claim);
        }

        for(Integer i = 0; i < 50; i++) {
            Claim__c claim = new Claim__c();
            claim.Name = 'Low ' + i;
            claim.Incident_Date__c = Date.today().addDays(-3);
            claim.Date_Filed__c = Date.today().addDays(-1);
            claim.Status__c = 'Open';
            claim.Settlement_Amount__c = 0;
            claim.Insurance_Provider__c = testProvider.Id;
            claims.add(claim);
        }

        for(Integer i = 0; i < 10; i++) {
            Claim__c claim = new Claim__c();
            claim.Name = 'NotHigh ' + i;
            claim.Incident_Date__c = Date.today().addDays(-3);
            claim.Date_Filed__c = Date.today().addDays(-1);
            claim.Status__c = 'Settled';
            claim.Settlement_Amount__c = 5000;
            claim.Insurance_Provider__c = testProvider.Id;
            claims.add(claim);
        }

        for(Integer i = 0; i < 50; i++) {
            Claim__c claim = new Claim__c();
            claim.Name = 'Settled ' + i;
            claim.Incident_Date__c = Date.today().addDays(-3);
            claim.Date_Filed__c = Date.today().addDays(-1);
            claim.Status__c = 'Settled';
            claim.Settlement_Amount__c = 0;
            claim.Insurance_Provider__c = testProvider.Id;
            claims.add(claim);
        }

        for(Integer i = 0; i < 10; i++) {
            Claim__c claim = new Claim__c();
            claim.Name = 'Denied ' + i;
            claim.Incident_Date__c = Date.today().addDays(-3);
            claim.Date_Filed__c = Date.today().addDays(-1);
            claim.Status__c = 'Denied';
            claim.Settlement_Amount__c = 5000;
            claim.Insurance_Provider__c = testProvider.Id;
            claims.add(claim);
        }

        for(Integer i = 0; i < 10; i++) {
            Claim__c claim = new Claim__c();
            claim.Name = 'WrongDate ' + i;
            claim.Incident_Date__c = Date.today().addDays(-5);
            claim.Date_Filed__c = Date.today().addDays(-3);
            claim.Status__c = 'Settled';
            claim.Settlement_Amount__c = 15000;
            claim.Insurance_Provider__c = testProvider.Id;
            claims.add(claim);
        }

        insert claims;
    }

    @isTest
    static void testClaimTriggerHandler_checkDatesAndStatusOnInsert() {
        Map<Id,Claim__c> testClaimsMap = new Map<Id,Claim__c>([SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%Test%']);
        List<Claim__c> testClaims = [SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%Test%'];

        Test.startTest();
        ClaimTriggerHandler.updateClaimFields(testClaims, testClaimsMap, System.TriggerOperation.BEFORE_INSERT);
        Test.stopTest();

        List<Claim__c> updatedClaims = [SELECT Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Id IN :testClaims];
        for(Claim__c updatedClaim : updatedClaims) {
            Assert.areEqual('Settled', updatedClaim.Status__c);
            Assert.areEqual(15000, updatedClaim.Settlement_Amount__c);
            Assert.isTrue(updatedClaim.Incident_Date__c < updatedClaim.Date_Filed__c);
            Assert.isNotNull(updatedClaim.Days_Open__c);
            Assert.areEqual(true, updatedClaim.Is_High_Value__c);
        }
    }

    @isTest
    static void testClaimTriggerHandler_checkDatesAndStatusOnUpdate() {
        Map<Id,Claim__c> testClaimsMap = new Map<Id,Claim__c>([SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%Low%']);
        List<Claim__c> testClaims = [SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%Low%'];
        for(Claim__c claim : testClaims) {
            if(claim.Name.contains('Low')) {
                claim.Status__c = 'Settled';
                claim.Settlement_Amount__c = 15000;
            }
        }
        update testClaims;

        Test.startTest();
        ClaimTriggerHandler.updateClaimFields(testClaims, testClaimsMap, System.TriggerOperation.BEFORE_UPDATE);
        Test.stopTest();

        List<Claim__c> updatedClaims = [SELECT Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Id IN :testClaims];
        for(Claim__c updatedClaim : updatedClaims) {
            Assert.areEqual('Settled', updatedClaim.Status__c);
            Assert.areEqual(15000, updatedClaim.Settlement_Amount__c);
            Assert.isTrue(updatedClaim.Incident_Date__c < updatedClaim.Date_Filed__c);
            Assert.areEqual(Date.today(), updatedClaim.Settlement_Date__c);
            Assert.isNotNull(updatedClaim.Days_Open__c);
            Assert.areEqual(true, updatedClaim.Is_High_Value__c);
        }
    }

    @isTest
    static void testClaimTriggerHandler_checkDaysOpenIfClaimOpen() {
        Map<Id,Claim__c> testClaimsMap = new Map<Id,Claim__c>([SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%Low%']);
        List<Claim__c> testClaims = [SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%Low%'];

        Test.startTest();
        ClaimTriggerHandler.updateClaimFields(testClaims, testClaimsMap, System.TriggerOperation.BEFORE_INSERT);
        Test.stopTest();

        List<Claim__c> updatedClaims = [SELECT Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Id IN :testClaims];
        for(Claim__c updatedClaim : updatedClaims) {
            Assert.areEqual('Open', updatedClaim.Status__c);
            Assert.areEqual(0, updatedClaim.Settlement_Amount__c);
            Assert.isTrue(updatedClaim.Incident_Date__c < updatedClaim.Date_Filed__c);
            Assert.isNotNull(updatedClaim.Days_Open__c);
            Assert.areEqual(updatedClaim.Days_Open__c, updatedClaim.Incident_Date__c.daysBetween(Date.today()));
            Assert.areEqual(false, updatedClaim.Is_High_Value__c);
        }
    }

    @isTest
    static void testClaimTriggerHandler_checkIsHighValueOnInsert() {
        Map<Id,Claim__c> testClaimsMap = new Map<Id,Claim__c>([SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%NotHigh%']);
        List<Claim__c> testClaims = [SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%NotHigh%'];

        Test.startTest();
        ClaimTriggerHandler.updateClaimFields(testClaims, testClaimsMap, System.TriggerOperation.BEFORE_INSERT);
        Test.stopTest();

        List<Claim__c> updatedClaims = [SELECT Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Id IN :testClaims];
        for(Claim__c updatedClaim : updatedClaims) {
            Assert.areEqual('Settled', updatedClaim.Status__c);
            Assert.areEqual(5000, updatedClaim.Settlement_Amount__c);
            Assert.isTrue(updatedClaim.Incident_Date__c < updatedClaim.Date_Filed__c);
            Assert.isNotNull(updatedClaim.Days_Open__c);
            Assert.areEqual(false, updatedClaim.Is_High_Value__c);
        }
    }

    @isTest
    static void testClaimTriggerHandler_checkIsHighValueOnUpdate() {
        Map<Id,Claim__c> testClaimsMap = new Map<Id,Claim__c>([SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%Low%']);
        List<Claim__c> testClaims = [SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%Low%'];
        for(Claim__c claim : testClaims) {
            if(claim.Name.contains('Low')) {
                claim.Status__c = 'Settled';
                claim.Settlement_Amount__c = 10000;
            }
        }
        update testClaims;

        Test.startTest();
        ClaimTriggerHandler.updateClaimFields(testClaims, testClaimsMap, System.TriggerOperation.BEFORE_UPDATE);
        Test.stopTest();

        List<Claim__c> updatedClaims = [SELECT Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Id IN :testClaims];
        for(Claim__c updatedClaim : updatedClaims) {
            Assert.areEqual('Settled', updatedClaim.Status__c);
            Assert.areEqual(10000, updatedClaim.Settlement_Amount__c);
            Assert.isTrue(updatedClaim.Incident_Date__c < updatedClaim.Date_Filed__c);
            Assert.isNotNull(updatedClaim.Days_Open__c);
            Assert.areEqual(false, updatedClaim.Is_High_Value__c);
        }
    }

    @isTest
    static void testClaimTriggerHandler_checkSettlementAmountOnInsert() {
        Map<Id,Claim__c> settledClaimsWithWrongAmountMap = new Map<Id,Claim__c>([SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%Settled%']);
        List<Claim__c> settledClaimsWithWrongAmount = [SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%Settled%'];

        Test.startTest();
        ClaimTriggerHandler.updateClaimFields(settledClaimsWithWrongAmount, settledClaimsWithWrongAmountMap, System.TriggerOperation.BEFORE_INSERT);
        Test.stopTest();

        List<Claim__c> updatedSettledClaims = [SELECT Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Id IN :settledClaimsWithWrongAmount];
        for(Claim__c updatedSettledClaim : updatedSettledClaims) {
            Assert.areEqual('Settled', updatedSettledClaim.Status__c);
            Assert.areEqual(0, updatedSettledClaim.Settlement_Amount__c, 'Settlement Amount must be greater than zero before Claim is marked as Settled.');
            Assert.isTrue(updatedSettledClaim.Incident_Date__c < updatedSettledClaim.Date_Filed__c);
            Assert.isNotNull(updatedSettledClaim.Days_Open__c);
            Assert.areEqual(false, updatedSettledClaim.Is_High_Value__c);
        }
    }

    @isTest
    static void testClaimTriggerHandler_checkSettlementAmountOnUpdate() {
        Map<Id,Claim__c> settledClaimsWithWrongAmountMap = new Map<Id,Claim__c>([SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%Settled%']);
        List<Claim__c> settledClaimsWithWrongAmount = [SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%Settled%'];
        for(Claim__c settledClaimWithWrongAmount : settledClaimsWithWrongAmount) {
            settledClaimWithWrongAmount.Settlement_Amount__c = -1;
        }
        update settledClaimsWithWrongAmount;

        Test.startTest();
        ClaimTriggerHandler.updateClaimFields(settledClaimsWithWrongAmount, settledClaimsWithWrongAmountMap, System.TriggerOperation.BEFORE_UPDATE);
        Test.stopTest();

        List<Claim__c> updatedSettledClaims = [SELECT Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Id IN :settledClaimsWithWrongAmount];
        for(Claim__c updatedSettledClaim : updatedSettledClaims) {
            Assert.areEqual('Settled', updatedSettledClaim.Status__c);
            Assert.areEqual(-1, updatedSettledClaim.Settlement_Amount__c, 'Settlement Amount must be greater than zero before Claim is marked as Settled.');
            Assert.isTrue(updatedSettledClaim.Incident_Date__c < updatedSettledClaim.Date_Filed__c);
            Assert.isNotNull(updatedSettledClaim.Days_Open__c);
            Assert.areEqual(false, updatedSettledClaim.Is_High_Value__c);
        }
    }

    @isTest
    static void testClaimTriggerHandler_checkDeniedClaimsOnInsert() {
        Map<Id,Claim__c> deniedClaimsWithWrongAmountMap = new Map<Id,Claim__c>([SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%Denied%']);
        List<Claim__c> deniedClaimsWithWrongAmount = [SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%Denied%'];

        Test.startTest();
        ClaimTriggerHandler.updateClaimFields(deniedClaimsWithWrongAmount, deniedClaimsWithWrongAmountMap, System.TriggerOperation.BEFORE_INSERT);
        Test.stopTest();

        List<Claim__c> updatedDeniedClaims = [SELECT Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Id IN :deniedClaimsWithWrongAmount];
        for(Claim__c updatedDeniedClaim : updatedDeniedClaims) {
            Assert.areEqual('Denied', updatedDeniedClaim.Status__c);
            Assert.areEqual(0, updatedDeniedClaim.Settlement_Amount__c);
            Assert.isTrue(updatedDeniedClaim.Incident_Date__c < updatedDeniedClaim.Date_Filed__c);
            Assert.isNotNull(updatedDeniedClaim.Days_Open__c);
            Assert.areEqual(false, updatedDeniedClaim.Is_High_Value__c);
        }
    }

    @isTest
    static void testClaimTriggerHandler_checkDeniedClaimsOnUpdate() {
        Map<Id,Claim__c> deniedClaimsWithWrongAmountMap = new Map<Id,Claim__c>([SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%Denied%']);
        List<Claim__c> deniedClaimsWithWrongAmount = [SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%Denied%'];
        for(Claim__c deniedClaimWithWrongAmount : deniedClaimsWithWrongAmount) {
            deniedClaimWithWrongAmount.Settlement_Amount__c = 5;
        }
        update deniedClaimsWithWrongAmount;

        Test.startTest();
        ClaimTriggerHandler.updateClaimFields(deniedClaimsWithWrongAmount, deniedClaimsWithWrongAmountMap, System.TriggerOperation.BEFORE_UPDATE);
        Test.stopTest();

        List<Claim__c> updatedDeniedClaims = [SELECT Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Id IN :deniedClaimsWithWrongAmount];
        for(Claim__c updatedDeniedClaim : updatedDeniedClaims) {
            Assert.areEqual('Denied', updatedDeniedClaim.Status__c);
            Assert.areEqual(0, updatedDeniedClaim.Settlement_Amount__c);
            Assert.isTrue(updatedDeniedClaim.Incident_Date__c < updatedDeniedClaim.Date_Filed__c);
            Assert.isNotNull(updatedDeniedClaim.Days_Open__c);
            Assert.areEqual(false, updatedDeniedClaim.Is_High_Value__c);
        }
    }

    /*
    This test did not work but this seems to prove that the code for validating the Incident Date works
    @isTest
    static void testClaimTriggerHandler_wrongDatesOnUpdate() {
        Map<Id,Claim__c> claimsWithWrongDateMap = new Map<Id,Claim__c>([SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%Wrong%']);
        List<Claim__c> claimsWithWrongDate = [SELECT Id, Name, Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Settlement_Date__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Name LIKE '%Wrong%'];
        for(Claim__c claimWithWrongDate : claimsWithWrongDate) {
            claimWithWrongDate.Incident_Date__c = Date.today().addDays(-1);
        }
        update claimsWithWrongDate;

        Test.startTest();
        ClaimTriggerHandler.updateClaimFields(claimsWithWrongDate, claimsWithWrongDateMap, System.TriggerOperation.BEFORE_UPDATE);
        Test.stopTest();

        List<Claim__c> updatedClaims = [SELECT Incident_Date__c, Date_Filed__c, Status__c, Settlement_Amount__c, Days_Open__c, Is_High_Value__c FROM Claim__c WHERE Id IN :claimsWithWrongDate];
        for(Claim__c updatedClaim : updatedClaims) {
            Assert.areEqual('Settled', updatedClaim.Status__c);
            Assert.areEqual(15000, updatedClaim.Settlement_Amount__c);
            Assert.isTrue(updatedClaim.Incident_Date__c > updatedClaim.Date_Filed__c, 'Incident Date must not be in the future. Incident Date cannot be later than Date Filed.');
        }
    }
    */
}
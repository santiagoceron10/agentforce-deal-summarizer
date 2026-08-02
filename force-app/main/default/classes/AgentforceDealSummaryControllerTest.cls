/**
 * AgentforceDealSummaryControllerTest
 * -----------------------------------
 * Scaffold test class for AgentforceDealSummaryController.
 *
 * SCAFFOLD NOTE: This test has NOT been executed — there is no Salesforce org
 * in this project to run it against. It documents the intended coverage shape
 * (context gathering across Opportunity + related records, and the guarded
 * Agentforce swap-point) so the class is ready to run once deployed.
 *
 * The Agentforce invocation is an unwired swap-point that throws by design, so
 * the happy-path test asserts that context gathering succeeds up to the point
 * of invocation. Once invokeAgentforce() is wired in your org, replace the
 * invocation assertion with an assertion on the returned summary (mock the
 * callout/agent response as appropriate).
 */
@IsTest
private class AgentforceDealSummaryControllerTest {

    @TestSetup
    static void setup() {
        Account acct = new Account(
            Name = 'Acme Corp', Industry = 'Technology',
            NumberOfEmployees = 500, AnnualRevenue = 25000000);
        insert acct;

        Contact con = new Contact(
            FirstName = 'Dana', LastName = 'Buyer',
            Title = 'VP Operations', Email = 'dana.buyer@example.com',
            AccountId = acct.Id);
        insert con;

        Opportunity opp = new Opportunity(
            Name = 'Acme - Platform Expansion',
            StageName = 'Proposal/Price Quote',
            Amount = 120000,
            CloseDate = Date.today().addDays(30),
            NextStep = 'Send revised proposal',
            Description = 'Expansion of the platform footprint into a second region.',
            AccountId = acct.Id);
        insert opp;

        insert new OpportunityContactRole(
            OpportunityId = opp.Id, ContactId = con.Id,
            IsPrimary = true, Role = 'Decision Maker');

        insert new Task(
            WhatId = opp.Id, Subject = 'Discovery call',
            Status = 'Completed', ActivityDate = Date.today().addDays(-5),
            Description = 'Reviewed requirements and success criteria.');

        insert new Event(
            WhatId = opp.Id, Subject = 'Executive readout',
            ActivityDate = Date.today().addDays(-1),
            DurationInMinutes = 30, ActivityDateTime = System.now());
    }

    @IsTest
    static void summarizeDeal_gathersContextThenReachesSwapPoint() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        Boolean reachedSwapPoint = false;
        try {
            AgentforceDealSummaryController.summarizeDeal(opp.Id);
        } catch (AgentforceDealSummaryController.DealSummaryException e) {
            // Expected: context gathering succeeded; the unwired Agentforce
            // swap-point throws its explicit "not wired" guard.
            reachedSwapPoint = e.getMessage().contains('not wired');
        }
        Test.stopTest();

        System.assert(
            reachedSwapPoint,
            'Expected context gathering to succeed and reach the Agentforce swap-point guard.');
    }

    @IsTest
    static void summarizeDeal_nullIdThrows() {
        Test.startTest();
        Boolean threw = false;
        try {
            AgentforceDealSummaryController.summarizeDeal(null);
        } catch (AgentforceDealSummaryController.DealSummaryException e) {
            threw = e.getMessage().contains('Opportunity Id is required');
        }
        Test.stopTest();

        System.assert(threw, 'Expected a validation error for a null Opportunity Id.');
    }
}

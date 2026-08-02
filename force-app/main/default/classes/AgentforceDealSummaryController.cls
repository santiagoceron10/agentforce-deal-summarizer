/**
 * AgentforceDealSummaryController
 * -------------------------------
 * @AuraEnabled controller for the `agentforceDealSummarizer` LWC.
 *
 * Gathers an Opportunity's deal context — the Opportunity itself plus its
 * Account, primary Contact (via OpportunityContactRole), recent activities
 * (Tasks/Events), and products (OpportunityLineItems) — serializes it to
 * JSON, and hands it to an Agentforce agent to produce a concise, grounded
 * deal summary (health, momentum, risks, recommended next steps).
 *
 * Security posture: `with sharing` + all SOQL runs `WITH USER_MODE`, so
 * object-, field-, and record-level access are enforced for the running user.
 *
 * SCAFFOLD NOTE: This class is a documented reference scaffold. It has NOT
 * been deployed to or tested against a live Salesforce/Agentforce org. The
 * Agentforce invocation is isolated in `invokeAgentforce()` as the single
 * integration swap-point (see the method body and the repo README).
 */
public with sharing class AgentforceDealSummaryController {

    /**
     * API name of the Agentforce agent that produces the summary.
     * Replace with your org's agent API name, or (recommended for production)
     * source it from Custom Metadata / Custom Settings instead of hardcoding.
     */
    private static final String AGENT_API_NAME = 'REPLACE_WITH_YOUR_AGENT_API_NAME';

    /** Cap on related records pulled into the prompt context, to keep it lean. */
    private static final Integer MAX_ACTIVITIES = 10;
    private static final Integer MAX_LINE_ITEMS = 25;

    public class DealSummaryException extends Exception {}

    /**
     * Entry point invoked by the LWC. Returns the AI-generated summary text
     * for the given Opportunity.
     *
     * @param opportunityId  Id of the Opportunity to summarize.
     * @return               The generated deal summary.
     */
    @AuraEnabled
    public static String summarizeDeal(Id opportunityId) {
        if (opportunityId == null) {
            throw buildException('An Opportunity Id is required.');
        }

        try {
            DealContext context = gatherContext(opportunityId);
            String serialized = JSON.serializePretty(context, true);
            return invokeAgentforce(AGENT_API_NAME, serialized);
        } catch (DealSummaryException dse) {
            throw dse;
        } catch (Exception e) {
            throw buildException('Unable to summarize deal: ' + e.getMessage());
        }
    }

    /**
     * Collects the Opportunity and its related context, each query enforcing
     * the running user's security via WITH USER_MODE.
     */
    private static DealContext gatherContext(Id opportunityId) {
        List<Opportunity> opps = [
            SELECT Id, Name, StageName, Amount, CloseDate, Probability,
                   NextStep, Description, ForecastCategoryName,
                   Owner.Name, Account.Name, Account.Industry, Account.Website,
                   Account.NumberOfEmployees, Account.AnnualRevenue
            FROM Opportunity
            WHERE Id = :opportunityId
            WITH USER_MODE
            LIMIT 1
        ];

        if (opps.isEmpty()) {
            throw buildException(
                'Opportunity not found, or you do not have access to it.');
        }
        Opportunity opp = opps[0];

        DealContext ctx = new DealContext();
        ctx.opportunity = new OpportunityInfo(opp);
        ctx.account = new AccountInfo(opp);
        ctx.primaryContact = fetchPrimaryContact(opportunityId);
        ctx.recentActivities = fetchRecentActivities(opportunityId);
        ctx.products = fetchProducts(opportunityId);
        return ctx;
    }

    /** Primary contact on the Opportunity via OpportunityContactRole. */
    private static ContactInfo fetchPrimaryContact(Id opportunityId) {
        List<OpportunityContactRole> roles = [
            SELECT Contact.Name, Contact.Title, Contact.Email, Role
            FROM OpportunityContactRole
            WHERE OpportunityId = :opportunityId AND IsPrimary = TRUE
            WITH USER_MODE
            LIMIT 1
        ];
        return roles.isEmpty() ? null : new ContactInfo(roles[0]);
    }

    /** Recent Tasks and Events logged against the Opportunity. */
    private static List<ActivityInfo> fetchRecentActivities(Id opportunityId) {
        List<ActivityInfo> activities = new List<ActivityInfo>();

        for (Task t : [
            SELECT Subject, Status, ActivityDate, Description
            FROM Task
            WHERE WhatId = :opportunityId
            WITH USER_MODE
            ORDER BY ActivityDate DESC NULLS LAST
            LIMIT :MAX_ACTIVITIES
        ]) {
            activities.add(new ActivityInfo(
                'Task', t.Subject, t.Status, t.ActivityDate, t.Description));
        }

        for (Event e : [
            SELECT Subject, ActivityDate, Description
            FROM Event
            WHERE WhatId = :opportunityId
            WITH USER_MODE
            ORDER BY ActivityDate DESC NULLS LAST
            LIMIT :MAX_ACTIVITIES
        ]) {
            activities.add(new ActivityInfo(
                'Event', e.Subject, null, e.ActivityDate, e.Description));
        }

        return activities;
    }

    /** Products on the deal via OpportunityLineItem. */
    private static List<ProductInfo> fetchProducts(Id opportunityId) {
        List<ProductInfo> products = new List<ProductInfo>();
        for (OpportunityLineItem oli : [
            SELECT Quantity, UnitPrice, TotalPrice,
                   Product2.Name, PricebookEntry.Product2.Name
            FROM OpportunityLineItem
            WHERE OpportunityId = :opportunityId
            WITH USER_MODE
            LIMIT :MAX_LINE_ITEMS
        ]) {
            products.add(new ProductInfo(oli));
        }
        return products;
    }

    /**
     * === Agentforce invocation swap-point ===
     *
     * This is the single integration point to wire against your org. It should
     * send `serializedContext` to the Agentforce agent identified by
     * `agentApiName` and return the generated summary text — for example via
     * the Agentforce Apex/Connect API or an Invocable Action exposed by your
     * agent, together with a prompt instructing the agent to:
     *   - use ONLY the supplied Salesforce data (no invented figures),
     *   - summarize deal health, momentum, risks, and recommended next steps,
     *   - clearly flag missing information.
     *
     * This reference scaffold does not bind a specific invocation, because the
     * correct binding depends on how Agentforce is enabled in your org. Until
     * you implement it, the method surfaces an explicit, non-silent guard so it
     * can never be mistaken for a working summary.
     */
    @SuppressWarnings('PMD.UnusedFormalParameter')
    private static String invokeAgentforce(String agentApiName, String serializedContext) {
        throw buildException(
            'Agentforce invocation is not wired. Implement invokeAgentforce() '
            + 'against your org\'s Agentforce agent ("' + agentApiName + '"). '
            + 'See the repository README, "Setup", for guidance.');
    }

    private static DealSummaryException buildException(String message) {
        DealSummaryException e = new DealSummaryException(message);
        e.setMessage(message);
        return e;
    }

    // ---- Serializable context DTOs (shape the JSON sent to the agent) ----

    public class DealContext {
        public OpportunityInfo opportunity;
        public AccountInfo account;
        public ContactInfo primaryContact;
        public List<ActivityInfo> recentActivities;
        public List<ProductInfo> products;
    }

    public class OpportunityInfo {
        public String name;
        public String stage;
        public Decimal amount;
        public Date closeDate;
        public Decimal probability;
        public String nextStep;
        public String description;
        public String forecastCategory;
        public String owner;
        public OpportunityInfo(Opportunity o) {
            this.name = o.Name;
            this.stage = o.StageName;
            this.amount = o.Amount;
            this.closeDate = o.CloseDate;
            this.probability = o.Probability;
            this.nextStep = o.NextStep;
            this.description = o.Description;
            this.forecastCategory = o.ForecastCategoryName;
            this.owner = o.Owner != null ? o.Owner.Name : null;
        }
    }

    public class AccountInfo {
        public String name;
        public String industry;
        public String website;
        public Integer employees;
        public Decimal annualRevenue;
        public AccountInfo(Opportunity o) {
            if (o.Account == null) return;
            this.name = o.Account.Name;
            this.industry = o.Account.Industry;
            this.website = o.Account.Website;
            this.employees = o.Account.NumberOfEmployees;
            this.annualRevenue = o.Account.AnnualRevenue;
        }
    }

    public class ContactInfo {
        public String name;
        public String title;
        public String email;
        public String role;
        public ContactInfo(OpportunityContactRole r) {
            if (r.Contact != null) {
                this.name = r.Contact.Name;
                this.title = r.Contact.Title;
                this.email = r.Contact.Email;
            }
            this.role = r.Role;
        }
    }

    public class ActivityInfo {
        public String type;
        public String subject;
        public String status;
        public Date activityDate;
        public String description;
        public ActivityInfo(
            String type, String subject, String status,
            Date activityDate, String description) {
            this.type = type;
            this.subject = subject;
            this.status = status;
            this.activityDate = activityDate;
            this.description = description;
        }
    }

    public class ProductInfo {
        public String name;
        public Decimal quantity;
        public Decimal unitPrice;
        public Decimal totalPrice;
        public ProductInfo(OpportunityLineItem oli) {
            this.name = oli.Product2 != null && oli.Product2.Name != null
                ? oli.Product2.Name
                : (oli.PricebookEntry != null && oli.PricebookEntry.Product2 != null
                    ? oli.PricebookEntry.Product2.Name : null);
            this.quantity = oli.Quantity;
            this.unitPrice = oli.UnitPrice;
            this.totalPrice = oli.TotalPrice;
        }
    }
}

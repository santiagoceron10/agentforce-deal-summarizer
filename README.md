# Agentforce Deal Summarizer

**AI deal summaries on the Opportunity record page — powered by Salesforce Agentforce.**

A Lightning Web Component that gives sellers and managers a one-click, grounded
summary of any deal. Drop it on the Opportunity record page, click **Summarize
Deal**, and an Agentforce agent returns a concise read on the opportunity's
**health, momentum, risks, and recommended next steps** — using only the data
already in Salesforce, with a copy-to-clipboard button for pasting into a
deal-review doc or Slack.

> **Status:** ✅ System architecture & design + reference implementation — a
> complete, documented build you can deploy on your own stack (see **Setup**).
> The Agentforce invocation is intentionally left as a single, clearly-marked
> integration swap-point you wire up for your own org.

---

## Why it's useful

Deal reviews eat time: someone opens the Opportunity, clicks into activities,
scrolls the products, checks who the buyer is, and mentally assembles "where is
this deal, really?" This component does that assembly on demand — a grounded
summary built from the deal's own record, so reps prep faster and managers get a
consistent read across the pipeline.

- **Grounded, not generative guesswork** — the agent is given only the
  Opportunity's real Salesforce data and instructed not to invent figures.
- **Security-respecting** — all data is read `WITH USER_MODE`, so the summary
  only ever reflects what the running user is allowed to see.
- **In-context** — lives on the Opportunity page; no new app to open.

---

## Architecture

```text
Opportunity Record Page
        │
        ▼
Lightning Web Component  (agentforceDealSummarizer)
        │  @AuraEnabled Apex
        ▼
AgentforceDealSummaryController
        │  gathers deal context  (WITH USER_MODE)
        ▼
 Opportunity · Account · primary Contact · recent Activities · Products
        │  serialized to JSON
        ▼
Agentforce agent  (generates the summary)
        │
        ▼
AI deal summary  →  rendered in the component  (+ Copy)
```

**What goes into the summary context**

| Source | Fields |
|---|---|
| Opportunity | Name, Stage, Amount, Close Date, Probability, Next Step, Description, Forecast Category, Owner |
| Account | Name, Industry, Website, Employees, Annual Revenue |
| Primary Contact | via `OpportunityContactRole` (Name, Title, Email, Role) |
| Recent Activities | Tasks & Events (`WhatId` = Opportunity), most recent first |
| Products | `OpportunityLineItem` (Name, Quantity, Unit Price, Total Price) |

---

## Repository layout

```
force-app/main/default/
├── classes/
│   ├── AgentforceDealSummaryController.cls            # context gathering + agent invocation
│   ├── AgentforceDealSummaryController.cls-meta.xml
│   ├── AgentforceDealSummaryControllerTest.cls        # scaffold test (not executed)
│   └── AgentforceDealSummaryControllerTest.cls-meta.xml
└── lwc/agentforceDealSummarizer/
    ├── agentforceDealSummarizer.js
    ├── agentforceDealSummarizer.html
    ├── agentforceDealSummarizer.css
    └── agentforceDealSummarizer.js-meta.xml           # target: Opportunity record page
sfdx-project.json · .forceignore · .gitignore · LICENSE · DESIGN.md
```

---

## Prerequisites

- A Salesforce org on **Summer '25 or later** with **Agentforce enabled**
- An **active Agentforce agent** you can invoke
- **API version 66.0+**
- **Salesforce CLI** (`sf`)
- Lightning Experience

---

## Setup

> This is the reference implementation. The steps below show how to deploy
> and wire it in your own org.

1. **Deploy the metadata**
   ```bash
   git clone https://github.com/santiagoceron10/agentforce-deal-summarizer.git
   cd agentforce-deal-summarizer
   sf project deploy start --source-dir force-app
   ```

2. **Point it at your agent.** In `AgentforceDealSummaryController.cls`, replace
   the placeholder:
   ```apex
   private static final String AGENT_API_NAME = 'REPLACE_WITH_YOUR_AGENT_API_NAME';
   ```
   with your Agentforce agent's API name. For production, sourcing this from
   **Custom Metadata / Custom Settings** is preferable to hardcoding.

3. **Wire the Agentforce invocation swap-point.** The controller isolates the
   agent call in a single private method, `invokeAgentforce(agentApiName,
   serializedContext)`. Implement it against your org's Agentforce enablement —
   sending the serialized deal context to your agent and returning the generated
   summary text, with a prompt instructing the agent to use only the supplied
   data, avoid invented figures, flag missing information, and produce a concise
   read on health / momentum / risks / next steps. Until wired, the method
   surfaces an explicit "not wired" error rather than a fake summary — by design.

4. **Add the component to the page.** In Lightning App Builder, open the
   **Opportunity** record page, drag **Deal Summary** (the
   `agentforceDealSummarizer` component) onto the layout, then **Save** and
   **Activate**.

---

## Security

- `with sharing` on the controller
- Every SOQL query runs `WITH USER_MODE` (enforces object-, field-, and
  record-level security for the running user)
- No credentials, org URLs, or secrets are stored in this repository; the agent
  API name is a placeholder

---

## Roadmap ideas

- Source `AGENT_API_NAME` from Custom Metadata
- Streaming / multi-turn follow-up questions on the summary
- Optional inclusion of Contracts, Quotes, or Chatter feed in the context
- A "refresh" that re-summarizes after new activity is logged

---

## License

MIT — see [LICENSE](LICENSE). © 2026 Santiago Ceron (SC Agentic Solutions).

# Agentforce Deal Summarizer — Design

**Function:** Deal review & qualification (Salesforce / Agentforce)
**Repo:** `agentforce-deal-summarizer` (public)
**Status:** 🟦 Design + code scaffold — **not deployed or tested** (no Salesforce/Agentforce org used in authoring).
**Stack:** Salesforce-native — LWC + Apex + **Agentforce**.

---

## What it does

A Lightning Web Component placed on the **Opportunity** record page collects the
deal's context — Opportunity fields plus the related Account, primary Contact,
recent activities (Tasks/Events), and products (OpportunityLineItems) — sends it
to an **Agentforce agent**, and renders an **AI deal summary** (health, momentum,
risks, recommended next steps) with a copy-to-clipboard button.

```
Open Opportunity → LWC gathers context → Apex → Agentforce → AI summary in the component
```

## Components (`force-app/main/default/`)

- **LWC `agentforceDealSummarizer`** (`.js/.html/.css/.js-meta.xml`) — target
  `lightning__RecordPage` scoped to **Opportunity**; a "Summarize Deal" button;
  loading and error states; renders the summary with a **Copy** button.
- **Apex `AgentforceDealSummaryController`** (+ test class) — `@AuraEnabled`
  entry point `summarizeDeal(Id opportunityId)`:
  - Queries the Opportunity + related records **`WITH USER_MODE`** (respects
    FLS / sharing): Opportunity (Name, StageName, Amount, CloseDate,
    Probability, NextStep, Description, ForecastCategory, Owner), Account,
    primary Contact via **OpportunityContactRole**, recent **Tasks/Events**,
    and **OpportunityLineItems**.
  - Serializes the context to JSON and invokes Agentforce via a single, isolated
    swap-point method, using `AGENT_API_NAME = 'REPLACE_WITH_YOUR_AGENT_API_NAME'`
    as a placeholder constant.
  - Returns the summary text.
- **Project config:** `sfdx-project.json`, `.forceignore`, `.gitignore`,
  `LICENSE` (MIT).

## Swap-points / placeholders (documented, not wired)

- `AGENT_API_NAME` constant → the org's actual Agentforce agent API name.
- `invokeAgentforce()` → the Agentforce invocation binding for the org.
- Agentforce enablement + a running agent (org-side).
- No credentials/secrets in the repo.

## Prerequisites (documented in README; not provisioned here)

Salesforce **Summer '25+**, **Agentforce-enabled** org, an active Agentforce
agent, **API 66.0+**, Salesforce CLI. Deploy the metadata, set `AGENT_API_NAME`,
implement the invocation swap-point, and add the LWC to the Opportunity record
page in Lightning App Builder.

## Illustrative behavior (NOT tests to run — no org)

- Open a mid-stage Opportunity → summary highlights stage, recent activity, and
  a clear next step.
- Sparse Opportunity → concise summary, no invented figures, missing data
  flagged.

*(These describe intended behavior; nothing is executed — no Salesforce/Agentforce org.)*

## Success criteria (authoring only)

- Opportunity-centric Apex context gathering + LWC targeted to the Opportunity
  record page.
- Clean, deployable-looking metadata (structural validity), business-framed
  README (what it is, architecture, prereqs, setup), clearly noting it is a
  **scaffold, not deployed/tested**.
- MIT licensed.
- **No deploy, no test.**

## Out of scope

Any Salesforce deployment, org setup, Agentforce configuration, or live run;
multi-object rollups beyond the Opportunity context above.

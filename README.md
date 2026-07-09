# Pricing Dislocation Analysis — Agentic Analytics Demo Kit

A ready-to-deploy Snowflake-native demo that proves one concept: **directors can move from manually stitching dashboard outputs to asking a governed question and receiving a fast, explainable answer.**

> **What is pricing dislocation?** For an insurance company, *dislocation* is the shift in premium that individual policyholders experience when the carrier moves from its current rating plan to a proposed one. Even a revenue-neutral rate filing rarely moves everyone equally — some insureds see increases, others decreases — so insurers analyze dislocation *before* deploying a new plan to understand who is affected, by how much, and where. It matters because large increases drive non-renewal (retention risk), regulators cap how much any single policy can swing, and impact can concentrate in a segment or geography. This demo scores that risk across a synthetic Florida property book by combining proposed rate change with lapse propensity, loss experience, and competitive position.

---

## What This Demo Does

An insurance pricing director types a natural-language question into Snowflake Intelligence:

> "Find pricing dislocation in Florida property"

In seconds, a Cortex Agent identifies the highest-risk segments, explains why they're flagged, and can generate a director-ready briefing — all governed by semantic views and RBAC.

---

## Supported Questions

The agent handles the following core business questions (and variations):

| # | Question | Skill Invoked |
|---|----------|---------------|
| 1 | Find pricing dislocation in the Florida property market. | `dislocation-score` |
| 2 | Which policy segments would see the largest premium increase under the proposed rate plan? | `dislocation-score` |
| 3 | Which segments combine high premium uplift with high lapse propensity? | `retention-risk` |
| 4 | Where are we over-indexed on profitable but retention-sensitive policyholders? | `retention-risk` |
| 5 | Summarize the top 5 dislocation risks for Florida property and generate a director briefing. | `executive-briefing` |
| 6 | Show the drivers behind the dislocation result and the variables used. | `explain-drivers` |
| 7 | What changed this month versus last month in the segments at greatest dislocation risk? | temporal comparison (dual-scenario query) |

### Additional Test Prompts

```
-- Dislocation Score
Compare dislocation risk across all states
Which segments are at highest risk under the Q3 filing?

-- Retention Risk
Show segments where lapse propensity exceeds 30% and rate change exceeds 20%
Which California WUI segments face the highest non-renewal pressure?

-- Market Hotspot Summary
Which counties are geographic dislocation hotspots?
Show geographic concentration of risk in Louisiana
Compare NorCal vs SoCal wildfire hotspots

-- Explain Drivers
Why is Louisiana showing so many critical segments?
What's driving the dislocation in the Texas hail corridor?
Break down the score for Coastal Homeowner in Santa Barbara

-- Executive Briefing
Generate a director briefing on national dislocation hotspots
Summarize dislocation risks for California wildfire zones

-- Temporal Comparison
What changed between the Q1 and Q3 rate filings?
Show segments that moved from MEDIUM to CRITICAL between filings
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  USER (Snowflake Intelligence / Snowsight)                  │
└───────────────────────┬─────────────────────────────────────┘
                        │ Natural language prompt
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  AGENT: DISLOCATION_ANALYSIS_AGENT                          │
│  • Interprets intent                                        │
│  • Routes to correct skill                                  │
│  • Formats response                                         │
├─────────────────────────────────────────────────────────────┤
│  SKILLS (5, on named stage):                                │
│  • dislocation-score       — scoring & ranking              │
│  • retention-risk          — lapse sensitivity analysis     │
│  • market-hotspot-summary  — geographic concentration       │
│  • explain-drivers         — driver decomposition           │
│  • executive-briefing      — narrative generation           │
├─────────────────────────────────────────────────────────────┤
│  SEMANTIC VIEWS:                                            │
│  • SV_DISLOCATION — primary dislocation metrics             │
│  • SV_PORTFOLIO   — portfolio context                       │
├─────────────────────────────────────────────────────────────┤
│  ADAPTER VIEWS (stable contract layer):                     │
│  • VW_DISLOCATION_ANALYSIS                                  │
│  • VW_PORTFOLIO_SUMMARY                                     │
├─────────────────────────────────────────────────────────────┤
│  TABLES (synthetic demo data):                              │
│  • DIM_GEOGRAPHY, DIM_SEGMENT, DIM_POLICY, DIM_PERIL       │
│  • FACT_PREMIUM_HISTORY, FACT_RATE_SCENARIO                 │
│  • FACT_CLAIMS, FACT_RETENTION                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Multi-State Coverage

The demo covers a **multi-state property portfolio** across four states with distinct peril profiles:

| State | Key Perils | Dislocation Driver |
|-------|-----------|-------------------|
| FL (Florida) | Hurricane/flood, coastal concentration | High rate increases on coastal segments |
| TX (Texas) | Hail corridor, hurricane (Gulf Coast), tornado | Roof replacement costs, active shopping market |
| LA (Louisiana) | Extreme CAT, market distress, carrier exits | Market-structure problem — nowhere to go |
| CA (California) | Wildfire WUI zones, FAIR Plan growth | Non-renewal pressure, not just pricing |

---

## Prerequisites

- Snowflake account with **ACCOUNTADMIN** access (or equivalent privileges)
- Cross-region inference enabled:
  ```sql
  ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
  ```
- One of:
  - **Snow CLI** (`pip install snowflake-cli`) — recommended
  - **SnowSQL** (legacy CLI)
  - **Snowsight SQL worksheet** (manual execution)

---

## Deployment

### Option A: Automated (recommended)

```bash
# Set your connection (optional — uses default if not set)
export SNOW_CONNECTION="my_connection_name"

# Run the deployment script
./deploy.sh
```

The script will:
1. Run `install.sql` — creates database, tables, views, semantic views, agent, and roles
2. Upload all 5 skill files to `@DISLOCATION_DEMO.SKILLS.SKILL_STAGE`
3. Run verification queries to confirm everything works

### Option B: Cortex Code (CoCo)

Paste `FUNCTIONAL_REQUIREMENTS.md` into a CoCo session and tell it:

```
Using the attached functional requirements document, build a complete Snowflake-native
dislocation analysis demo in my connected Snowflake account. Use install.sql as the
reference implementation. Upload all 5 skills from the skills/ directory to the stage.
```

### Option C: Manual

1. **Run install.sql** in a Snowsight worksheet (ACCOUNTADMIN role)
2. **Upload skills** via PUT commands:
   ```sql
   PUT file:///path/to/skills/dislocation-score/SKILL.md
       @DISLOCATION_DEMO.SKILLS.SKILL_STAGE/skills/dislocation-score/
       AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

   PUT file:///path/to/skills/retention-risk/SKILL.md
       @DISLOCATION_DEMO.SKILLS.SKILL_STAGE/skills/retention-risk/
       AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

   PUT file:///path/to/skills/market-hotspot-summary/SKILL.md
       @DISLOCATION_DEMO.SKILLS.SKILL_STAGE/skills/market-hotspot-summary/
       AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

   PUT file:///path/to/skills/explain-drivers/SKILL.md
       @DISLOCATION_DEMO.SKILLS.SKILL_STAGE/skills/explain-drivers/
       AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

   PUT file:///path/to/skills/executive-briefing/SKILL.md
       @DISLOCATION_DEMO.SKILLS.SKILL_STAGE/skills/executive-briefing/
       AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
   ```
3. **Verify** — see Verification section below

---

## Verification

After deployment, run these checks:

```sql
-- Check row counts
SELECT 'DIM_GEOGRAPHY' AS TBL, COUNT(*) AS ROWS FROM DISLOCATION_DEMO.CORE.DIM_GEOGRAPHY
UNION ALL SELECT 'DIM_SEGMENT', COUNT(*) FROM DISLOCATION_DEMO.CORE.DIM_SEGMENT
UNION ALL SELECT 'DIM_POLICY', COUNT(*) FROM DISLOCATION_DEMO.CORE.DIM_POLICY
UNION ALL SELECT 'FACT_PREMIUM_HISTORY', COUNT(*) FROM DISLOCATION_DEMO.CORE.FACT_PREMIUM_HISTORY
UNION ALL SELECT 'FACT_RATE_SCENARIO', COUNT(*) FROM DISLOCATION_DEMO.CORE.FACT_RATE_SCENARIO
UNION ALL SELECT 'FACT_CLAIMS', COUNT(*) FROM DISLOCATION_DEMO.CORE.FACT_CLAIMS
UNION ALL SELECT 'FACT_RETENTION', COUNT(*) FROM DISLOCATION_DEMO.CORE.FACT_RETENTION;

-- Check semantic views
SHOW SEMANTIC VIEWS IN SCHEMA DISLOCATION_DEMO.CORE;

-- Check agent
DESCRIBE AGENT DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT;

-- Check skills on stage (should return 5 files)
LS @DISLOCATION_DEMO.SKILLS.SKILL_STAGE/ PATTERN='.*SKILL\.md';

-- Quick data validation
SELECT DISLOCATION_SEVERITY, COUNT(*) AS SEGMENT_COUNT
FROM DISLOCATION_DEMO.CORE.VW_DISLOCATION_ANALYSIS
WHERE STATE = 'FL'
GROUP BY DISLOCATION_SEVERITY
ORDER BY 1;
```

Expected results:
- 85 geographies (4 states), 12 segments, ~11,000 policies
- 2 semantic views (SV_DISLOCATION, SV_PORTFOLIO)
- 1 agent (DISLOCATION_ANALYSIS_AGENT)
- 5 skill files on stage
- FL severity distribution: mix of CRITICAL, HIGH, MEDIUM, LOW

---

## Demo Script (Live Meeting)

### Opening (2 minutes)

**Talking point**: "Today's pricing and portfolio directors spend hours manually stitching insights across multiple dashboards and reports to answer one question: where does our proposed rate filing create the most business risk? We're going to show how that question gets answered in seconds with governed, explainable, conversational analytics."

### Demo Flow

#### Prompt 1: Find Dislocation (Single State)

> **Find pricing dislocation in Florida property**

**Expected**: Ranked table of FL segments with dislocation scores, severity bands, rate changes, and lapse propensity.

**Talking point**: "In under 10 seconds, the agent identified the segments with the highest dislocation risk. It used a weighted composite score that balances rate change magnitude, retention risk, loss experience, portfolio concentration, and competitive position."

#### Prompt 2: Cross-State Comparison

> **Compare dislocation risk across all states**

**Expected**: State-by-state comparison showing CRITICAL/HIGH counts, average scores, and total premium at risk.

**Talking point**: "Same analytical framework, different peril drivers. Louisiana's market distress and California's wildfire non-renewal crisis score highest, but through completely different mechanisms."

#### Prompt 3: Explain Drivers

> **Why is Louisiana showing so many critical segments?**

**Expected**: Decomposition showing LA's extreme rate needs (35-60%), high lapse propensity, and poor competitive position.

**Talking point**: "The agent explains not just WHAT is dislocated but WHY — in Louisiana's case, it's a market-structure problem where carriers are exiting and policyholders have nowhere to go."

#### Prompt 4: Retention Risk

> **Which segments combine high premium uplift with high lapse propensity?**

**Expected**: Retention-risk analysis with premium at risk calculations and state-specific context.

**Talking point**: "The agent identifies segments where pricing pressure and customer flight risk intersect — these are the segments where rate increases are most likely to cause actual policyholder loss."

#### Prompt 5: Executive Briefing

> **Summarize the top 5 dislocation risks for Florida property and generate a director briefing**

**Expected**: Formatted briefing with findings, drivers, implications, and recommended actions.

**Talking point**: "A portfolio briefing that would normally require stitching insights from multiple dashboards, assembled in seconds with full explainability."

### Closing (2 minutes)

**Architecture message**: "This sits on top of your existing Snowflake foundation. The semantic layer translates your physical data model into business-ready agent inputs. The same prompts, skills, and agent work whether the underlying data comes from a Data Vault, a curated mart, or staged extracts — we just remap the adapter views."

**Expansion message**: "This is one workflow for one line of business. The same pattern extends to claims dislocation, retention analysis, underwriting drift — any analytical workflow your pricing team repeats. Each one becomes a governed, reusable skill rather than another dashboard."

---

## Dislocation Score Methodology

```
Score = (Rate_Component × 0.35) + (Lapse_Component × 0.25) +
        (Loss_Component × 0.20) + (Concentration_Component × 0.10) +
        (Competitive_Component × 0.10)

Where:
  Rate_Component = MIN(proposed_rate_change_pct / 45, 1.0)
  Lapse_Component = lapse_propensity (already 0-1)
  Loss_Component = MIN(loss_ratio, 1.0)
  Concentration_Component = MIN(policy_count / 500, 1.0)
  Competitive_Component = MIN((1 - competitive_position_index) + 0.5, 1.0)

Severity Bands:
  CRITICAL: score >= 0.55
  HIGH:     score >= 0.40
  MEDIUM:   score >= 0.25
  LOW:      score < 0.25
```

---

## Object Inventory

| Object | Type | Schema | Purpose |
|--------|------|--------|---------|
| DISLOCATION_DEMO | Database | — | Demo container |
| CORE | Schema | — | All operational objects |
| SKILLS | Schema | — | Stage for skill files |
| DISLOCATION_DEMO_WH | Warehouse | — | Compute |
| DIM_GEOGRAPHY | Table | CORE | Geographic reference (FL, TX, LA, CA — 85 counties) |
| DIM_SEGMENT | Table | CORE | 12 insurance segments |
| DIM_POLICY | Table | CORE | ~11,000 synthetic policies across 4 states |
| DIM_PERIL | Table | CORE | 10 cause-of-loss types |
| FACT_PREMIUM_HISTORY | Table | CORE | Current premiums by policy |
| FACT_RATE_SCENARIO | Table | CORE | 2 scenarios: Q1 (prior) + Q3 (current) per state |
| FACT_CLAIMS | Table | CORE | ~11,000 claims with state-specific peril distribution |
| FACT_RETENTION | Table | CORE | Retention/lapse metrics by segment/geography |
| VW_DISLOCATION_ANALYSIS | View | CORE | Primary adapter view (scoring + drivers) |
| VW_PORTFOLIO_SUMMARY | View | CORE | Portfolio context view |
| SV_DISLOCATION | Semantic View | CORE | Agent's primary data surface |
| SV_PORTFOLIO | Semantic View | CORE | Agent's portfolio context |
| DISLOCATION_ANALYSIS_AGENT | Agent | CORE | Conversational agent with 5 skills |
| SKILL_STAGE | Stage | SKILLS | 5 skill SKILL.md files |
| DISLOCATION_DIRECTOR_RL | Role | — | Director: agent + views only |
| DISLOCATION_ANALYST_RL | Role | — | Analyst: full table + skill access |

### Skills

| Skill | Stage Path | Purpose |
|-------|-----------|---------|
| dislocation-score | @SKILL_STAGE/skills/dislocation-score/ | Score and rank segments by dislocation severity |
| retention-risk | @SKILL_STAGE/skills/retention-risk/ | Identify lapse-sensitive cohorts with large rate increases |
| market-hotspot-summary | @SKILL_STAGE/skills/market-hotspot-summary/ | Geographic concentration and outlier identification |
| explain-drivers | @SKILL_STAGE/skills/explain-drivers/ | Decompose score into weighted driver components |
| executive-briefing | @SKILL_STAGE/skills/executive-briefing/ | Format findings as director-ready narrative |

### Temporal Scenarios

| Scenario | Effective Date | Purpose |
|----------|---------------|---------|
| 2025 Q1 Rate Filing | 2025-01-01 | Prior quarter baseline (lower rates) |
| 2025 Q3 Rate Filing | 2025-07-01 | Current proposed filing (higher rates, post-CAT/reinsurance) |

---

## Customization Guide

### To adapt for a different customer:

1. **Database name**: Change `DISLOCATION_DEMO` to `{CUSTOMER}_DEMO` in install.sql
2. **Geographies**: Replace counties in DIM_GEOGRAPHY with target state/region
3. **Segments**: Adjust DIM_SEGMENT to match the customer's policy segmentation
4. **Rate scenario**: Update FACT_RATE_SCENARIO with the actual proposed changes
5. **Scoring weights**: Adjust the 5 dislocation score weights in VW_DISLOCATION_ANALYSIS
6. **Adapter views**: Remap VW_DISLOCATION_ANALYSIS to point at customer's actual source tables

### To connect to real data (production path):

Replace the adapter views to point at the customer's existing consumption layer:

```sql
CREATE OR REPLACE VIEW VW_DISLOCATION_ANALYSIS AS
SELECT ...
FROM {customer_db}.{curated_schema}.{their_existing_table}
-- Map their columns to the stable contract names
```

The semantic views, agent, and skills remain unchanged.

---

## Troubleshooting

---

## RBAC — Role-Based Access Control

The demo includes two personas with distinct access levels, demonstrating governed data access:

### Access Matrix

| Capability | DISLOCATION_DIRECTOR_RL | DISLOCATION_ANALYST_RL |
|---|:---:|:---:|
| Use the agent (Snowflake Intelligence) | Yes | Yes |
| Query adapter views (VW_DISLOCATION_ANALYSIS, VW_PORTFOLIO_SUMMARY) | Yes | Yes |
| Query claims detail (VW_CLAIMS_DETAIL) | Yes | Yes |
| See claimant/attorney names | **Masked** | Yes |
| See litigation flag, loss amounts | Yes | Yes |
| Use compute warehouse | Yes | Yes |
| Query raw tables (DIM_*, FACT_*) | **No** | Yes |
| Access SKILLS schema | **No** | Yes |
| Read skill files on stage | **No** | Yes |
| Inspect/debug agent configuration | **No** | Yes |

### Director Role (DISLOCATION_DIRECTOR_RL)

Designed for executives who consume answers without needing to see underlying data:
- Can interact with the agent via Snowflake Intelligence
- Sees results through semantic views and adapter views only
- Cannot query raw tables, inspect skill definitions, or access internal implementation

### Analyst Role (DISLOCATION_ANALYST_RL)

Designed for pricing/actuarial analysts who validate and debug:
- Full access to all raw tables for manual validation
- Can read skill files on stage to understand agent behavior
- Can inspect and validate dislocation score calculations directly

### Demo Tip: Showing Role Differences

To demonstrate RBAC during a live meeting, switch roles and show the access difference:

```sql
-- As Director: can query views
USE ROLE DISLOCATION_DIRECTOR_RL;
USE SECONDARY ROLES NONE;
USE WAREHOUSE DISLOCATION_DEMO_WH;
SELECT * FROM DISLOCATION_DEMO.CORE.VW_DISLOCATION_ANALYSIS LIMIT 5;  -- WORKS

-- As Director: cannot query raw tables
SELECT * FROM DISLOCATION_DEMO.CORE.DIM_POLICY LIMIT 5;  -- FAILS: not authorized

-- As Analyst: full access
USE ROLE DISLOCATION_ANALYST_RL;
SELECT * FROM DISLOCATION_DEMO.CORE.DIM_POLICY LIMIT 5;  -- WORKS
LS @DISLOCATION_DEMO.SKILLS.SKILL_STAGE/;                -- WORKS
```

### Assigning Roles to Users

```sql
-- Grant director access to a business user
GRANT ROLE DISLOCATION_DIRECTOR_RL TO USER director_user;

-- Grant analyst access to a pricing analyst
GRANT ROLE DISLOCATION_ANALYST_RL TO USER analyst_user;
```

---

| Issue | Fix |
|-------|-----|
| Agent returns "no data found" | Verify VW_DISLOCATION_ANALYSIS has rows: `SELECT COUNT(*) FROM DISLOCATION_DEMO.CORE.VW_DISLOCATION_ANALYSIS` |
| Semantic view errors | Check GRANT SELECT on underlying views to the role running the agent |
| Skills not discovered | Verify files on stage: `LS @DISLOCATION_DEMO.SKILLS.SKILL_STAGE/ PATTERN='.*SKILL\.md'` |
| Agent not available in Intelligence | Ensure cross-region inference is enabled and agent USAGE is granted |
| Slow responses | Check warehouse is not suspended; agent cold-start takes a few extra seconds |
| PUT command fails | Ensure you're running as ACCOUNTADMIN or have WRITE privilege on stage |

---

## Teardown

To completely remove the demo from the account:

```bash
# Via Snow CLI
snow sql -f cleanup.sql

# Or run cleanup.sql manually in Snowsight
```

This removes all databases, warehouses, and roles created by the demo.

---

## Data Governance Demo: Dynamic PII Masking via Cortex Agent

This optional extension demonstrates how Snowflake's **dynamic data masking** flows transparently through a Cortex Agent — the same question returns different results based on who's asking.

### The Story

Claims data contains sensitive PII (claimant names, attorney involvement, litigation status). In production:
- **Pricing analysts** need full claims detail to validate dislocation scores
- **Directors** should see aggregated risk metrics but NOT individual claimant identities

With Snowflake masking policies, this governance is enforced at the platform level — no application code, no agent logic changes.

### Setup

Run the RBAC extension script **after** the main install:

```sql
-- Run in Snowsight as ACCOUNTADMIN
-- File: install_rbac_demo.sql
```

This adds:
- 4 PII columns to FACT_CLAIMS (claimant name, attorney, litigation flag, loss description)
- 1 masking policy (names → REDACTED for non-analysts)
- A claims detail view (VW_CLAIMS_DETAIL) with policy applied
- A semantic view (SV_CLAIMS_DETAIL) for agent consumption
- The agent updated with a Claims_Detail tool

### Demo: Same Question, Different Answers

**As Analyst** — ask the agent:
> "Show claims in Florida with claimant details"

Result: Full names, attorney firms, litigation flags visible.

| CLAIMANT_NAME | ATTORNEY_NAME | LITIGATION_FLAG | INCURRED_LOSS |
|---|---|---|---|
| Nancy Clark | Fasig \| Brooks | TRUE | $274,618 |
| Kenneth Carter | — | FALSE | $272,997 |

**As Director** — same question:

| CLAIMANT_NAME | ATTORNEY_NAME | LITIGATION_FLAG | INCURRED_LOSS |
|---|---|---|---|
| ●●●● REDACTED ●●●● | ●●●● REDACTED ●●●● | TRUE | $274,618 |
| ●●●● REDACTED ●●●● | ●●●● REDACTED ●●●● | FALSE | $272,997 |

Same rows, same order — only the name columns are masked.

### Testing the Masking (SQL Worksheet)

```sql
-- Full PII visible
USE ROLE DISLOCATION_ANALYST_RL;
USE SECONDARY ROLES NONE;
USE WAREHOUSE DISLOCATION_DEMO_WH;
SELECT CLAIMANT_NAME, ATTORNEY_NAME, LITIGATION_FLAG, INCURRED_LOSS
FROM DISLOCATION_DEMO.CORE.VW_CLAIMS_DETAIL
WHERE STATE = 'FL'
ORDER BY INCURRED_LOSS DESC LIMIT 5;

-- PII masked (same rows, same order)
USE ROLE DISLOCATION_DIRECTOR_RL;
USE SECONDARY ROLES NONE;
USE WAREHOUSE DISLOCATION_DEMO_WH;
SELECT CLAIMANT_NAME, ATTORNEY_NAME, LITIGATION_FLAG, INCURRED_LOSS
FROM DISLOCATION_DEMO.CORE.VW_CLAIMS_DETAIL
WHERE STATE = 'FL'
ORDER BY INCURRED_LOSS DESC LIMIT 5;
```

### Talking Points

- "The masking happens at the Snowflake platform layer — the agent has zero awareness of it"
- "This is the same governance that protects your data in dashboards, APIs, and direct SQL"
- "No additional application security code needed — role-based masking applies everywhere"
- "The analyst sees full detail for claims validation; the director sees the financial exposure without PII"

### Rollback

To remove the RBAC extension without affecting the core demo, uncomment and run the cleanup section at the bottom of `install_rbac_demo.sql`.

---

## File Inventory

```
dislocation-demo-kit/
├── README.md                      ← This file
├── FUNCTIONAL_REQUIREMENTS.md     ← Full requirements spec (customer-safe)
├── install.sql                    ← Idempotent install script (all objects + data)
├── install_rbac_demo.sql          ← Optional: PII masking + claims detail (run after install.sql)
├── cleanup.sql                    ← Complete teardown script
├── deploy.sh                      ← Automated deployment (install + upload + verify)
└── skills/
    ├── dislocation-score/
    │   └── SKILL.md               ← Scoring & segment ranking
    ├── retention-risk/
    │   └── SKILL.md               ← Lapse sensitivity analysis
    ├── market-hotspot-summary/
    │   └── SKILL.md               ← Geographic concentration
    ├── explain-drivers/
    │   └── SKILL.md               ← Driver decomposition
    └── executive-briefing/
        └── SKILL.md               ← Director-ready narrative generation
```

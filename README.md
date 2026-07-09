# Pricing Dislocation — Coco CLI Hands-On Lab

A command-line hands-on lab that you run end-to-end from **Coco CLI** and the **Snowflake CLI**. You deploy a governed, agentic analytics workload into your own Snowflake account, then ask a natural-language question and get a fast, explainable answer — without ever opening Snowsight.

> **What is pricing dislocation?** For an insurance company, *dislocation* is the shift in premium that individual policyholders experience when the carrier moves from its current rating plan to a proposed one. Even a revenue-neutral rate filing rarely moves everyone equally — some insureds see increases, others decreases — so insurers analyze dislocation *before* deploying a new plan to understand who is affected, by how much, and where. It matters because large increases drive non-renewal (retention risk), regulators cap how much any single policy can swing, and impact can concentrate in a segment or geography. This lab scores that risk across a synthetic multi-state property book by combining proposed rate change with lapse propensity, loss experience, and competitive position.

---

## What you'll do

By the end of this lab you will have, entirely from the CLI:

1. Deployed a full agentic-analytics stack (tables, seed data, adapter views, semantic views, a Cortex Agent, 5 agent skills, and RBAC roles) with one script.
2. Asked the deployed **Cortex Agent** business questions using `cortex agents run`.
3. Queried the **semantic views** directly with `cortex analyst query`.
4. Demonstrated **governed access** by switching roles, and (optionally) **dynamic PII masking** where the same question returns different results by role.
5. (Optional capstone) Opened the same agent in **Snowflake Cowork** — the only step in the lab that uses Snowsight.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  YOU  (Coco CLI / Snowflake CLI)                         │
│    • cortex agents run   → ask the agent (Snowflake Cowork mode) │
│    • cortex analyst query → query semantic views             │
│    • setup.sh / teardown.sh → deploy & remove                │
└───────────────────────┬─────────────────────────────────────┘
                        │ natural language
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  AGENT: DISLOCATION_ANALYSIS_AGENT                          │
│  • Interprets intent → routes to a skill → formats response  │
├─────────────────────────────────────────────────────────────┤
│  SKILLS (5, on a named stage — loaded by the agent server-side):
│  • dislocation-score  • retention-risk  • market-hotspot-summary
│  • explain-drivers    • executive-briefing                   │
├─────────────────────────────────────────────────────────────┤
│  SEMANTIC VIEWS: SV_DISLOCATION · SV_PORTFOLIO · SV_CLAIMS_DETAIL
├─────────────────────────────────────────────────────────────┤
│  ADAPTER VIEWS: VW_DISLOCATION_ANALYSIS · VW_PORTFOLIO_SUMMARY · VW_CLAIMS_DETAIL
├─────────────────────────────────────────────────────────────┤
│  TABLES: DIM_GEOGRAPHY · DIM_SEGMENT · DIM_POLICY · DIM_PERIL │
│          FACT_PREMIUM_HISTORY · FACT_RATE_SCENARIO · FACT_CLAIMS · FACT_RETENTION
└─────────────────────────────────────────────────────────────┘
```

> **Why are the 5 skills uploaded to a stage?** These are **Cortex Agent skills**, not local Coco skills. The agent runs *inside* Snowflake, so it loads each `SKILL.md` server-side from the named stage referenced in `sql/005-agent.sql`. `setup.sh` uploads them there. (The separate, optional `install-skill.sh` installs a *local* Coco companion skill on your laptop — a different thing.)

---

## Prerequisites

- [**Snowflake CLI**](https://docs.snowflake.com/en/developer-guide/snowflake-cli) (`snow`) configured with a connection (key-pair auth recommended). This is the only thing you must set up in advance — no Snowsight.
- [**Coco CLI**](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code) (`cortex`) — used to ask the agent and query semantic views.
- **Python 3** — used by `setup.sh` / `snowclisp` to run the numbered SQL files.
- A role with privileges to create a database, warehouse, roles, and a Cortex Agent (e.g. `ACCOUNTADMIN`).
- Cross-region inference enabled for the agent's models:
  ```bash
  snow sql -c <your_connection> -q "ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';"
  ```

---

## Repository layout

```
coco-dislocation-hol/
├── README.md                       ← this file
├── FUNCTIONAL_REQUIREMENTS.md      ← product/requirements spec (background)
├── setup.sh                        ← one-command deploy (SQL files + skill upload + verify)
├── teardown.sh                     ← remove everything the lab created
├── install-skill.sh                ← (optional) install the local Coco companion skill
├── .env/
│   └── dislocation.env.template    ← deploy config template (copy to dislocation.env)
├── sql/
│   ├── snowflake.yml               ← ctx.env definitions for `snow sql` templating
│   ├── 001-ddl.sql                 ← database, schemas, warehouse, stage, tables
│   ├── 002-dml.sql                 ← synthetic seed data
│   ├── 003-views.sql               ← adapter views + claims-detail view (PII columns)
│   ├── 004-semantic_views.sql      ← SV_DISLOCATION, SV_PORTFOLIO, SV_CLAIMS_DETAIL
│   ├── 005-agent.sql               ← Cortex Agent (skills + Claims_Detail tool)
│   ├── 006-rbac.sql                ← Director / Analyst roles + grants
│   └── optional-pii_masking.sql    ← OPTIONAL governance module (no numeric prefix → not auto-run)
├── skills/                         ← 5 Cortex Agent skills (uploaded to the stage by setup.sh)
│   ├── dislocation-score/SKILL.md
│   ├── retention-risk/SKILL.md
│   ├── market-hotspot-summary/SKILL.md
│   ├── explain-drivers/SKILL.md
│   └── executive-briefing/SKILL.md
├── coco-skill/dislocation-lab/SKILL.md   ← local Coco companion skill (installed by install-skill.sh)
└── pyutil/snowclisp/snowclisp.py         ← runs the numbered SQL files in order via `snow sql`
```

All object names (database, schema, warehouse, stage) are parameterized via `<% ctx.env.X %>` and resolved from your `.env` at deploy time — the same files deploy to any database/schema with no SQL editing.

---

## Module 0 — Configure & deploy

```bash
# 1. Create your config from the template and fill in your values
cp .env/dislocation.env.template .env/dislocation.env
#    set CLI_CONNECTION_NAME (required); optionally change ROLE / WAREHOUSE /
#    DATABASE / SCHEMA / SKILLS_SCHEMA / STAGE

# 2. Deploy everything
./setup.sh
```

`setup.sh` sources your `.env`, runs `sql/001..006` in numeric order via `snowclisp` (which calls `snow sql`), uploads the 5 agent skills to `@<DATABASE>.<SKILLS_SCHEMA>.<STAGE>`, then verifies row counts, semantic views, skills on the stage, and the Florida severity distribution. It finishes by printing the exact `cortex agents run` command for your database/schema.

**Expected:** 85 geographies (4 states), 12 segments, ~11,000 policies; 3 semantic views; 1 agent; 5 skill files on the stage; a mix of CRITICAL/HIGH/MEDIUM/LOW for Florida.

---

## Module 1 — Ask the agent

The deployed agent is reachable from the CLI in "Snowflake Cowork mode". Using the defaults, its fully-qualified name is `DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT`.

```bash
cortex agents run DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT \
  "Find pricing dislocation in Florida property"
```

The agent handles these core questions (each routes to a skill):

| # | Question | Skill invoked |
|---|----------|---------------|
| 1 | Find pricing dislocation in the Florida property market. | `dislocation-score` |
| 2 | Which policy segments would see the largest premium increase under the proposed rate plan? | `dislocation-score` |
| 3 | Which segments combine high premium uplift with high lapse propensity? | `retention-risk` |
| 4 | Where are we over-indexed on profitable but retention-sensitive policyholders? | `retention-risk` |
| 5 | Summarize the top 5 dislocation risks for Florida property and generate a director briefing. | `executive-briefing` |
| 6 | Show the drivers behind the dislocation result and the variables used. | `explain-drivers` |
| 7 | What changed this month versus last month in the segments at greatest dislocation risk? | temporal comparison |

More prompts to try:

```
cortex agents run DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT "Compare dislocation risk across all states"
cortex agents run DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT "Why is Louisiana showing so many critical segments?"
cortex agents run DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT "Which counties are geographic dislocation hotspots?"
cortex agents run DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT "Generate a director briefing on national dislocation hotspots"
```

You can inspect the agent's configuration any time:

```bash
cortex agents describe DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT
```

---

## Module 2 — Query the semantic views directly

Skip the agent and hit the governed semantic layer with Cortex Analyst:

```bash
cortex analyst query "Which segments have the highest dislocation score in Florida?" \
  --view DISLOCATION_DEMO.CORE.SV_DISLOCATION

cortex analyst query "What is total premium and policy count by state?" \
  --view DISLOCATION_DEMO.CORE.SV_PORTFOLIO
```

This is the same semantic layer the agent uses — business logic lives in Snowflake, not in the client.

---

## Module 3 — Multi-state exploration

The book spans four states with distinct peril profiles. Ask the agent to compare them and explain the drivers.

| State | Key perils | Dislocation driver |
|-------|-----------|--------------------|
| FL | Hurricane/flood, coastal concentration | High rate increases on coastal segments |
| TX | Hail corridor, Gulf hurricane, tornado | Roof replacement costs, active shopping market |
| LA | Extreme CAT, carrier exits | Market-structure problem — nowhere to go |
| CA | Wildfire WUI zones, FAIR Plan growth | Non-renewal pressure, not just pricing |

```bash
cortex agents run DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT "Compare dislocation risk across all states"
cortex agents run DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT "What's driving the dislocation in the Texas hail corridor?"
cortex agents run DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT "Summarize dislocation risks for California wildfire zones"
```

---

## Module 4 — Governed access (RBAC)

The lab creates two personas:

| Capability | `DISLOCATION_DIRECTOR_RL` | `DISLOCATION_ANALYST_RL` |
|---|:---:|:---:|
| Use the agent | Yes | Yes |
| Query adapter/semantic views | Yes | Yes |
| Query raw tables (`DIM_*`, `FACT_*`) | **No** | Yes |
| Read skill files on the stage | **No** | Yes |

Demonstrate the difference from the CLI:

```bash
# Director: views work, raw tables do not
snow sql -c <your_connection> -q "
USE ROLE DISLOCATION_DIRECTOR_RL; USE SECONDARY ROLES NONE; USE WAREHOUSE DISLOCATION_DEMO_WH;
SELECT * FROM DISLOCATION_DEMO.CORE.VW_DISLOCATION_ANALYSIS LIMIT 5;"   # works

snow sql -c <your_connection> -q "
USE ROLE DISLOCATION_DIRECTOR_RL; USE SECONDARY ROLES NONE;
SELECT * FROM DISLOCATION_DEMO.CORE.DIM_POLICY LIMIT 5;"                # fails: not authorized

# Analyst: full access
snow sql -c <your_connection> -q "
USE ROLE DISLOCATION_ANALYST_RL; USE WAREHOUSE DISLOCATION_DEMO_WH;
SELECT * FROM DISLOCATION_DEMO.CORE.DIM_POLICY LIMIT 5;"                # works
```

Assign the personas to real users:

```bash
snow sql -c <your_connection> -q "GRANT ROLE DISLOCATION_DIRECTOR_RL TO USER director_user;"
snow sql -c <your_connection> -q "GRANT ROLE DISLOCATION_ANALYST_RL TO USER analyst_user;"
```

---

## Module 5 (optional) — Dynamic PII masking

This adds a masking policy on claimant/attorney names so the **same question returns different results by role** — governance enforced at the platform layer, transparent to the agent.

```bash
# Apply the masking module (not run by setup.sh)
snow sql -c <your_connection> -f sql/optional-pii_masking.sql
```

Test it:

```bash
# Analyst → full names
snow sql -c <your_connection> -q "
USE ROLE DISLOCATION_ANALYST_RL; USE SECONDARY ROLES NONE; USE WAREHOUSE DISLOCATION_DEMO_WH;
SELECT CLAIMANT_NAME, ATTORNEY_NAME, LITIGATION_FLAG, INCURRED_LOSS
FROM DISLOCATION_DEMO.CORE.VW_CLAIMS_DETAIL WHERE STATE='FL' ORDER BY INCURRED_LOSS DESC LIMIT 5;"

# Director → ●●●● REDACTED ●●●● (same rows, same order, financials still visible)
snow sql -c <your_connection> -q "
USE ROLE DISLOCATION_DIRECTOR_RL; USE SECONDARY ROLES NONE; USE WAREHOUSE DISLOCATION_DEMO_WH;
SELECT CLAIMANT_NAME, ATTORNEY_NAME, LITIGATION_FLAG, INCURRED_LOSS
FROM DISLOCATION_DEMO.CORE.VW_CLAIMS_DETAIL WHERE STATE='FL' ORDER BY INCURRED_LOSS DESC LIMIT 5;"
```

Ask the agent the same claims question under each role and observe the masked vs. full names in the response.

---

## Optional capstone — Snowflake Cowork

Everything above is CLI-only. If you want to see the same agent in a chat UI, open **Snowflake Cowork**, select `DISLOCATION_ANALYSIS_AGENT`, and ask *"Find pricing dislocation in Florida property."* This is the **only** step in the lab that uses Snowsight, and it's entirely optional — the agent you built from the CLI is the same one.

---

## Dislocation score methodology

```
Score = (Rate_Component × 0.35) + (Lapse_Component × 0.25) +
        (Loss_Component × 0.20) + (Concentration_Component × 0.10) +
        (Competitive_Component × 0.10)

  Rate_Component          = MIN(proposed_rate_change_pct / 45, 1.0)
  Lapse_Component         = lapse_propensity (0–1)
  Loss_Component          = MIN(loss_ratio, 1.0)
  Concentration_Component = MIN(policy_count / 500, 1.0)
  Competitive_Component   = MIN((1 - competitive_position_index) + 0.5, 1.0)

Severity: CRITICAL ≥ 0.55 · HIGH ≥ 0.40 · MEDIUM ≥ 0.25 · LOW < 0.25
```

---

## Object inventory

| Object | Type | Purpose |
|--------|------|---------|
| `<DATABASE>` | Database | Lab container (default `DISLOCATION_DEMO`) |
| `<SCHEMA>` (`CORE`) | Schema | All operational objects |
| `<SKILLS_SCHEMA>` (`SKILLS`) | Schema | Named stage for agent skill files |
| `<WAREHOUSE>` | Warehouse | Compute (XSMALL, auto-suspend) |
| `DIM_GEOGRAPHY / DIM_SEGMENT / DIM_POLICY / DIM_PERIL` | Tables | Reference dimensions |
| `FACT_PREMIUM_HISTORY / FACT_RATE_SCENARIO / FACT_CLAIMS / FACT_RETENTION` | Tables | Facts |
| `VW_DISLOCATION_ANALYSIS / VW_PORTFOLIO_SUMMARY / VW_CLAIMS_DETAIL` | Views | Stable adapter (contract) layer |
| `SV_DISLOCATION / SV_PORTFOLIO / SV_CLAIMS_DETAIL` | Semantic Views | The agent's governed data surfaces |
| `DISLOCATION_ANALYSIS_AGENT` | Agent | Conversational agent with 5 skills |
| `SKILL_STAGE` | Stage | 5 skill `SKILL.md` files |
| `DISLOCATION_DIRECTOR_RL / DISLOCATION_ANALYST_RL` | Roles | Governed personas |

---

## Customization

- **Different account layout:** change `DATABASE` / `SCHEMA` / `WAREHOUSE` / `STAGE` in `.env/dislocation.env` — no SQL editing needed.
- **Different data:** edit the seed inserts in `sql/002-dml.sql` (geographies, segments, rate scenarios).
- **Different scoring:** adjust the weighted components in `sql/003-views.sql` (`VW_DISLOCATION_ANALYSIS`).
- **Connect to real data:** repoint the adapter views in `sql/003-views.sql` at your existing consumption layer; the semantic views, agent, and skills stay unchanged.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `snow: command not found` | Install the Snowflake CLI: `pip install snowflake-cli` |
| Agent returns "no data found" | Verify rows: `snow sql -c <conn> -q "SELECT COUNT(*) FROM DISLOCATION_DEMO.CORE.VW_DISLOCATION_ANALYSIS;"` |
| Skills not discovered | Confirm files on stage: `snow sql -c <conn> -q "LS @DISLOCATION_DEMO.SKILLS.SKILL_STAGE/ PATTERN='.*SKILL\.md';"` |
| Agent errors on model | Ensure cross-region inference is enabled (see Prerequisites) |
| `cortex agents run` can't find the agent | Confirm the FQN matches your `.env` (`<DATABASE>.<SCHEMA>.DISLOCATION_ANALYSIS_AGENT`) and that USAGE is granted |
| Template values not substituted | Ensure `setup.sh` runs from the repo root so `snow` discovers `sql/snowflake.yml` |

---

## Teardown

```bash
./teardown.sh
```

Removes the database (all schemas, tables, views, stages), the warehouse, and both lab roles, using the same `.env` configuration.

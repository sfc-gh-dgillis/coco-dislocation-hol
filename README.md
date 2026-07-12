# Pricing Dislocation — Coco CLI Hands-On Lab

A command-line hands-on lab for **Coco** (Coco CLI / Coco Desktop). You stand up a governed, agentic pricing-dislocation workload in your own Snowflake account, then explore it, extend it, and govern it — all from Coco. Business users can consume the finished agent in **Snowflake Cowork**, but that UI step is optional; the entire lab runs from the terminal.

> **First time?** See the [Setup & Reference appendix](#appendix-setup--reference) for one-time configuration.
>
> **Returning to run it again?** Open Coco in the project directory and tell it to *"reset the lab"*. The `dislocation-lab` skill handles the rest.

> **What is pricing dislocation?** For an insurer, *dislocation* is the shift in premium that individual policyholders experience when the carrier moves from its current rating plan to a proposed one. Even a revenue-neutral filing rarely moves everyone equally, so insurers analyze dislocation *before* deploying a new plan — large increases drive non-renewal, regulators cap per-policy swings, and impact can concentrate in a segment or geography. This lab scores that risk across a synthetic multi-state property book by combining proposed rate change with lapse propensity, loss experience, and competitive position.

---

## Coco CLI Lab Script

**Scenario:** You're standing up an agentic dislocation-analysis workload for a P&C insurer. You'll deploy it, interrogate the data and the governed semantic layer, ask a deployed agent business questions, extend the model, and prove governance — all from Coco.

**Repo:** `coco-dislocation-hol` (synthetic FL/TX/LA/CA property book)

**Total time:** ~12–15 minutes

---

## Pre-Lab Checklist

Run through this before each walkthrough to ensure a clean starting state.

1. **Open Coco** in the `coco-dislocation-hol` project root.
2. **Reset to a clean state** — tell Coco *"reset the lab and switch to main"*. The `dislocation-lab` skill switches to `main` and (with your confirmation) tears down any prior Snowflake objects so the deploy step is a live moment.
3. **Verify your connection** — ask Coco to *"verify my Snowflake connection"* (it runs `cortex connections list` / `snow sql` for you).
4. **Browser tab (optional)** — open Snowflake Cowork if you plan to show the capstone.

> **Important:** Don't run `./setup.sh` before the walkthrough — Act 1 deploys live as a demo moment.

---

## Lab Overview

You go from an empty account to a governed, agentic dislocation workload you can question in natural language — all from Coco in ~15 minutes.

**Data domain:** a synthetic multi-state property insurance book (FL, TX, LA, CA) — ~11,000 policies, 12 segments, 85 counties, two rate-filing scenarios.

**The arc follows five acts:**

- **Act 1 — Orientation & Deploy (~3 min):** pick a model (`/model`), explore the repo with `@` file mentions, deploy the whole stack via the `dislocation-lab` skill, cut a dev branch (native git).
- **Act 2 — Explore the data & governed layer (~3 min):** `$data-quality` on the seeded tables, `#` table mentions to inspect raw data and the scoring view, `$lineage` to trace the semantic view back to sources.
- **Act 3 — Ask the agent (~3 min):** `cortex agents run` against the deployed agent (Snowflake Cowork mode) and `cortex analyst query` against the semantic views.
- **Act 4 — Extend & iterate (~3 min):** `/fork` a checkpoint, build the wrong thing, `/rewind` + clean up, rebuild correctly using an `@` style reference, `/compact` the session.
- **Act 5 — Governance & git (~2 min):** RBAC role switch, optional dynamic PII masking, commit with an auto-generated message.
- **Capstone (optional):** open the same agent in Snowflake Cowork.

**Capabilities demonstrated:** built-in and custom skills (`$data-quality`, `$lineage`, `$trust-center`, `dislocation-lab`), `@` file mentions and `#` table mentions for context injection, direct SQL execution, `cortex agents run` / `cortex analyst query`, native git, session management (`/model`, `/fork`, `/rewind`, `/compact`), and iterative problem-solving.

---

## Act 1 — Orientation & Deploy (~3 min)

> **Story:** "Here's a repo that claims to deploy an agentic dislocation workload. Let's understand it, then stand it up."

### Prompt 1 — Choose a model

Coco supports multiple LLM models. Switch anytime with `/model`, or launch with `cortex --model <id>`.

```
/model claude-opus-4-8
```

**Expected:** Coco switches models. Good moment to talk through tradeoffs — start with `auto` (Coco picks the best available), use Opus for complex reasoning, Sonnet for fast iteration. Models require regional availability; enable [cross-region inference](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions#cross-region-inference) (`CORTEX_ENABLED_CROSS_REGION`, ACCOUNTADMIN) if a model isn't in your region.

### Prompt 2 — Explore the project

```
@AGENTS.md @sql/005-agent.sql What does this lab deploy, and how does the agent get its skills?
```

**Expected:** The `@` prefix injects each file's contents directly into the prompt — no copy-paste. Coco summarizes the stack (tables → adapter views → semantic views → agent + 5 skills → RBAC) and explains that the agent loads its skills server-side from a named stage.

> **Aside — skills.** Coco ships with **built-in skills** (data-quality, lineage, trust-center, and more) and supports **custom skills**. This repo includes a project skill at `.cortex/skills/dislocation-lab/SKILL.md` that knows how to deploy, verify, reset, and drive this lab. Invoke a skill explicitly with `$` (e.g. `$data-quality`), or let Coco auto-activate it. Run `/skill list` to see them all.

### Prompt 3 — Deploy the lab

```
Set up the dislocation lab in my Snowflake account.
```

**Expected:** The `dislocation-lab` skill activates and runs the deploy: it ensures `.env/dislocation.env` exists (copying the template if needed), then runs `./setup.sh`, which executes `sql/001..006` in order via `snowclisp`, uploads the 5 agent skills to the stage, and verifies row counts, semantic views, skills-on-stage, and the Florida severity distribution. No commands to memorize.

> If you'd rather run it yourself: `cp .env/dislocation.env.template .env/dislocation.env` (set `CLI_CONNECTION_NAME`), then `./setup.sh`.

### Prompt 4 — Cut a dev branch

```
Create a branch called dislocation-lab-dev and switch to it.
```

**Expected:** Coco runs `git checkout -b dislocation-lab-dev` natively — no leaving the CLI. Reinforces that Coco is a full dev environment with built-in git.

---

## Act 2 — Explore the data & governed layer (~3 min)

> **Story:** "Before we trust the scores, let's check the data and see how the logic is layered."

### Prompt 5 — Data quality scan

```
$data-quality Run a quick quality scan on the lab's dimension and fact tables in DISLOCATION_DEMO.CORE — null rates on key columns, row counts, and anything that looks off. Give me a plain-English summary.
```

**Expected:** The data-quality skill identifies the tables, runs targeted null/row-count/anomaly checks, and returns a plain-English health summary — no hand-written SQL.

### Prompt 6 — Inspect the raw data

```
#DISLOCATION_DEMO.CORE.DIM_POLICY What does the policy data look like, and how many policies exist per state?
```

**Expected:** The `#` prefix auto-injects the table's column schema and a sample of rows, so Coco sees exact columns without a `DESCRIBE`. It describes the table and runs a per-state count against Snowflake.

> **Aside — `#` table mentions.** `#DB.SCHEMA.TABLE` injects a table's schema and sample rows into the prompt. Mention several tables in one prompt to give Coco join context. You'll use this again in Acts 3–4.

### Prompt 7 — Trace lineage

```
$lineage Trace the lineage of DISLOCATION_DEMO.CORE.SV_DISLOCATION back to its source tables.
```

**Expected:** The lineage skill maps `SV_DISLOCATION → VW_DISLOCATION_ANALYSIS → FACT_*/DIM_*`, showing how the semantic view the agent uses is built from the adapter view over the base tables.

### Prompt 8 — Understand the scoring view

```
#DISLOCATION_DEMO.CORE.VW_DISLOCATION_ANALYSIS Explain how the dislocation score is calculated and what the severity bands mean.
```

**Expected:** With the view's columns injected, Coco explains the weighted composite (rate change, lapse, loss ratio, concentration, competitive position) and the CRITICAL/HIGH/MEDIUM/LOW bands.

---

## Act 3 — Ask the agent (Snowflake Cowork mode) (~3 min)

> **Story:** "Now the payoff — a governed agent that answers pricing questions in plain English."

The deployed agent is `DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT`. Reach it from the CLI with `cortex agents run` (tip: prefix a command with `!` inside a Coco session to run it in-line, or use a second terminal).

### Prompt 9 — Find dislocation

```
cortex agents run DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT "Find pricing dislocation in Florida property"
```

**Expected:** A ranked table of FL segments with scores, severity bands, rate changes, and lapse propensity — plus drivers and implications. The agent routed to the `dislocation-score` skill.

### Prompt 10 — Compare states & explain drivers

```
cortex agents run DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT "Compare dislocation risk across all states"
cortex agents run DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT "Why is Louisiana showing so many critical segments?"
```

**Expected:** A state-by-state comparison, then a driver decomposition — same framework, different peril mechanisms per state.

### Prompt 11 — Query the semantic view directly

```
cortex analyst query "Which segments combine the highest rate increase with the highest lapse propensity in Florida?" --view DISLOCATION_DEMO.CORE.SV_DISLOCATION
```

**Expected:** Cortex Analyst answers straight off the governed semantic layer — the same logic the agent uses, no agent hop.

---

## Act 4 — Extend & iterate (~3 min)

> **Story:** "Let's add a derived metric — and show what happens when it goes sideways."

### Prompt 12 — Fork a checkpoint

```
/fork before-new-view
```

**Expected:** Coco branches the *session* (like `git branch` for your conversation). If the next steps go wrong, you can return to this exact state.

### Prompt 13 — Build the wrong thing (intentional)

```
Create a view called premiumatrisk that sums premium delta by county. Just make it quickly.
```

**Expected:** Coco builds it — but it breaks conventions (no `VW_` prefix, unqualified, not templated). We're about to undo it.

### Prompt 14 — Rewind and clean up

```
/rewind 1
```

Then:

```
Delete anything that "premiumatrisk" prompt created — drop the view in Snowflake and remove any file.
```

**Expected:** `/rewind` rolls back the *conversation*; the follow-up cleans the *side effects* (dropped view, removed file). Note the distinction: `/rewind` is destructive to conversation only — files/tables/commits need explicit cleanup.

### Prompt 15 — Rebuild correctly

```
@sql/003-views.sql Create a new adapter view VW_PREMIUM_AT_RISK that totals PREMIUM_DELTA and policy count by STATE and COUNTY for the current scenario. Follow the conventions in this file — env templating, naming, and SQL style. Then compile it.
```

**Expected:** With the real file as a style reference, Coco writes a `<% ctx.env.X %>`-templated `VW_PREMIUM_AT_RISK` that matches the existing naming and formatting, then compiles it.

### Prompt 16 — Compact the session

```
/compact
```

**Expected:** Coco condenses the conversation history, preserving state (branch, what was built) while freeing context. Use it proactively during long sessions.

---

## Act 5 — Governance & git (~2 min)

> **Story:** "Prove the access controls, then commit."

### Prompt 17 — Show RBAC differences

```
Using my connection, show that DISLOCATION_DIRECTOR_RL can query VW_DISLOCATION_ANALYSIS but not DIM_POLICY, and that DISLOCATION_ANALYST_RL can query both.
```

**Expected:** Coco runs the role-scoped queries (`USE ROLE …; USE SECONDARY ROLES NONE; …`) and shows the Director blocked on raw tables while the Analyst has full access — governance enforced by Snowflake, not app code.

### Prompt 18 (optional) — Dynamic PII masking

```
Apply the optional PII masking module, then show the same Florida claims query as the Analyst vs the Director role.
```

**Expected:** Coco runs `sql/optional-pii_masking.sql`, then the same query returns full claimant/attorney names for the Analyst and `●●●● REDACTED ●●●●` for the Director — same rows, same financials, names masked at the platform layer.

### Prompt 19 — Commit

```
Commit all changes with an appropriate message.
```

**Expected:** Coco stages the new/modified files and writes a well-formed commit message summarizing the work.

---

## Capstone (optional) — Snowflake Cowork

Everything above is CLI-only. To see the same agent in a chat UI, open **Snowflake Cowork**, select `DISLOCATION_ANALYSIS_AGENT`, and ask *"Find pricing dislocation in Florida property."* This is the **only** step that touches the Snowsight UI, and it's entirely optional — it's the same agent you built from the CLI.

---

## Closing talking points

1. **From zero to governed agent in ~15 minutes**, all from the terminal.
2. **Skills do the heavy lifting** — `$data-quality`, `$lineage`, and the custom `dislocation-lab` skill turn intent into the right commands.
3. **`@` and `#` context injection** — files and Snowflake tables piped straight into the prompt, so Coco writes accurate SQL and views without guessing.
4. **Snowflake-native** — direct SQL, `cortex agents run`, and `cortex analyst query` with no extra config.
5. **Full lifecycle** — explore → deploy → question → extend → govern → commit, without leaving Coco.
6. **Governed by construction** — semantic views centralize the logic; RBAC and masking are enforced by the platform.

---

## Troubleshooting / backup plans

| If this happens… | Do this… |
|---|---|
| `snow: command not found` | Install the Snowflake CLI: `pip install snowflake-cli` |
| Deploy fails partway | Re-run `./setup.sh` (SQL is idempotent) or ask Coco to diagnose the failing file |
| Agent returns "no data found" | `snow sql -c <conn> -q "SELECT COUNT(*) FROM DISLOCATION_DEMO.CORE.VW_DISLOCATION_ANALYSIS;"` |
| Skills not discovered | `snow sql -c <conn> -q "LS @DISLOCATION_DEMO.SKILLS.SKILL_STAGE/ PATTERN='.*SKILL\.md';"` |
| Agent errors on model | Enable cross-region inference (see appendix Prerequisites) |
| Template values not substituted | Ensure `./setup.sh` runs from the repo root so `snow` finds `sql/snowflake.yml` |
| Running low on time | Skip Act 4 and the capstone; go straight to Act 5 |

---

# Appendix: Setup & Reference

## Prerequisites

- [**Snowflake CLI**](https://docs.snowflake.com/en/developer-guide/snowflake-cli) (`snow`) with a configured connection (key-pair auth recommended). The only thing you set up in advance — no Snowsight.
- **Coco** (`cortex`) — used for `cortex agents run` / `cortex analyst query` and the interactive lab.
- **Python 3** — used by `setup.sh` / `snowclisp` to run the numbered SQL files.
- A role that can create a database, warehouse, roles, and a Cortex Agent (e.g. `ACCOUNTADMIN`).
- Cross-region inference for the agent's models:
  ```bash
  snow sql -c <your_connection> -q "ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';"
  ```

## Deploy

```bash
cp .env/dislocation.env.template .env/dislocation.env   # set CLI_CONNECTION_NAME (required)
./setup.sh                                              # runs sql/001..006, uploads skills, verifies
```

Object names (database, schema, warehouse, stage) are parameterized via `<% ctx.env.X %>` and resolved from `.env` at deploy time — the same files deploy to any database/schema with no SQL editing.

**Expected:** 44 geographies (5 states), 12 segments, ~5,000 policies; 3 semantic views; 1 agent; 5 skill files on the stage; a mix of CRITICAL/HIGH/MEDIUM/LOW for Florida.

## Repository layout

```
coco-dislocation-hol/
├── README.md                       ← this file (lab script + reference)
├── AGENTS.md                       ← project context/conventions for Coco
├── FUNCTIONAL_REQUIREMENTS.md      ← product/requirements spec (background)
├── setup.sh                        ← one-command deploy (SQL + skill upload + verify)
├── teardown.sh                     ← remove everything the lab created
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
├── .cortex/skills/dislocation-lab/SKILL.md   ← project Coco skill that operates the lab
└── pyutil/snowclisp/snowclisp.py             ← runs the numbered SQL files in order
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  YOU  (Coco CLI / Snowflake CLI)                            │
│    • cortex agents run   → ask the agent (Snowflake Cowork mode)
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
│  dislocation-score · retention-risk · market-hotspot-summary
│  explain-drivers · executive-briefing                        │
├─────────────────────────────────────────────────────────────┤
│  SEMANTIC VIEWS: SV_DISLOCATION · SV_PORTFOLIO · SV_CLAIMS_DETAIL
├─────────────────────────────────────────────────────────────┤
│  ADAPTER VIEWS: VW_DISLOCATION_ANALYSIS · VW_PORTFOLIO_SUMMARY · VW_CLAIMS_DETAIL
├─────────────────────────────────────────────────────────────┤
│  TABLES: DIM_GEOGRAPHY · DIM_SEGMENT · DIM_POLICY · DIM_PERIL │
│          FACT_PREMIUM_HISTORY · FACT_RATE_SCENARIO · FACT_CLAIMS · FACT_RETENTION
└─────────────────────────────────────────────────────────────┘
```

## Multi-state coverage

| State | Key perils | Dislocation driver |
|-------|-----------|--------------------|
| FL | Hurricane/flood, coastal concentration | High rate increases on coastal segments |
| TX | Hail corridor, Gulf hurricane, tornado | Roof replacement costs, active shopping market |
| LA | Extreme CAT, carrier exits | Market-structure problem — nowhere to go |
| CA | Wildfire WUI zones, FAIR Plan growth | Non-renewal pressure, not just pricing |

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

## Object inventory

| Object | Type | Purpose |
|--------|------|---------|
| `<DATABASE>` (`DISLOCATION_DEMO`) | Database | Lab container |
| `<SCHEMA>` (`CORE`) | Schema | All operational objects |
| `<SKILLS_SCHEMA>` (`SKILLS`) | Schema | Named stage for agent skill files |
| `<WAREHOUSE>` | Warehouse | Compute (XSMALL, auto-suspend) |
| `DIM_*` / `FACT_*` | Tables | Reference dimensions + facts |
| `VW_DISLOCATION_ANALYSIS` / `VW_PORTFOLIO_SUMMARY` / `VW_CLAIMS_DETAIL` | Views | Stable adapter (contract) layer |
| `SV_DISLOCATION` / `SV_PORTFOLIO` / `SV_CLAIMS_DETAIL` | Semantic Views | The agent's governed data surfaces |
| `DISLOCATION_ANALYSIS_AGENT` | Agent | Conversational agent with 5 skills |
| `SKILL_STAGE` | Stage | 5 skill `SKILL.md` files |
| `DISLOCATION_DIRECTOR_RL` / `DISLOCATION_ANALYST_RL` | Roles | Governed personas |

## Customization

- **Different account layout:** change `DATABASE` / `SCHEMA` / `WAREHOUSE` / `STAGE` in `.env/dislocation.env` — no SQL editing.
- **Different data:** edit the seed inserts in `sql/002-dml.sql`.
- **Different scoring:** adjust the weighted components in `sql/003-views.sql` (`VW_DISLOCATION_ANALYSIS`).
- **Connect to real data:** repoint the adapter views in `sql/003-views.sql`; the semantic views, agent, and skills stay unchanged.

## Teardown

```bash
./teardown.sh
```

Removes the database (all schemas, tables, views, stages), the warehouse, and both lab roles, using the same `.env` configuration.

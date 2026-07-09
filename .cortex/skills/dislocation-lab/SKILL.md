---
name: dislocation-lab
description: "Operate the Pricing Dislocation Coco CLI hands-on lab. Use this skill whenever the user mentions: set up / deploy the lab, reset the lab, tear down, verify the deployment, ask the agent, dislocation analysis, dislocation score, retention risk, run the lab, the demo script, or any deploy/verify/governance operation in this project. Always use this skill for lab-related tasks even if the user doesn't say 'lab'."
---

# Dislocation Lab Skill

Helps a Snowflake SE (or lab participant) operate the Pricing Dislocation lab from Coco CLI without memorizing commands. It translates natural-language requests into the right actions. Everything is CLI-driven — the only optional Snowsight step is the Snowflake Cowork capstone.

## Important context

- Deployment is driven by `./setup.sh`, which sources `.env/dislocation.env`, runs the numbered files in `sql/` (001–006) via `snowclisp` (`snow sql`), uploads the 5 agent skills to the stage, and verifies.
- Object names are parameterized via `<% ctx.env.X %>` and resolved from `.env/dislocation.env`. Defaults: DATABASE `DISLOCATION_DEMO`, SCHEMA `CORE`, SKILLS_SCHEMA `SKILLS`, STAGE `SKILL_STAGE`, WAREHOUSE `DISLOCATION_DEMO_WH`.
- The deployed agent is `<DATABASE>.<SCHEMA>.DISLOCATION_ANALYSIS_AGENT` (default `DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT`).
- `sql/optional-pii_masking.sql` is NOT run by `setup.sh` (no numeric prefix); apply it only when demonstrating dynamic masking.

## Deploy / set up the lab

When the user wants to set up, deploy, initialize, or start the lab:

1. Ensure config exists — if `.env/dislocation.env` is missing:
   ```bash
   cp .env/dislocation.env.template .env/dislocation.env
   ```
   Tell the user to set at least `CLI_CONNECTION_NAME`, then continue.
2. Deploy:
   ```bash
   ./setup.sh
   ```
   `setup.sh` prints the exact `cortex agents run` command for the configured database/schema when it finishes.

## Verify the deployment

```bash
snow sql -c <conn> -q "
SELECT 'DIM_POLICY' t, COUNT(*) n FROM DISLOCATION_DEMO.CORE.DIM_POLICY
UNION ALL SELECT 'VW_DISLOCATION_ANALYSIS', COUNT(*) FROM DISLOCATION_DEMO.CORE.VW_DISLOCATION_ANALYSIS;"
snow sql -c <conn> -q "SHOW SEMANTIC VIEWS IN SCHEMA DISLOCATION_DEMO.CORE;"
snow sql -c <conn> -q "LS @DISLOCATION_DEMO.SKILLS.SKILL_STAGE/ PATTERN='.*SKILL\.md';"
cortex agents describe DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT
```
Expected: ~11,000 policies; 3 semantic views; 5 skill files on the stage; the agent present.

## Ask the agent (Snowflake Cowork mode)

```bash
cortex agents run DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT "Find pricing dislocation in Florida property"
```
Other good prompts: "Compare dislocation risk across all states", "Why is Louisiana showing so many critical segments?", "Which segments combine high premium uplift with high lapse propensity?", "Generate a director briefing on national dislocation hotspots".

## Query semantic views directly

```bash
cortex analyst query "Which segments have the highest dislocation score in Florida?" \
  --view DISLOCATION_DEMO.CORE.SV_DISLOCATION
```
`SV_PORTFOLIO` for portfolio composition, `SV_CLAIMS_DETAIL` for claims.

## Governance (RBAC + optional PII masking)

- Roles: `DISLOCATION_DIRECTOR_RL` (agent + views only) vs `DISLOCATION_ANALYST_RL` (full tables + skills).
- Apply dynamic PII masking on claimant/attorney names:
  ```bash
  snow sql -c <conn> -f sql/optional-pii_masking.sql
  ```
  Then the same claims question returns full names for the Analyst role and `●●●● REDACTED ●●●●` for the Director role — enforced at the platform layer, transparent to the agent.

## Reset the lab (clean slate)

When the user wants to reset, clean, tear down, or start over:

1. Check the current branch. If not on `main`, ask before switching (the lab script cuts a dev branch as a live moment):
   ```bash
   git branch --show-current
   git checkout main && git pull   # only after confirming
   ```
2. Remove any scratch model/SQL files created during a session (ask before deleting anything not tracked).
3. Drop Snowflake objects:
   ```bash
   ./teardown.sh
   ```
   Re-run `./setup.sh` to stand it back up.

## Scoring reference & guardrails

Dislocation Score = 0.35·RateChange + 0.25·Lapse + 0.20·LossRatio + 0.10·Concentration + 0.10·Competitive.
Bands: CRITICAL ≥ 0.55, HIGH ≥ 0.40, MEDIUM ≥ 0.25, LOW < 0.25.
Never recommend specific rate actions; always note results require actuarial review.

---
name: dislocation-lab
description: "Operate the Pricing Dislocation Coco hands-on lab in any environment — Coco CLI, Coco Desktop, or Coco in Snowsight (Cloud Agents). Use this skill whenever the user mentions: set up / deploy the lab, reset the lab, tear down, verify the deployment, ask the agent, dislocation analysis, dislocation score, retention risk, run the lab, the demo script, or any deploy/verify/governance operation in this project. Always use this skill for lab-related tasks even if the user doesn't say 'lab'."
---

# Dislocation Lab Skill

Helps a Snowflake SE (or lab participant) operate the Pricing Dislocation lab from Coco without memorizing commands. It translates natural-language requests into the right actions. The lab runs three ways — **Coco CLI**, **Coco Desktop**, and **Coco in Snowsight (Cloud Agents)** — with an identical deploy path; only a few environment details differ (see below).

## Environments

The deploy is the same everywhere: `./setup.sh` runs the numbered SQL and uploads skills. What changes by environment:

| | CLI / Coco Desktop | Snowsight (Cloud Agents) |
|---|---|---|
| Shell | local terminal | isolated container (full shell: `snow`, `python3`, `git`, `cortex`) |
| Snowflake auth | user's named connection in `~/.snowflake/connections.toml` | ambient Snowsight session via pre-wired `default` connection |
| `CLI_CONNECTION_NAME` | the user's connection name | `default` |
| Repo in front of Coco | local `git clone` | Git-synced workspace |
| Ask the agent | `cortex agents run …` | open the agent in Snowflake Cowork (AI & ML » Agents) |

**Detecting the environment:** if you're unsure, a quick `cortex connections list` (or checking whether a `default` connection resolves) tells you. In Snowsight/Cloud Agents the connection is `default` and the filesystem is session-scoped (not persistent across sessions) — if a returning user's files are gone, re-open the git workspace and re-deploy.

## Important context

- Deployment is driven by `./setup.sh`, which sources `.env/dislocation.env`, runs the numbered files in `sql/` (001–007) via `snowclisp` (`snow sql`), uploads the 5 agent skills to the stage, exposes the agent in Snowflake Cowork, and verifies.
- Object names are parameterized via `<% ctx.env.X %>` and resolved from `.env/dislocation.env`. Defaults: DATABASE `DISLOCATION_DEMO`, SCHEMA `CORE`, SKILLS_SCHEMA `SKILLS`, STAGE `SKILL_STAGE`, WAREHOUSE `DISLOCATION_DEMO_WH`, CLI_CONNECTION_NAME `default`.
- The deployed agent is `<DATABASE>.<SCHEMA>.DISLOCATION_ANALYSIS_AGENT` (default `DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT`).
- `sql/007-cowork.sql` (run by `setup.sh`) registers the agent in the account-level Snowflake Cowork object so it appears in AI & ML » Agents.
- `sql/optional-pii_masking.sql` is NOT run by `setup.sh` (no numeric prefix); apply it only when demonstrating dynamic masking.

## Deploy / set up the lab

When the user wants to set up, deploy, initialize, or start the lab:

1. Ensure config is set. `.env/dislocation.env` is the single config file (no template to copy).
   - **CLI / Desktop:** confirm `CLI_CONNECTION_NAME` points at the user's connection.
   - **Snowsight:** leave `CLI_CONNECTION_NAME=default` (the ambient session).
2. Deploy:
   ```bash
   ./setup.sh
   ```
   `setup.sh` prints a summary and the exact `cortex agents run` command for the configured database/schema when it finishes. In Snowsight, point the user to Snowflake Cowork instead of that CLI command.

## Verify the deployment

```bash
snow sql -c <conn> -q "
SELECT 'DIM_POLICY' t, COUNT(*) n FROM DISLOCATION_DEMO.CORE.DIM_POLICY
UNION ALL SELECT 'VW_DISLOCATION_ANALYSIS', COUNT(*) FROM DISLOCATION_DEMO.CORE.VW_DISLOCATION_ANALYSIS;"
snow sql -c <conn> -q "SHOW SEMANTIC VIEWS IN SCHEMA DISLOCATION_DEMO.CORE;"
snow sql -c <conn> -q "LS @DISLOCATION_DEMO.SKILLS.SKILL_STAGE/ PATTERN='.*SKILL\.md';"
cortex agents describe DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT
```
Use `-c default` in Snowsight. Expected: ~11,000 policies; 3 semantic views; 5 skill files on the stage; the agent present (and visible in Cowork).

## Ask the agent

**CLI / Coco Desktop:**
```bash
cortex agents run DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT "Find pricing dislocation in Florida property"
```

**Snowsight:** open Snowflake Cowork (Snowsight » AI & ML » Agents, or ai.snowflake.com), select `DISLOCATION_ANALYSIS_AGENT`, and ask the same question. `setup.sh` already exposed it there via `007-cowork.sql`.

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
   In Snowsight, branch switching can also be done from the Workspaces **Changes** tab.
2. Remove any scratch model/SQL files created during a session (ask before deleting anything not tracked).
3. Drop Snowflake objects:
   ```bash
   ./teardown.sh
   ```
   Re-run `./setup.sh` to stand it back up. (`teardown.sh` also removes the agent's Cowork registration.)

## Scoring reference & guardrails

Dislocation Score = 0.35·RateChange + 0.25·Lapse + 0.20·LossRatio + 0.10·Concentration + 0.10·Competitive.
Bands: CRITICAL ≥ 0.55, HIGH ≥ 0.40, MEDIUM ≥ 0.25, LOW < 0.25.
Never recommend specific rate actions; always note results require actuarial review.

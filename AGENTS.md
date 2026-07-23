# AGENTS.md

## Project overview

This is the **Pricing Dislocation — Coco Hands-On Lab**: a Snowflake-native lab that deploys a governed agentic-analytics workload for P&C insurance pricing dislocation, then explores it from **Coco**. It runs three ways with an identical deploy path — the **Coco CLI**, **Coco Desktop**, or **Coco in Snowsight** (Cloud Agents, which gives the side-panel assistant a real shell). Business users consume the deployed agent in **Snowflake Cowork**. Environment differences: CLI/Desktop use a named `connections.toml` connection and local git; Snowsight uses the ambient session via the pre-wired `default` connection and a Git-synced workspace, and you open the agent in Cowork instead of `cortex agents run`.

**Tech stack:** Snowflake CLI (`snow`), Coco (`cortex`), Python 3 (runs the SQL files via `snowclisp`). No dbt, no Streamlit.

IMPORTANT: Any time you make changes to files in this project, ask: "Shall I commit these changes to git?" If yes, commit with a descriptive commit message. The commit message header should be no longer than 50 characters. If no, continue. Keep the git history clean and meaningful.

## What gets deployed

`./setup.sh` runs `sql/001..007` in order, uploads the 5 agent skills to the stage, and exposes the agent in Snowflake Cowork:

| Layer | Objects |
|-------|---------|
| Tables | `DIM_GEOGRAPHY`, `DIM_SEGMENT`, `DIM_POLICY`, `DIM_PERIL`, `FACT_PREMIUM_HISTORY`, `FACT_RATE_SCENARIO`, `FACT_CLAIMS`, `FACT_RETENTION` |
| Adapter views | `VW_DISLOCATION_ANALYSIS`, `VW_PORTFOLIO_SUMMARY`, `VW_CLAIMS_DETAIL` |
| Semantic views | `SV_DISLOCATION`, `SV_PORTFOLIO`, `SV_CLAIMS_DETAIL` |
| Agent | `DISLOCATION_ANALYSIS_AGENT` (5 skills + `Claims_Detail` tool) |
| Roles | `DISLOCATION_DIRECTOR_RL`, `DISLOCATION_ANALYST_RL` |

## Setup commands

```bash
# edit .env/dislocation.env → set CLI_CONNECTION_NAME (leave `default` in Snowsight)
./setup.sh                                              # deploy + upload skills + Cowork + verify
./teardown.sh                                           # remove everything
```

## How to interact

```bash
# Ask the deployed agent (Snowflake Cowork mode, from the CLI)
cortex agents run DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT "Find pricing dislocation in Florida property"

# Query a semantic view directly
cortex analyst query "Top dislocation segments in Florida" --view DISLOCATION_DEMO.CORE.SV_DISLOCATION

# Inspect the agent
cortex agents describe DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT
```

## Project structure

```
setup.sh · teardown.sh          # deploy / teardown (runs in any shell: CLI, Desktop, or Snowsight Cloud Agents)
.env/dislocation.env            # deploy config (set CLI_CONNECTION_NAME; `default` in Snowsight)
sql/                            # snowflake.yml + 001-ddl .. 007-cowork + optional-pii_masking.sql
skills/                         # 5 Cortex Agent skills (uploaded to the stage)
.cortex/skills/dislocation-lab/ # local Coco skill that operates the lab conversationally
pyutil/snowclisp/               # runs the numbered SQL files in order
```

## Conventions

- **SQL is parameterized** with `<% ctx.env.X %>` and resolved from `.env` at deploy time. When editing `sql/*.sql`, keep object references templated (`<% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.…`) — do not hardcode `DISLOCATION_DEMO`.
- The numbered files run in order; anything without a numeric prefix (e.g. `optional-pii_masking.sql`) is intentionally skipped by `snowclisp`.
- Never edit `~/.snowflake/connections.toml` — it holds credentials.
- Use fully-qualified names (`DATABASE.SCHEMA.OBJECT`) in generated SQL for clarity.
- Do not deploy or run destructive Snowflake operations without confirming with the user.

## Branding

- The assistant is **Coco** — available as the Coco CLI, Coco Desktop, and Coco in Snowsight (Cloud Agents). The `cortex` binary name is unchanged.
- The business-user conversational UI is **Snowflake Cowork**.
- **Cortex Agent(s)** and **Cortex Analyst** product names are unchanged.

## Notes

- Cross-region inference must be enabled for the agent's models: `ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';`
- Scoring: `0.35·RateChange + 0.25·Lapse + 0.20·LossRatio + 0.10·Concentration + 0.10·Competitive`; bands CRITICAL ≥ 0.55 / HIGH ≥ 0.40 / MEDIUM ≥ 0.25 / LOW < 0.25.
- Start a session with `auto` or `claude-opus-4-8` for the best experience.

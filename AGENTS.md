# AGENTS.md

## Project overview

This is the **Pricing Dislocation — Coco CLI Hands-On Lab**: a Snowflake-native, CLI-driven lab that deploys a governed agentic-analytics workload for P&C insurance pricing dislocation, then explores it entirely from **Coco** (Coco CLI or Coco Desktop). Business users consume the deployed agent in **Snowflake Cowork**, but that UI step is optional — the whole lab runs from the command line.

**Tech stack:** Snowflake CLI (`snow`), Coco (`cortex`), Python 3 (runs the SQL files via `snowclisp`). No dbt, no Streamlit.

IMPORTANT: Any time you make changes to files in this project, ask: "Tis I, Coco — shall I commit these changes to git?" If yes, commit with a descriptive message. If no, continue. Keep the git history clean and meaningful.

## What gets deployed

`./setup.sh` runs `sql/001..006` in order and uploads the 5 agent skills to the stage:

| Layer | Objects |
|-------|---------|
| Tables | `DIM_GEOGRAPHY`, `DIM_SEGMENT`, `DIM_POLICY`, `DIM_PERIL`, `FACT_PREMIUM_HISTORY`, `FACT_RATE_SCENARIO`, `FACT_CLAIMS`, `FACT_RETENTION` |
| Adapter views | `VW_DISLOCATION_ANALYSIS`, `VW_PORTFOLIO_SUMMARY`, `VW_CLAIMS_DETAIL` |
| Semantic views | `SV_DISLOCATION`, `SV_PORTFOLIO`, `SV_CLAIMS_DETAIL` |
| Agent | `DISLOCATION_ANALYSIS_AGENT` (5 skills + `Claims_Detail` tool) |
| Roles | `DISLOCATION_DIRECTOR_RL`, `DISLOCATION_ANALYST_RL` |

## Setup commands

```bash
cp .env/dislocation.env.template .env/dislocation.env   # set CLI_CONNECTION_NAME
./setup.sh                                              # deploy + upload skills + verify
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
setup.sh · teardown.sh          # deploy / teardown (Snowflake CLI, no Snowsight)
.env/dislocation.env.template   # deploy config (copy to dislocation.env)
sql/                            # snowflake.yml + 001-ddl .. 006-rbac + optional-pii_masking.sql
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

- The CLI/desktop assistant is **Coco** (Coco CLI, Coco Desktop). The `cortex` binary name is unchanged.
- The business-user conversational UI is **Snowflake Cowork**.
- **Cortex Agent(s)** and **Cortex Analyst** product names are unchanged.

## Notes

- Cross-region inference must be enabled for the agent's models: `ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';`
- Scoring: `0.35·RateChange + 0.25·Lapse + 0.20·LossRatio + 0.10·Concentration + 0.10·Competitive`; bands CRITICAL ≥ 0.55 / HIGH ≥ 0.40 / MEDIUM ≥ 0.25 / LOW < 0.25.
- Start a session with `auto` or `claude-opus-4-8` for the best experience.

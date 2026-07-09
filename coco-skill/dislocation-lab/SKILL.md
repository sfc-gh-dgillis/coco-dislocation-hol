---
name: dislocation-lab
description: Guides a user through the Pricing Dislocation Coco hands-on lab — deploying the objects, asking the deployed agent questions from the CLI, querying the semantic views, and demonstrating RBAC + PII masking. Invoke when the user mentions the dislocation lab, dislocation analysis, or asks how to run/drive this lab.
---

# Dislocation Lab Guide (Coco companion skill)

This is a local Coco skill that helps a participant run the Pricing
Dislocation hands-on lab entirely from the command line. No Snowsight is
required (the only optional Snowsight step is chatting with the deployed agent
in Snowflake Cowork at the very end).

## Deploy the lab

1. `cp .env/dislocation.env.template .env/dislocation.env` and set at least
   `CLI_CONNECTION_NAME` (a configured Snowflake CLI connection).
2. Run `./setup.sh`. It runs `sql/001..006` in order via snowclisp, uploads the
   5 agent skills to the stage, and verifies row counts / semantic views / agent.

## Ask the agent (Snowflake Cowork, from the CLI)

Use `cortex agents run <DB>.<SCHEMA>.DISLOCATION_ANALYSIS_AGENT "<question>"`.
Good starter questions:
- "Find pricing dislocation in Florida property"
- "Compare dislocation risk across all states"
- "Why is Louisiana showing so many critical segments?"
- "Which segments combine high premium uplift with high lapse propensity?"
- "Summarize the top 5 dislocation risks for Florida property and generate a director briefing"

## Query semantic views directly

`cortex analyst query "<question>" --view <DB>.<SCHEMA>.SV_DISLOCATION`
(SV_PORTFOLIO for portfolio composition, SV_CLAIMS_DETAIL for claims.)

## Demonstrate governance (RBAC + optional PII masking)

- Roles: `DISLOCATION_DIRECTOR_RL` (agent + views only) vs
  `DISLOCATION_ANALYST_RL` (full tables + skills).
- To add dynamic PII masking on claimant/attorney names, run the optional module:
  `snow sql -c <conn> -f sql/optional-pii_masking.sql`
  Then the same claims question returns full names for the Analyst role and
  `●●●● REDACTED ●●●●` for the Director role — masking enforced at the platform
  layer, transparent to the agent.

## Scoring reference

Dislocation Score = 0.35·RateChange + 0.25·Lapse + 0.20·LossRatio +
0.10·Concentration + 0.10·Competitive. Bands: CRITICAL ≥ 0.55, HIGH ≥ 0.40,
MEDIUM ≥ 0.25, LOW < 0.25. Never recommend specific rate actions; always note
results require actuarial review.

## Teardown

`./teardown.sh` removes the database, warehouse, and both lab roles.

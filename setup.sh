#!/usr/bin/env bash
set -euo pipefail

# Pricing Dislocation — Coco CLI Hands-On Lab deployment.
#
# 1. Sources the deployment environment variables, then runs the numbered SQL
#    files in sql/ (001-*.sql .. 007-*.sql) in order via snowclisp, using the
#    configured Snowflake CLI connection. This creates the database, tables,
#    seed data, adapter views, semantic views, the Cortex Agent, RBAC roles, and
#    exposes the agent in the Snowflake CoWork UI.
# 2. Uploads the 5 Cortex Agent skills to the named stage so the deployed agent
#    can load them at runtime (server-side skills — see README).
# 3. Runs verification queries and prints a summary.
#
# snowclisp runs `snow sql`, which resolves the `<% ctx.env.X %>` templates from
# sql/snowflake.yml in its working directory (shell env vars override those
# values). We therefore run from sql/ so snow picks up sql/snowflake.yml.
#
# No Snowsight is required for any of this — it is all Snowflake CLI.
# The optional PII-masking extension (sql/optional-pii_masking.sql) is NOT run
# here; it has no numeric prefix so snowclisp skips it. Run it manually to add
# the masking-policy governance module (see README).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env/dislocation.env}"
SQL_DIR="$SCRIPT_DIR/sql"
SNOWCLISP="$SCRIPT_DIR/pyutil/snowclisp/snowclisp.py"
SKILLS_DIR="$SCRIPT_DIR/skills"

SKILLS=(dislocation-score retention-risk market-hotspot-summary explain-drivers executive-briefing)

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: env file not found: $ENV_FILE" >&2
  echo "  Create it with: cp .env/dislocation.env.template .env/dislocation.env" >&2
  exit 1
fi

# Source and export every variable defined in the env file.
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${CLI_CONNECTION_NAME:?ERROR: CLI_CONNECTION_NAME is not set in $ENV_FILE}"
: "${DATABASE:?ERROR: DATABASE is not set in $ENV_FILE}"
: "${SCHEMA:?ERROR: SCHEMA is not set in $ENV_FILE}"
: "${SKILLS_SCHEMA:?ERROR: SKILLS_SCHEMA is not set in $ENV_FILE}"
: "${STAGE:?ERROR: STAGE is not set in $ENV_FILE}"

# --- Step 1: run the numbered SQL files -----------------------------------
echo "Step 1/3: Running SQL files in $SQL_DIR using connection '$CLI_CONNECTION_NAME'..."
cd "$SQL_DIR"
python3 "$SNOWCLISP" . "$CLI_CONNECTION_NAME"
cd "$SCRIPT_DIR"

# --- Step 2: upload the 5 agent skills to the stage -----------------------
echo ""
echo "Step 2/3: Uploading ${#SKILLS[@]} agent skills to @${DATABASE}.${SKILLS_SCHEMA}.${STAGE}"
for skill in "${SKILLS[@]}"; do
  local_path="$SKILLS_DIR/$skill/SKILL.md"
  stage_path="@${DATABASE}.${SKILLS_SCHEMA}.${STAGE}/skills/$skill/"
  if [[ ! -f "$local_path" ]]; then
    echo "ERROR: skill file not found: $local_path" >&2
    exit 1
  fi
  echo "  Uploading $skill ..."
  snow sql -c "$CLI_CONNECTION_NAME" -q \
    "PUT file://$local_path $stage_path AUTO_COMPRESS=FALSE OVERWRITE=TRUE;" >/dev/null
done
echo "  All ${#SKILLS[@]} skills uploaded."

# --- Step 3: verify + summary ---------------------------------------------
echo ""
echo "Step 3/3: Verifying deployment..."

snow sql -c "$CLI_CONNECTION_NAME" -q "
SELECT 'DIM_GEOGRAPHY' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM ${DATABASE}.${SCHEMA}.DIM_GEOGRAPHY
UNION ALL SELECT 'DIM_SEGMENT', COUNT(*) FROM ${DATABASE}.${SCHEMA}.DIM_SEGMENT
UNION ALL SELECT 'DIM_POLICY', COUNT(*) FROM ${DATABASE}.${SCHEMA}.DIM_POLICY
UNION ALL SELECT 'FACT_PREMIUM_HISTORY', COUNT(*) FROM ${DATABASE}.${SCHEMA}.FACT_PREMIUM_HISTORY
UNION ALL SELECT 'FACT_RATE_SCENARIO', COUNT(*) FROM ${DATABASE}.${SCHEMA}.FACT_RATE_SCENARIO
UNION ALL SELECT 'FACT_CLAIMS', COUNT(*) FROM ${DATABASE}.${SCHEMA}.FACT_CLAIMS
UNION ALL SELECT 'FACT_RETENTION', COUNT(*) FROM ${DATABASE}.${SCHEMA}.FACT_RETENTION
ORDER BY TABLE_NAME;"

snow sql -c "$CLI_CONNECTION_NAME" -q "SHOW SEMANTIC VIEWS IN SCHEMA ${DATABASE}.${SCHEMA};"
snow sql -c "$CLI_CONNECTION_NAME" -q "LS @${DATABASE}.${SKILLS_SCHEMA}.${STAGE}/ PATTERN='.*SKILL\.md';"
snow sql -c "$CLI_CONNECTION_NAME" -q "
SELECT DISLOCATION_SEVERITY, COUNT(*) AS SEGMENT_COUNT
FROM ${DATABASE}.${SCHEMA}.VW_DISLOCATION_ANALYSIS
WHERE STATE = 'FL'
GROUP BY DISLOCATION_SEVERITY
ORDER BY 1;"

AGENT_FQN="${DATABASE}.${SCHEMA}.DISLOCATION_ANALYSIS_AGENT"
cat <<EOF

============================================================
Deployment complete
============================================================
  Database/Schema:  ${DATABASE}.${SCHEMA}
  Skills stage:     @${DATABASE}.${SKILLS_SCHEMA}.${STAGE}
  Warehouse:        ${WAREHOUSE:-<from env>}
  Semantic views:   SV_DISLOCATION, SV_PORTFOLIO, SV_CLAIMS_DETAIL
  Agent:            ${AGENT_FQN}
  Roles:            DISLOCATION_DIRECTOR_RL, DISLOCATION_ANALYST_RL

Next steps (all from the command line — no Snowsight needed):

  # Ask the agent a question (Snowflake Cowork, from the CLI):
  cortex agents run ${AGENT_FQN} "Find pricing dislocation in Florida property"

  # Or query a semantic view directly:
  cortex analyst query "Which segments have the highest dislocation score?" \\
    --view ${DATABASE}.${SCHEMA}.SV_DISLOCATION

  # Or open the agent in the Snowflake CoWork UI (already exposed by setup):
  #   https://ai.snowflake.com   (Snowsight: AI & ML » Agents)

Optional governance module (adds dynamic PII masking):
  snow sql -c ${CLI_CONNECTION_NAME} -f sql/optional-pii_masking.sql
============================================================
EOF

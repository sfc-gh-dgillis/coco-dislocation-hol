#!/usr/bin/env bash
set -euo pipefail

# Pricing Dislocation Lab — teardown.
# Removes everything setup.sh created, using the same .env configuration.
# Pure Snowflake CLI — no Snowsight.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env/dislocation.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: env file not found: $ENV_FILE" >&2
  echo "  Create it with: cp .env/dislocation.env.template .env/dislocation.env" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${CLI_CONNECTION_NAME:?ERROR: CLI_CONNECTION_NAME is not set in $ENV_FILE}"
: "${ROLE:?ERROR: ROLE is not set in $ENV_FILE}"
: "${DATABASE:?ERROR: DATABASE is not set in $ENV_FILE}"
: "${SCHEMA:?ERROR: SCHEMA is not set in $ENV_FILE}"
: "${WAREHOUSE:?ERROR: WAREHOUSE is not set in $ENV_FILE}"

echo "Tearing down ${DATABASE} (schema ${SCHEMA}), warehouse ${WAREHOUSE}, and lab roles..."

snow sql -c "$CLI_CONNECTION_NAME" -q "
USE ROLE ${ROLE};

-- Drop the agent first (depends on semantic views)
DROP AGENT IF EXISTS ${DATABASE}.${SCHEMA}.DISLOCATION_ANALYSIS_AGENT;

-- Drop semantic views
DROP SEMANTIC VIEW IF EXISTS ${DATABASE}.${SCHEMA}.SV_DISLOCATION;
DROP SEMANTIC VIEW IF EXISTS ${DATABASE}.${SCHEMA}.SV_PORTFOLIO;
DROP SEMANTIC VIEW IF EXISTS ${DATABASE}.${SCHEMA}.SV_CLAIMS_DETAIL;

-- Drop the database (cascades all schemas, tables, views, stages)
DROP DATABASE IF EXISTS ${DATABASE};

-- Drop the warehouse
DROP WAREHOUSE IF EXISTS ${WAREHOUSE};

-- Drop roles
DROP ROLE IF EXISTS DISLOCATION_DIRECTOR_RL;
DROP ROLE IF EXISTS DISLOCATION_ANALYST_RL;
"

echo "Teardown complete: removed ${DATABASE}, ${WAREHOUSE}, and the two lab roles."

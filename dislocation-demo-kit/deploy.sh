#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  Dislocation Analysis Demo — Automated Deployment Script                ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║  Deploys the full demo to a Snowflake account:                          ║
# ║    1. Runs install.sql (tables, views, semantic views, agent, roles)     ║
# ║    2. Uploads all 5 skill files to the agent stage                      ║
# ║    3. Runs verification queries                                         ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Configuration ─────────────────────────────────────────────────────────────
# Set your connection name here or pass via environment variable
SNOW_CONNECTION="${SNOW_CONNECTION:-}"
SNOW_CLI="${SNOW_CLI:-snow}"  # Use "snow" (Snow CLI) or "snowsql" (SnowSQL)

# ─── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ─── Pre-flight checks ────────────────────────────────────────────────────────

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Dislocation Analysis Demo — Deployment                      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check for Snow CLI or SnowSQL
if command -v snow &>/dev/null; then
    SNOW_CLI="snow"
    info "Found Snow CLI (snow)"
elif command -v snowsql &>/dev/null; then
    SNOW_CLI="snowsql"
    info "Found SnowSQL"
else
    error "Neither 'snow' (Snow CLI) nor 'snowsql' (SnowSQL) found in PATH.
       Install Snow CLI: pip install snowflake-cli
       Or install SnowSQL: https://docs.snowflake.com/en/user-guide/snowsql"
fi

# Connection argument
CONN_ARG=""
if [[ -n "$SNOW_CONNECTION" ]]; then
    if [[ "$SNOW_CLI" == "snow" ]]; then
        CONN_ARG="--connection $SNOW_CONNECTION"
    else
        CONN_ARG="--connection $SNOW_CONNECTION"
    fi
    info "Using connection: $SNOW_CONNECTION"
else
    info "Using default connection (set SNOW_CONNECTION env var to override)"
fi

# ─── Helper: execute SQL ───────────────────────────────────────────────────────

run_sql_file() {
    local file="$1"
    local desc="$2"
    info "Running: $desc"
    if [[ "$SNOW_CLI" == "snow" ]]; then
        snow sql -f "$file" $CONN_ARG 2>&1 | tail -5
    else
        snowsql $CONN_ARG -f "$file" 2>&1 | tail -5
    fi
}

run_sql() {
    local query="$1"
    if [[ "$SNOW_CLI" == "snow" ]]; then
        snow sql -q "$query" $CONN_ARG 2>&1
    else
        snowsql $CONN_ARG -q "$query" 2>&1
    fi
}

# ─── Step 1: Run install script ────────────────────────────────────────────────

info "Step 1/3: Running install.sql (creates database, tables, views, agent, roles)"
run_sql_file "$SCRIPT_DIR/install.sql" "install.sql"
ok "Install script completed"
echo ""

# ─── Step 2: Upload skills to stage ───────────────────────────────────────────

info "Step 2/3: Uploading 5 skill files to @DISLOCATION_DEMO.SKILLS.SKILL_STAGE"

SKILLS=("dislocation-score" "retention-risk" "market-hotspot-summary" "explain-drivers" "executive-briefing")

for skill in "${SKILLS[@]}"; do
    local_path="$SCRIPT_DIR/skills/$skill/SKILL.md"
    stage_path="@DISLOCATION_DEMO.SKILLS.SKILL_STAGE/skills/$skill/"

    if [[ ! -f "$local_path" ]]; then
        error "Skill file not found: $local_path"
    fi

    info "  Uploading $skill..."
    run_sql "PUT file://$local_path $stage_path AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
done

ok "All 5 skills uploaded"
echo ""

# ─── Step 3: Verify installation ──────────────────────────────────────────────

info "Step 3/3: Running verification queries"

echo ""
info "  Checking table row counts..."
run_sql "
SELECT 'DIM_GEOGRAPHY' AS TBL, COUNT(*) AS ROWS FROM DISLOCATION_DEMO.CORE.DIM_GEOGRAPHY
UNION ALL SELECT 'DIM_SEGMENT', COUNT(*) FROM DISLOCATION_DEMO.CORE.DIM_SEGMENT
UNION ALL SELECT 'DIM_POLICY', COUNT(*) FROM DISLOCATION_DEMO.CORE.DIM_POLICY
UNION ALL SELECT 'FACT_PREMIUM_HISTORY', COUNT(*) FROM DISLOCATION_DEMO.CORE.FACT_PREMIUM_HISTORY
UNION ALL SELECT 'FACT_RATE_SCENARIO', COUNT(*) FROM DISLOCATION_DEMO.CORE.FACT_RATE_SCENARIO
UNION ALL SELECT 'FACT_CLAIMS', COUNT(*) FROM DISLOCATION_DEMO.CORE.FACT_CLAIMS
UNION ALL SELECT 'FACT_RETENTION', COUNT(*) FROM DISLOCATION_DEMO.CORE.FACT_RETENTION;
"

echo ""
info "  Checking semantic views..."
run_sql "SHOW SEMANTIC VIEWS IN SCHEMA DISLOCATION_DEMO.CORE;"

echo ""
info "  Checking agent..."
run_sql "DESCRIBE AGENT DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT;"

echo ""
info "  Checking skills on stage..."
run_sql "LS @DISLOCATION_DEMO.SKILLS.SKILL_STAGE/ PATTERN='.*SKILL\.md';"

echo ""
info "  Checking dislocation severity distribution (FL)..."
run_sql "
SELECT DISLOCATION_SEVERITY, COUNT(*) AS SEGMENT_COUNT
FROM DISLOCATION_DEMO.CORE.VW_DISLOCATION_ANALYSIS
WHERE STATE = 'FL'
GROUP BY DISLOCATION_SEVERITY
ORDER BY 1;
"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  DEPLOYMENT COMPLETE                                         ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  Next steps:                                                 ║"
echo "║    1. Open Snowflake Intelligence                            ║"
echo "║    2. Select: DISLOCATION_ANALYSIS_AGENT                     ║"
echo "║    3. Ask: 'Find pricing dislocation in Florida property'    ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
ok "Done!"

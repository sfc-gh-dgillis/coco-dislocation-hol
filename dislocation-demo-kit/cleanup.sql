-- ╔═══════════════════════════════════════════════════════════════════════════╗
-- ║  DISLOCATION ANALYSIS — Cleanup / Teardown Script                       ║
-- ╠═══════════════════════════════════════════════════════════════════════════╣
-- ║  This script removes ALL objects created by dislocation_demo_install.sql ║
-- ║  Run this to cleanly remove the demo from the account.                  ║
-- ╚═══════════════════════════════════════════════════════════════════════════╝

USE ROLE ACCOUNTADMIN;

-- Drop the agent first (depends on semantic views)
DROP AGENT IF EXISTS DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT;

-- Drop semantic views
DROP SEMANTIC VIEW IF EXISTS DISLOCATION_DEMO.CORE.SV_DISLOCATION;
DROP SEMANTIC VIEW IF EXISTS DISLOCATION_DEMO.CORE.SV_PORTFOLIO;

-- Drop the database (cascades all schemas, tables, views, stages)
DROP DATABASE IF EXISTS DISLOCATION_DEMO;

-- Drop the warehouse
DROP WAREHOUSE IF EXISTS DISLOCATION_DEMO_WH;

-- Drop roles
DROP ROLE IF EXISTS DISLOCATION_DIRECTOR_RL;
DROP ROLE IF EXISTS DISLOCATION_ANALYST_RL;

-- ╔═══════════════════════════════════════════════════════════════════════════╗
-- ║  CLEANUP COMPLETE                                                       ║
-- ║                                                                         ║
-- ║  Removed:                                                               ║
-- ║    • Database DISLOCATION_DEMO (all schemas, tables, views, stages)     ║
-- ║    • Warehouse DISLOCATION_DEMO_WH                                      ║
-- ║    • Roles: DISLOCATION_DIRECTOR_RL, DISLOCATION_ANALYST_RL             ║
-- ╚═══════════════════════════════════════════════════════════════════════════╝

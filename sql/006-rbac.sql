-- ===========================================================================
-- 006 — RBAC roles + grants (Director vs Analyst)
-- ===========================================================================

USE ROLE <% ctx.env.ROLE %>;
USE WAREHOUSE <% ctx.env.WAREHOUSE %>;
USE DATABASE <% ctx.env.DATABASE %>;
USE SCHEMA <% ctx.env.SCHEMA %>;

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ SECTION 13 — RBAC (Lightweight Demo Roles)                                │
-- └───────────────────────────────────────────────────────────────────────────┘

-- Director role: agent + semantic views (no raw table access)
CREATE ROLE IF NOT EXISTS DISLOCATION_DIRECTOR_RL
  COMMENT = 'Director persona: conversational access via agent and semantic views only';

-- Analyst role: agent + semantic views + underlying tables for validation
CREATE ROLE IF NOT EXISTS DISLOCATION_ANALYST_RL
  COMMENT = 'Analyst persona: full access including underlying tables and views';

-- Grant hierarchy
GRANT ROLE DISLOCATION_DIRECTOR_RL TO ROLE SYSADMIN;
GRANT ROLE DISLOCATION_ANALYST_RL TO ROLE SYSADMIN;

-- Database and schema access
GRANT USAGE ON DATABASE <% ctx.env.DATABASE %> TO ROLE DISLOCATION_DIRECTOR_RL;
GRANT USAGE ON DATABASE <% ctx.env.DATABASE %> TO ROLE DISLOCATION_ANALYST_RL;
GRANT USAGE ON SCHEMA <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %> TO ROLE DISLOCATION_DIRECTOR_RL;
GRANT USAGE ON SCHEMA <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %> TO ROLE DISLOCATION_ANALYST_RL;
GRANT USAGE ON SCHEMA <% ctx.env.DATABASE %>.<% ctx.env.SKILLS_SCHEMA %> TO ROLE DISLOCATION_ANALYST_RL;

-- Warehouse access
GRANT USAGE ON WAREHOUSE <% ctx.env.WAREHOUSE %> TO ROLE DISLOCATION_DIRECTOR_RL;
GRANT USAGE ON WAREHOUSE <% ctx.env.WAREHOUSE %> TO ROLE DISLOCATION_ANALYST_RL;

-- Note: Semantic views inherit access from the underlying views (SELECT grants below).
-- No separate GRANT USAGE ON SEMANTIC VIEW is required.

-- Agent access (both roles)
GRANT USAGE ON AGENT <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.DISLOCATION_ANALYSIS_AGENT TO ROLE DISLOCATION_DIRECTOR_RL;
GRANT USAGE ON AGENT <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.DISLOCATION_ANALYSIS_AGENT TO ROLE DISLOCATION_ANALYST_RL;

-- View access (needed for semantic views to work)
GRANT SELECT ON VIEW <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.VW_DISLOCATION_ANALYSIS TO ROLE DISLOCATION_DIRECTOR_RL;
GRANT SELECT ON VIEW <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.VW_DISLOCATION_ANALYSIS TO ROLE DISLOCATION_ANALYST_RL;
GRANT SELECT ON VIEW <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.VW_PORTFOLIO_SUMMARY TO ROLE DISLOCATION_DIRECTOR_RL;
GRANT SELECT ON VIEW <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.VW_PORTFOLIO_SUMMARY TO ROLE DISLOCATION_ANALYST_RL;
GRANT SELECT ON VIEW <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.VW_CLAIMS_DETAIL TO ROLE DISLOCATION_DIRECTOR_RL;
GRANT SELECT ON VIEW <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.VW_CLAIMS_DETAIL TO ROLE DISLOCATION_ANALYST_RL;

-- Table access (analyst only)
GRANT SELECT ON ALL TABLES IN SCHEMA <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %> TO ROLE DISLOCATION_ANALYST_RL;

-- Stage access (analyst only — for inspecting skills)
GRANT READ ON STAGE <% ctx.env.DATABASE %>.<% ctx.env.SKILLS_SCHEMA %>.<% ctx.env.STAGE %> TO ROLE DISLOCATION_ANALYST_RL;

-- Grant to current user for demo convenience
GRANT ROLE DISLOCATION_DIRECTOR_RL TO ROLE ACCOUNTADMIN;
GRANT ROLE DISLOCATION_ANALYST_RL TO ROLE ACCOUNTADMIN;

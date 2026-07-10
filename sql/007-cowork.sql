-- ===========================================================================
-- 007 — Expose Agent in Snowflake CoWork (formerly Snowflake Intelligence)
-- ===========================================================================
--
-- Makes DISLOCATION_ANALYSIS_AGENT appear in the Snowflake CoWork business-user
-- UI at https://ai.snowflake.com (Snowsight: AI & ML » Agents).
--
-- Runs as part of ./setup.sh (numeric prefix). Idempotent: safe to re-run.
--
-- NOTE: the old SNOWFLAKE_INTELLIGENCE.AGENTS schema mechanism is deprecated;
-- the account-level CoWork object used below is the current way to curate
-- which agents are visible.

USE ROLE <% ctx.env.ROLE %>;
USE DATABASE <% ctx.env.DATABASE %>;
USE SCHEMA <% ctx.env.SCHEMA %>;
USE WAREHOUSE <% ctx.env.WAREHOUSE %>;


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ 1. Ensure the account-level CoWork object exists                          │
-- │                                                                           │
-- │  Only one CoWork object may exist per account and it must be named        │
-- │  SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT.                                   │
-- │                                                                           │
-- │  ACCOUNT-WIDE EFFECT: once this object exists, ONLY agents added to it    │
-- │  are visible in CoWork — for ALL users. IF NOT EXISTS makes this a no-op  │
-- │  when the account already has one.                                        │
-- └───────────────────────────────────────────────────────────────────────────┘

CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ 2. Add the Dislocation agent to the curated CoWork list (idempotent)      │
-- │                                                                           │
-- │  ALTER ... ADD AGENT errors if the agent is already present, so we drop   │
-- │  any existing reference first (ignoring "not present") then add it.       │
-- └───────────────────────────────────────────────────────────────────────────┘

EXECUTE IMMEDIATE $$
BEGIN
  BEGIN
    ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
      DROP AGENT <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.DISLOCATION_ANALYSIS_AGENT;
  EXCEPTION
    WHEN OTHER THEN NULL;  -- agent not yet in the object — fine
  END;

  ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
    ADD AGENT <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.DISLOCATION_ANALYSIS_AGENT;

  RETURN 'CoWork: DISLOCATION_ANALYSIS_AGENT exposed';
END;
$$;


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ 3. Let the lab personas see the curated agent list                        │
-- │                                                                           │
-- │  USAGE on the CoWork object = ability to view the list of agents in it.  │
-- │  USAGE on the agent itself + DB/SCHEMA/WAREHOUSE is already granted to    │
-- │  both roles in 006-rbac.sql.                                             │
-- └───────────────────────────────────────────────────────────────────────────┘

GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
  TO ROLE DISLOCATION_DIRECTOR_RL;
GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
  TO ROLE DISLOCATION_ANALYST_RL;

-- Or make the curated list visible to every user in the account:
-- GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
--   TO ROLE PUBLIC;


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ Verification (uncomment to inspect the curated list)                      │
-- └───────────────────────────────────────────────────────────────────────────┘

-- SHOW AGENTS IN SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ Cleanup (uncomment to remove the agent from CoWork)                       │
-- └───────────────────────────────────────────────────────────────────────────┘

-- ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
--   DROP AGENT <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.DISLOCATION_ANALYSIS_AGENT;

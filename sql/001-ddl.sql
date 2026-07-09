-- ===========================================================================
-- 001 — DDL: database, schemas, warehouse, stage, dimension + fact tables
-- ===========================================================================

USE ROLE <% ctx.env.ROLE %>;

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ SECTION 1 — Infrastructure                                                │
-- └───────────────────────────────────────────────────────────────────────────┘

CREATE DATABASE IF NOT EXISTS <% ctx.env.DATABASE %>
  COMMENT = 'Agentic analytics demo: insurance pricing dislocation analysis';

CREATE SCHEMA IF NOT EXISTS <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>
  COMMENT = 'Core schema: tables, views, semantic views, agent, procedures';

CREATE SCHEMA IF NOT EXISTS <% ctx.env.DATABASE %>.<% ctx.env.SKILLS_SCHEMA %>
  COMMENT = 'Skills schema: named stage for agent skill files';

CREATE WAREHOUSE IF NOT EXISTS <% ctx.env.WAREHOUSE %>
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'Warehouse for Dislocation Analysis demo';

USE WAREHOUSE <% ctx.env.WAREHOUSE %>;
USE SCHEMA <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>;

-- Create stage for skills
CREATE STAGE IF NOT EXISTS <% ctx.env.DATABASE %>.<% ctx.env.SKILLS_SCHEMA %>.<% ctx.env.STAGE %>
  COMMENT = 'Named stage for agent skill SKILL.md files';


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ SECTION 2 — Dimension Tables                                             │
-- └───────────────────────────────────────────────────────────────────────────┘

-- DIM_GEOGRAPHY: Florida counties + comparison states
CREATE OR REPLACE TABLE DIM_GEOGRAPHY (
    GEOGRAPHY_KEY       NUMBER(38,0) NOT NULL PRIMARY KEY,
    STATE               VARCHAR(2)   NOT NULL,
    STATE_NAME          VARCHAR(50)  NOT NULL,
    COUNTY              VARCHAR(50)  NOT NULL,
    REGION              VARCHAR(30)  NOT NULL,
    TERRITORY_CODE      VARCHAR(10),
    COASTAL_FLAG        BOOLEAN      DEFAULT FALSE,
    HAZARD_ZONE         VARCHAR(30),
    ZIP_CODE            VARCHAR(10),
    CREATED_DATE        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- DIM_SEGMENT: Insurance policy segments
CREATE OR REPLACE TABLE DIM_SEGMENT (
    SEGMENT_KEY         NUMBER(38,0) NOT NULL PRIMARY KEY,
    SEGMENT_NAME        VARCHAR(50)  NOT NULL,
    SEGMENT_DESCRIPTION VARCHAR(200),
    LINE_OF_BUSINESS    VARCHAR(50)  NOT NULL DEFAULT 'Property',
    RISK_TIER           VARCHAR(20),
    CREATED_DATE        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- DIM_POLICY: Synthetic policy book
CREATE OR REPLACE TABLE DIM_POLICY (
    POLICY_KEY          NUMBER(38,0) NOT NULL PRIMARY KEY,
    POLICY_ID           VARCHAR(20)  NOT NULL,
    SEGMENT_KEY         NUMBER(38,0) NOT NULL,
    GEOGRAPHY_KEY       NUMBER(38,0) NOT NULL,
    LINE_OF_BUSINESS    VARCHAR(50)  NOT NULL DEFAULT 'Property',
    COVERAGE_TYPE       VARCHAR(50),
    POLICY_EFFECTIVE_DATE DATE       NOT NULL,
    POLICY_EXPIRATION_DATE DATE      NOT NULL,
    POLICY_STATUS       VARCHAR(20)  DEFAULT 'ACTIVE',
    INSURED_VALUE       NUMBER(18,2),
    DEDUCTIBLE          NUMBER(18,2),
    CREATED_DATE        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- DIM_PERIL: Cause of loss / peril types
CREATE OR REPLACE TABLE DIM_PERIL (
    PERIL_KEY           NUMBER(38,0) NOT NULL PRIMARY KEY,
    PERIL_NAME          VARCHAR(50)  NOT NULL,
    PERIL_CATEGORY      VARCHAR(30)  NOT NULL,
    CAT_ELIGIBLE        BOOLEAN      DEFAULT FALSE,
    CREATED_DATE        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ SECTION 3 — Fact Tables                                                  │
-- └───────────────────────────────────────────────────────────────────────────┘

-- FACT_PREMIUM_HISTORY: Current and historical premiums by policy
CREATE OR REPLACE TABLE FACT_PREMIUM_HISTORY (
    PREMIUM_KEY         NUMBER(38,0) NOT NULL PRIMARY KEY AUTOINCREMENT,
    POLICY_KEY          NUMBER(38,0) NOT NULL,
    EFFECTIVE_DATE      DATE         NOT NULL,
    WRITTEN_PREMIUM     NUMBER(18,2) NOT NULL,
    EARNED_PREMIUM      NUMBER(18,2),
    TIV                 NUMBER(18,2),
    ANNUAL_PREMIUM      NUMBER(18,2),
    PREMIUM_PERIOD      VARCHAR(10)  DEFAULT 'ANNUAL',
    CREATED_DATE        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- FACT_RATE_SCENARIO: Proposed rate changes (the "what-if")
CREATE OR REPLACE TABLE FACT_RATE_SCENARIO (
    SCENARIO_KEY        NUMBER(38,0) NOT NULL PRIMARY KEY AUTOINCREMENT,
    SCENARIO_NAME       VARCHAR(100) NOT NULL DEFAULT '2025 Q3 Rate Filing',
    SEGMENT_KEY         NUMBER(38,0) NOT NULL,
    GEOGRAPHY_KEY       NUMBER(38,0) NOT NULL,
    PROPOSED_RATE_CHANGE_PCT NUMBER(8,4) NOT NULL,
    EFFECTIVE_DATE      DATE,
    SCENARIO_STATUS     VARCHAR(20)  DEFAULT 'PROPOSED',
    RATIONALE           VARCHAR(500),
    CREATED_DATE        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- FACT_CLAIMS: Claims history for loss ratio computation
CREATE OR REPLACE TABLE FACT_CLAIMS (
    CLAIM_KEY           NUMBER(38,0) NOT NULL PRIMARY KEY AUTOINCREMENT,
    POLICY_KEY          NUMBER(38,0) NOT NULL,
    PERIL_KEY           NUMBER(38,0) NOT NULL,
    ACCIDENT_DATE       DATE         NOT NULL,
    REPORT_DATE         DATE,
    PAID_LOSS           NUMBER(18,2) DEFAULT 0,
    CASE_RESERVE        NUMBER(18,2) DEFAULT 0,
    INCURRED_LOSS       NUMBER(18,2) DEFAULT 0,
    PAID_EXPENSE        NUMBER(18,2) DEFAULT 0,
    CLAIM_STATUS        VARCHAR(20)  DEFAULT 'OPEN',
    SEVERITY_BAND       VARCHAR(20),
    CREATED_DATE        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- FACT_RETENTION: Lapse propensity and retention metrics by segment/geography
CREATE OR REPLACE TABLE FACT_RETENTION (
    RETENTION_KEY       NUMBER(38,0) NOT NULL PRIMARY KEY AUTOINCREMENT,
    SEGMENT_KEY         NUMBER(38,0) NOT NULL,
    GEOGRAPHY_KEY       NUMBER(38,0) NOT NULL,
    MEASUREMENT_DATE    DATE         NOT NULL,
    RETENTION_RATE      NUMBER(8,4)  NOT NULL,
    LAPSE_PROPENSITY    NUMBER(8,4)  NOT NULL,
    COMPETITIVE_POSITION_INDEX NUMBER(8,4) DEFAULT 1.0,
    PRICE_SENSITIVITY_SCORE NUMBER(8,4),
    POLICIES_IN_COHORT  NUMBER(10,0),
    CREATED_DATE        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

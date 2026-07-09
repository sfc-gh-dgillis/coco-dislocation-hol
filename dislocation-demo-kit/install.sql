-- ╔═══════════════════════════════════════════════════════════════════════════╗
-- ║  DISLOCATION ANALYSIS — Agentic Analytics Demo Install                  ║
-- ╠═══════════════════════════════════════════════════════════════════════════╣
-- ║  Industry: Property & Casualty Insurance                                ║
-- ║  Use Case: Pricing Dislocation Analysis (Florida Property)              ║
-- ║  Pattern:  Semantic Views + Cortex Agent + Skills                       ║
-- ║                                                                         ║
-- ║  This script is company-agnostic and reusable across engagements.       ║
-- ║  To customize: change database name and seed data values.               ║
-- ║                                                                         ║
-- ║  PREREQUISITES:                                                         ║
-- ║    • Run as ACCOUNTADMIN (or SYSADMIN + SECURITYADMIN)                  ║
-- ║    • Cross-region inference enabled for Cortex Agent models             ║
-- ║    • Script is idempotent: safe to re-run                               ║
-- ║                                                                         ║
-- ║  COMPANION FILES:                                                       ║
-- ║    dislocation_demo_cleanup.sql  — drops everything this creates        ║
-- ║    skills/*/SKILL.md             — agent skill definitions              ║
-- ║    DEMO_RUNBOOK.md               — demo narrative and prompts           ║
-- ╚═══════════════════════════════════════════════════════════════════════════╝

USE ROLE ACCOUNTADMIN;

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ SECTION 1 — Infrastructure                                               │
-- └───────────────────────────────────────────────────────────────────────────┘

CREATE DATABASE IF NOT EXISTS DISLOCATION_DEMO
  COMMENT = 'Agentic analytics demo: insurance pricing dislocation analysis';

CREATE SCHEMA IF NOT EXISTS DISLOCATION_DEMO.CORE
  COMMENT = 'Core schema: tables, views, semantic views, agent, procedures';

CREATE SCHEMA IF NOT EXISTS DISLOCATION_DEMO.SKILLS
  COMMENT = 'Skills schema: named stage for agent skill files';

CREATE WAREHOUSE IF NOT EXISTS DISLOCATION_DEMO_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'Warehouse for Dislocation Analysis demo';

USE WAREHOUSE DISLOCATION_DEMO_WH;
USE SCHEMA DISLOCATION_DEMO.CORE;

-- Create stage for skills
CREATE STAGE IF NOT EXISTS DISLOCATION_DEMO.SKILLS.SKILL_STAGE
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


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ SECTION 4 — Seed Data: Dimensions                                        │
-- └───────────────────────────────────────────────────────────────────────────┘

-- Perils
INSERT INTO DIM_PERIL (PERIL_KEY, PERIL_NAME, PERIL_CATEGORY, CAT_ELIGIBLE) VALUES
(1, 'Hurricane/Wind', 'Weather', TRUE),
(2, 'Flood', 'Water', TRUE),
(3, 'Fire', 'Fire', FALSE),
(4, 'Lightning', 'Weather', FALSE),
(5, 'Hail', 'Weather', TRUE),
(6, 'Water Damage', 'Water', FALSE),
(7, 'Theft/Vandalism', 'Crime', FALSE),
(8, 'Liability', 'Liability', FALSE),
(9, 'Tornado', 'Weather', TRUE),
(10, 'Sinkhole', 'Earth Movement', FALSE);

-- Segments
INSERT INTO DIM_SEGMENT (SEGMENT_KEY, SEGMENT_NAME, SEGMENT_DESCRIPTION, LINE_OF_BUSINESS, RISK_TIER) VALUES
(1, 'Coastal Homeowner', 'Primary residences within 5 miles of coast', 'Property', 'High'),
(2, 'Inland Homeowner', 'Primary residences beyond 5 miles of coast', 'Property', 'Standard'),
(3, 'High-Value Home', 'Homes with TIV > $1M', 'Property', 'High'),
(4, 'Condo Unit Owner', 'Condominium unit owner policies (HO-6)', 'Property', 'Standard'),
(5, 'Rental Property', 'Landlord / dwelling fire policies', 'Property', 'Standard'),
(6, 'Mobile Home', 'Manufactured/mobile home policies', 'Property', 'Elevated'),
(7, 'Seasonal/Vacation', 'Secondary/vacation home policies', 'Property', 'Elevated'),
(8, 'New Construction', 'Homes built within last 5 years', 'Property', 'Preferred'),
(9, 'Senior Homeowner', 'Policyholders age 65+', 'Property', 'Standard'),
(10, 'Multi-Policy Bundle', 'Auto + Home bundled policyholders', 'Property', 'Preferred'),
(11, 'Flood Zone A/V', 'Properties in FEMA high-risk flood zones', 'Property', 'High'),
(12, 'Wind Mitigation Credit', 'Homes with verified wind mitigation features', 'Property', 'Preferred');

-- Geography: Florida counties with coastal/inland classification
INSERT INTO DIM_GEOGRAPHY (GEOGRAPHY_KEY, STATE, STATE_NAME, COUNTY, REGION, TERRITORY_CODE, COASTAL_FLAG, HAZARD_ZONE)
SELECT 
    ROW_NUMBER() OVER (ORDER BY county) AS GEOGRAPHY_KEY,
    'FL', 'Florida', county, region, territory_code, coastal_flag, hazard_zone
FROM (VALUES
    ('Miami-Dade',    'Southeast',  'FL-SE-01', TRUE,  'Coastal High-Risk'),
    ('Broward',       'Southeast',  'FL-SE-02', TRUE,  'Coastal High-Risk'),
    ('Palm Beach',    'Southeast',  'FL-SE-03', TRUE,  'Coastal High-Risk'),
    ('Monroe',        'Southeast',  'FL-SE-04', TRUE,  'Coastal High-Risk'),
    ('Hillsborough',  'Gulf Coast', 'FL-GC-01', TRUE,  'Coastal Moderate'),
    ('Pinellas',      'Gulf Coast', 'FL-GC-02', TRUE,  'Coastal High-Risk'),
    ('Manatee',       'Gulf Coast', 'FL-GC-03', TRUE,  'Coastal Moderate'),
    ('Sarasota',      'Gulf Coast', 'FL-GC-04', TRUE,  'Coastal Moderate'),
    ('Lee',           'Gulf Coast', 'FL-GC-05', TRUE,  'Coastal High-Risk'),
    ('Collier',       'Gulf Coast', 'FL-GC-06', TRUE,  'Coastal Moderate'),
    ('Charlotte',     'Gulf Coast', 'FL-GC-07', TRUE,  'Coastal Moderate'),
    ('Duval',         'Northeast',  'FL-NE-01', TRUE,  'Coastal Moderate'),
    ('St. Johns',     'Northeast',  'FL-NE-02', TRUE,  'Coastal Moderate'),
    ('Volusia',       'Central',    'FL-CE-01', TRUE,  'Coastal Moderate'),
    ('Brevard',       'Central',    'FL-CE-02', TRUE,  'Coastal Moderate'),
    ('Indian River',  'Central',    'FL-CE-03', TRUE,  'Coastal Moderate'),
    ('St. Lucie',     'Central',    'FL-CE-04', TRUE,  'Coastal Moderate'),
    ('Martin',        'Central',    'FL-CE-05', TRUE,  'Coastal Moderate'),
    ('Escambia',      'Panhandle',  'FL-PH-01', TRUE,  'Coastal High-Risk'),
    ('Santa Rosa',    'Panhandle',  'FL-PH-02', TRUE,  'Coastal High-Risk'),
    ('Okaloosa',      'Panhandle',  'FL-PH-03', TRUE,  'Coastal Moderate'),
    ('Bay',           'Panhandle',  'FL-PH-04', TRUE,  'Coastal High-Risk'),
    ('Gulf',          'Panhandle',  'FL-PH-05', TRUE,  'Coastal Moderate'),
    ('Franklin',      'Panhandle',  'FL-PH-06', TRUE,  'Coastal Moderate'),
    ('Wakulla',       'Panhandle',  'FL-PH-07', TRUE,  'Coastal Moderate'),
    ('Orange',        'Central',    'FL-CE-06', FALSE, 'Inland Standard'),
    ('Osceola',       'Central',    'FL-CE-07', FALSE, 'Inland Standard'),
    ('Seminole',      'Central',    'FL-CE-08', FALSE, 'Inland Standard'),
    ('Lake',          'Central',    'FL-CE-09', FALSE, 'Inland Standard'),
    ('Polk',          'Central',    'FL-CE-10', FALSE, 'Inland Standard'),
    ('Alachua',       'North Central', 'FL-NC-01', FALSE, 'Inland Standard'),
    ('Marion',        'North Central', 'FL-NC-02', FALSE, 'Inland Standard'),
    ('Leon',          'North Central', 'FL-NC-03', FALSE, 'Inland Standard'),
    ('Pasco',         'Gulf Coast', 'FL-GC-08', TRUE,  'Coastal Moderate'),
    ('Hernando',      'Gulf Coast', 'FL-GC-09', TRUE,  'Coastal Moderate'),
    ('Citrus',        'Gulf Coast', 'FL-GC-10', TRUE,  'Coastal Moderate')
) AS t(county, region, territory_code, coastal_flag, hazard_zone);

-- Add comparison states (small set for context)
INSERT INTO DIM_GEOGRAPHY (GEOGRAPHY_KEY, STATE, STATE_NAME, COUNTY, REGION, TERRITORY_CODE, COASTAL_FLAG, HAZARD_ZONE)
VALUES
(100, 'TX', 'Texas', 'Harris', 'Gulf Coast', 'TX-GC-01', TRUE, 'Coastal High-Risk'),
(101, 'TX', 'Texas', 'Galveston', 'Gulf Coast', 'TX-GC-02', TRUE, 'Coastal High-Risk'),
(102, 'TX', 'Texas', 'Dallas', 'North Texas', 'TX-NT-01', FALSE, 'Inland Standard'),
(103, 'LA', 'Louisiana', 'Orleans', 'Southeast LA', 'LA-SE-01', TRUE, 'Coastal High-Risk'),
(104, 'LA', 'Louisiana', 'Jefferson', 'Southeast LA', 'LA-SE-02', TRUE, 'Coastal High-Risk'),
(105, 'SC', 'South Carolina', 'Charleston', 'Lowcountry', 'SC-LC-01', TRUE, 'Coastal Moderate'),
(106, 'SC', 'South Carolina', 'Horry', 'Grand Strand', 'SC-GS-01', TRUE, 'Coastal Moderate'),
(107, 'GA', 'Georgia', 'Chatham', 'Coastal GA', 'GA-CG-01', TRUE, 'Coastal Moderate');


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ SECTION 5 — Seed Data: Policies (synthetic, ~5000 policies)              │
-- └───────────────────────────────────────────────────────────────────────────┘

-- Generate 5000 synthetic policies distributed across segments and geographies
INSERT INTO DIM_POLICY (POLICY_KEY, POLICY_ID, SEGMENT_KEY, GEOGRAPHY_KEY, LINE_OF_BUSINESS, 
                        COVERAGE_TYPE, POLICY_EFFECTIVE_DATE, POLICY_EXPIRATION_DATE, 
                        POLICY_STATUS, INSURED_VALUE, DEDUCTIBLE)
SELECT 
    ROW_NUMBER() OVER (ORDER BY RANDOM()) AS POLICY_KEY,
    'POL-' || LPAD(ROW_NUMBER() OVER (ORDER BY RANDOM())::VARCHAR, 7, '0') AS POLICY_ID,
    s.SEGMENT_KEY,
    g.GEOGRAPHY_KEY,
    'Property' AS LINE_OF_BUSINESS,
    CASE s.SEGMENT_KEY
        WHEN 1 THEN 'HO-3 Special Form'
        WHEN 2 THEN 'HO-3 Special Form'
        WHEN 3 THEN 'HO-5 Comprehensive'
        WHEN 4 THEN 'HO-6 Unit Owner'
        WHEN 5 THEN 'DP-3 Dwelling Fire'
        WHEN 6 THEN 'HO-7 Mobile Home'
        WHEN 7 THEN 'HO-3 Special Form'
        WHEN 8 THEN 'HO-3 Special Form'
        WHEN 9 THEN 'HO-3 Special Form'
        WHEN 10 THEN 'HO-3 Special Form'
        WHEN 11 THEN 'HO-3 Special Form'
        WHEN 12 THEN 'HO-3 Special Form'
    END AS COVERAGE_TYPE,
    DATEADD('day', -UNIFORM(0, 365, RANDOM()), '2025-01-01')::DATE AS POLICY_EFFECTIVE_DATE,
    DATEADD('year', 1, DATEADD('day', -UNIFORM(0, 365, RANDOM()), '2025-01-01'))::DATE AS POLICY_EXPIRATION_DATE,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 92 THEN 'ACTIVE' ELSE 'LAPSED' END AS POLICY_STATUS,
    CASE s.SEGMENT_KEY
        WHEN 1 THEN UNIFORM(350000, 900000, RANDOM())
        WHEN 2 THEN UNIFORM(200000, 500000, RANDOM())
        WHEN 3 THEN UNIFORM(1000000, 5000000, RANDOM())
        WHEN 4 THEN UNIFORM(100000, 400000, RANDOM())
        WHEN 5 THEN UNIFORM(150000, 600000, RANDOM())
        WHEN 6 THEN UNIFORM(50000, 200000, RANDOM())
        WHEN 7 THEN UNIFORM(400000, 1500000, RANDOM())
        WHEN 8 THEN UNIFORM(300000, 800000, RANDOM())
        WHEN 9 THEN UNIFORM(200000, 600000, RANDOM())
        WHEN 10 THEN UNIFORM(250000, 700000, RANDOM())
        WHEN 11 THEN UNIFORM(250000, 750000, RANDOM())
        WHEN 12 THEN UNIFORM(250000, 650000, RANDOM())
    END AS INSURED_VALUE,
    CASE 
        WHEN s.RISK_TIER = 'High' THEN UNIFORM(2500, 10000, RANDOM())
        WHEN s.RISK_TIER = 'Elevated' THEN UNIFORM(1500, 5000, RANDOM())
        ELSE UNIFORM(1000, 2500, RANDOM())
    END AS DEDUCTIBLE
FROM (
    -- Generate rows using a generator, then cross join with segments and geographies
    SELECT SEQ4() AS row_num
    FROM TABLE(GENERATOR(ROWCOUNT => 5000))
) gen
JOIN DIM_SEGMENT s ON s.SEGMENT_KEY = (MOD(gen.row_num, 12) + 1)
JOIN DIM_GEOGRAPHY g ON g.GEOGRAPHY_KEY = (MOD(gen.row_num, 36) + 1)  -- FL geographies only
;


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ SECTION 6 — Seed Data: Premium History                                   │
-- └───────────────────────────────────────────────────────────────────────────┘

INSERT INTO FACT_PREMIUM_HISTORY (POLICY_KEY, EFFECTIVE_DATE, WRITTEN_PREMIUM, EARNED_PREMIUM, TIV, ANNUAL_PREMIUM)
SELECT 
    p.POLICY_KEY,
    p.POLICY_EFFECTIVE_DATE AS EFFECTIVE_DATE,
    -- Base premium varies by segment and TIV
    ROUND(p.INSURED_VALUE * 
        CASE s.SEGMENT_KEY
            WHEN 1 THEN UNIFORM(0.008, 0.018, RANDOM())  -- Coastal: expensive
            WHEN 2 THEN UNIFORM(0.004, 0.008, RANDOM())  -- Inland: moderate
            WHEN 3 THEN UNIFORM(0.006, 0.012, RANDOM())  -- High-value
            WHEN 4 THEN UNIFORM(0.003, 0.006, RANDOM())  -- Condo
            WHEN 5 THEN UNIFORM(0.005, 0.010, RANDOM())  -- Rental
            WHEN 6 THEN UNIFORM(0.010, 0.022, RANDOM())  -- Mobile
            WHEN 7 THEN UNIFORM(0.007, 0.015, RANDOM())  -- Seasonal
            WHEN 8 THEN UNIFORM(0.003, 0.006, RANDOM())  -- New construction
            WHEN 9 THEN UNIFORM(0.005, 0.009, RANDOM())  -- Senior
            WHEN 10 THEN UNIFORM(0.004, 0.007, RANDOM()) -- Bundle
            WHEN 11 THEN UNIFORM(0.012, 0.025, RANDOM()) -- Flood zone
            WHEN 12 THEN UNIFORM(0.003, 0.006, RANDOM()) -- Wind mitigation
        END, 2) AS WRITTEN_PREMIUM,
    NULL AS EARNED_PREMIUM,  -- Will be computed
    p.INSURED_VALUE AS TIV,
    NULL AS ANNUAL_PREMIUM
FROM DIM_POLICY p
JOIN DIM_SEGMENT s ON p.SEGMENT_KEY = s.SEGMENT_KEY;

-- Backfill earned premium (assume fully earned for simplicity)
UPDATE FACT_PREMIUM_HISTORY SET 
    EARNED_PREMIUM = WRITTEN_PREMIUM,
    ANNUAL_PREMIUM = WRITTEN_PREMIUM;


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ SECTION 7 — Seed Data: Rate Scenario (Proposed Rate Changes)             │
-- └───────────────────────────────────────────────────────────────────────────┘

-- The scenario: proposed rate increases that vary by segment and geography
-- This creates the "dislocation" — some segments get hit much harder than others
INSERT INTO FACT_RATE_SCENARIO (SCENARIO_NAME, SEGMENT_KEY, GEOGRAPHY_KEY, PROPOSED_RATE_CHANGE_PCT, EFFECTIVE_DATE, RATIONALE)
SELECT 
    '2025 Q3 Rate Filing' AS SCENARIO_NAME,
    s.SEGMENT_KEY,
    g.GEOGRAPHY_KEY,
    -- Rate changes that create meaningful dislocation patterns
    CASE 
        -- Coastal segments in high-risk zones get largest increases
        WHEN s.SEGMENT_KEY = 1 AND g.HAZARD_ZONE = 'Coastal High-Risk' THEN UNIFORM(18.0, 35.0, RANDOM())
        WHEN s.SEGMENT_KEY = 1 AND g.HAZARD_ZONE = 'Coastal Moderate' THEN UNIFORM(12.0, 22.0, RANDOM())
        -- Flood zone properties hammered
        WHEN s.SEGMENT_KEY = 11 THEN UNIFORM(22.0, 45.0, RANDOM())
        -- Mobile homes in coastal areas
        WHEN s.SEGMENT_KEY = 6 AND g.COASTAL_FLAG = TRUE THEN UNIFORM(15.0, 30.0, RANDOM())
        -- High-value homes coastal
        WHEN s.SEGMENT_KEY = 3 AND g.COASTAL_FLAG = TRUE THEN UNIFORM(14.0, 28.0, RANDOM())
        -- Seasonal/vacation coastal
        WHEN s.SEGMENT_KEY = 7 AND g.COASTAL_FLAG = TRUE THEN UNIFORM(16.0, 32.0, RANDOM())
        -- Inland segments get moderate increases
        WHEN g.COASTAL_FLAG = FALSE THEN UNIFORM(3.0, 9.0, RANDOM())
        -- New construction and wind mitigation get smallest increases (good risk)
        WHEN s.SEGMENT_KEY IN (8, 12) THEN UNIFORM(2.0, 6.0, RANDOM())
        -- Bundle discount policyholders — moderate
        WHEN s.SEGMENT_KEY = 10 THEN UNIFORM(5.0, 12.0, RANDOM())
        -- Default coastal
        ELSE UNIFORM(8.0, 18.0, RANDOM())
    END AS PROPOSED_RATE_CHANGE_PCT,
    '2025-07-01'::DATE AS EFFECTIVE_DATE,
    CASE 
        WHEN s.SEGMENT_KEY IN (1, 11) AND g.HAZARD_ZONE = 'Coastal High-Risk' 
            THEN 'CAT loss experience and reinsurance cost increases require significant rate correction'
        WHEN s.SEGMENT_KEY = 6 THEN 'Elevated severity trends and construction vulnerability'
        WHEN g.COASTAL_FLAG = FALSE THEN 'Modest adjustment for inflation and loss trend'
        ELSE 'Rate adequacy correction based on loss experience'
    END AS RATIONALE
FROM DIM_SEGMENT s
CROSS JOIN DIM_GEOGRAPHY g
WHERE g.STATE = 'FL';  -- Florida focus for the scenario


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ SECTION 8 — Seed Data: Claims History                                    │
-- └───────────────────────────────────────────────────────────────────────────┘

-- Generate ~8000 claims over the past 3 years
INSERT INTO FACT_CLAIMS (POLICY_KEY, PERIL_KEY, ACCIDENT_DATE, REPORT_DATE, 
                         PAID_LOSS, CASE_RESERVE, INCURRED_LOSS, PAID_EXPENSE,
                         CLAIM_STATUS, SEVERITY_BAND)
SELECT 
    p.POLICY_KEY,
    -- Peril distribution weighted toward wind/water in FL
    CASE 
        WHEN UNIFORM(1, 100, RANDOM()) <= 35 THEN 1  -- Hurricane/Wind
        WHEN UNIFORM(1, 100, RANDOM()) <= 55 THEN 6  -- Water Damage
        WHEN UNIFORM(1, 100, RANDOM()) <= 70 THEN 2  -- Flood
        WHEN UNIFORM(1, 100, RANDOM()) <= 80 THEN 3  -- Fire
        WHEN UNIFORM(1, 100, RANDOM()) <= 88 THEN 4  -- Lightning
        WHEN UNIFORM(1, 100, RANDOM()) <= 93 THEN 7  -- Theft
        WHEN UNIFORM(1, 100, RANDOM()) <= 96 THEN 5  -- Hail
        WHEN UNIFORM(1, 100, RANDOM()) <= 98 THEN 8  -- Liability
        ELSE 10  -- Sinkhole
    END AS PERIL_KEY,
    DATEADD('day', -UNIFORM(1, 1095, RANDOM()), CURRENT_DATE())::DATE AS ACCIDENT_DATE,
    DATEADD('day', UNIFORM(0, 14, RANDOM()), DATEADD('day', -UNIFORM(1, 1095, RANDOM()), CURRENT_DATE()))::DATE AS REPORT_DATE,
    -- Severity varies by segment risk tier
    ROUND(CASE s.RISK_TIER
        WHEN 'High' THEN UNIFORM(5000, 250000, RANDOM())
        WHEN 'Elevated' THEN UNIFORM(3000, 150000, RANDOM())
        WHEN 'Standard' THEN UNIFORM(2000, 80000, RANDOM())
        ELSE UNIFORM(1000, 50000, RANDOM())
    END, 2) AS PAID_LOSS,
    ROUND(UNIFORM(0, 50000, RANDOM()), 2) AS CASE_RESERVE,
    0 AS INCURRED_LOSS,  -- Will be computed
    ROUND(UNIFORM(500, 15000, RANDOM()), 2) AS PAID_EXPENSE,
    CASE 
        WHEN UNIFORM(1, 100, RANDOM()) <= 65 THEN 'CLOSED'
        WHEN UNIFORM(1, 100, RANDOM()) <= 90 THEN 'OPEN'
        ELSE 'SUBROGATION'
    END AS CLAIM_STATUS,
    CASE 
        WHEN UNIFORM(1, 100, RANDOM()) <= 50 THEN 'Small'
        WHEN UNIFORM(1, 100, RANDOM()) <= 80 THEN 'Medium'
        WHEN UNIFORM(1, 100, RANDOM()) <= 95 THEN 'Large'
        ELSE 'Catastrophic'
    END AS SEVERITY_BAND
FROM DIM_POLICY p
JOIN DIM_SEGMENT s ON p.SEGMENT_KEY = s.SEGMENT_KEY
JOIN TABLE(GENERATOR(ROWCOUNT => 8000)) gen
WHERE MOD(gen.SEQ4(), (SELECT COUNT(*) FROM DIM_POLICY)) + 1 = p.POLICY_KEY
  AND gen.SEQ4() < 8000;

-- If the above generator approach yields fewer rows, supplement with a simpler approach
INSERT INTO FACT_CLAIMS (POLICY_KEY, PERIL_KEY, ACCIDENT_DATE, REPORT_DATE, 
                         PAID_LOSS, CASE_RESERVE, INCURRED_LOSS, PAID_EXPENSE,
                         CLAIM_STATUS, SEVERITY_BAND)
SELECT 
    UNIFORM(1, 5000, RANDOM()) AS POLICY_KEY,
    CASE MOD(SEQ4(), 10) + 1
        WHEN 1 THEN 1 WHEN 2 THEN 1 WHEN 3 THEN 1  -- 30% wind
        WHEN 4 THEN 6 WHEN 5 THEN 6                  -- 20% water damage
        WHEN 6 THEN 2 WHEN 7 THEN 2                  -- 20% flood
        WHEN 8 THEN 3                                  -- 10% fire
        WHEN 9 THEN 5                                  -- 10% hail
        ELSE 7                                         -- 10% theft
    END AS PERIL_KEY,
    DATEADD('day', -UNIFORM(1, 1095, RANDOM()), CURRENT_DATE())::DATE AS ACCIDENT_DATE,
    DATEADD('day', UNIFORM(1, 30, RANDOM()), DATEADD('day', -UNIFORM(1, 1095, RANDOM()), CURRENT_DATE()))::DATE AS REPORT_DATE,
    ROUND(UNIFORM(2000, 200000, RANDOM()), 2) AS PAID_LOSS,
    ROUND(UNIFORM(0, 75000, RANDOM()), 2) AS CASE_RESERVE,
    0 AS INCURRED_LOSS,
    ROUND(UNIFORM(500, 12000, RANDOM()), 2) AS PAID_EXPENSE,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 60 THEN 'CLOSED' ELSE 'OPEN' END AS CLAIM_STATUS,
    CASE 
        WHEN UNIFORM(1,100,RANDOM()) <= 45 THEN 'Small'
        WHEN UNIFORM(1,100,RANDOM()) <= 78 THEN 'Medium'
        WHEN UNIFORM(1,100,RANDOM()) <= 94 THEN 'Large'
        ELSE 'Catastrophic'
    END AS SEVERITY_BAND
FROM TABLE(GENERATOR(ROWCOUNT => 8000));

-- Compute incurred loss
UPDATE FACT_CLAIMS SET INCURRED_LOSS = PAID_LOSS + CASE_RESERVE;


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ SECTION 9 — Seed Data: Retention Metrics                                 │
-- └───────────────────────────────────────────────────────────────────────────┘

-- Retention rates and lapse propensity by segment/geography
-- Key insight: segments with high rate increases have elevated lapse risk
INSERT INTO FACT_RETENTION (SEGMENT_KEY, GEOGRAPHY_KEY, MEASUREMENT_DATE, 
                            RETENTION_RATE, LAPSE_PROPENSITY, COMPETITIVE_POSITION_INDEX,
                            PRICE_SENSITIVITY_SCORE, POLICIES_IN_COHORT)
SELECT 
    s.SEGMENT_KEY,
    g.GEOGRAPHY_KEY,
    '2025-03-31'::DATE AS MEASUREMENT_DATE,
    -- Retention rate (inverse relationship with expected rate increase)
    CASE 
        WHEN s.SEGMENT_KEY = 1 AND g.HAZARD_ZONE = 'Coastal High-Risk' THEN UNIFORM(0.72, 0.82, RANDOM())
        WHEN s.SEGMENT_KEY = 11 THEN UNIFORM(0.68, 0.78, RANDOM())
        WHEN s.SEGMENT_KEY = 6 AND g.COASTAL_FLAG = TRUE THEN UNIFORM(0.70, 0.80, RANDOM())
        WHEN s.SEGMENT_KEY IN (8, 12) THEN UNIFORM(0.90, 0.96, RANDOM())
        WHEN s.SEGMENT_KEY = 10 THEN UNIFORM(0.88, 0.94, RANDOM())
        WHEN g.COASTAL_FLAG = FALSE THEN UNIFORM(0.85, 0.93, RANDOM())
        ELSE UNIFORM(0.78, 0.88, RANDOM())
    END AS RETENTION_RATE,
    -- Lapse propensity (higher = more likely to leave)
    CASE 
        WHEN s.SEGMENT_KEY = 1 AND g.HAZARD_ZONE = 'Coastal High-Risk' THEN UNIFORM(0.22, 0.38, RANDOM())
        WHEN s.SEGMENT_KEY = 11 THEN UNIFORM(0.28, 0.42, RANDOM())
        WHEN s.SEGMENT_KEY = 6 AND g.COASTAL_FLAG = TRUE THEN UNIFORM(0.25, 0.38, RANDOM())
        WHEN s.SEGMENT_KEY = 7 AND g.COASTAL_FLAG = TRUE THEN UNIFORM(0.20, 0.35, RANDOM())
        WHEN s.SEGMENT_KEY IN (8, 12) THEN UNIFORM(0.05, 0.12, RANDOM())
        WHEN s.SEGMENT_KEY = 10 THEN UNIFORM(0.06, 0.14, RANDOM())
        WHEN g.COASTAL_FLAG = FALSE THEN UNIFORM(0.08, 0.18, RANDOM())
        ELSE UNIFORM(0.15, 0.28, RANDOM())
    END AS LAPSE_PROPENSITY,
    -- Competitive position (< 1 means we're more expensive than market)
    CASE 
        WHEN s.SEGMENT_KEY IN (1, 11) AND g.HAZARD_ZONE = 'Coastal High-Risk' THEN UNIFORM(0.75, 0.92, RANDOM())
        WHEN s.SEGMENT_KEY = 6 THEN UNIFORM(0.80, 0.95, RANDOM())
        WHEN s.SEGMENT_KEY IN (8, 12) THEN UNIFORM(1.02, 1.15, RANDOM())
        ELSE UNIFORM(0.90, 1.08, RANDOM())
    END AS COMPETITIVE_POSITION_INDEX,
    -- Price sensitivity (higher = more sensitive to increases)
    CASE 
        WHEN s.SEGMENT_KEY IN (6, 9) THEN UNIFORM(0.75, 0.95, RANDOM())  -- Mobile/Senior very sensitive
        WHEN s.SEGMENT_KEY = 3 THEN UNIFORM(0.30, 0.55, RANDOM())        -- High-value less sensitive
        WHEN s.SEGMENT_KEY = 10 THEN UNIFORM(0.40, 0.60, RANDOM())       -- Bundle has switching cost
        ELSE UNIFORM(0.50, 0.80, RANDOM())
    END AS PRICE_SENSITIVITY_SCORE,
    UNIFORM(50, 500, RANDOM()) AS POLICIES_IN_COHORT
FROM DIM_SEGMENT s
CROSS JOIN DIM_GEOGRAPHY g
WHERE g.STATE = 'FL';


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ SECTION 10 — Adapter Views (Stable Semantic Contract Layer)              │
-- └───────────────────────────────────────────────────────────────────────────┘

-- Primary dislocation analysis view — the agent's main data surface
CREATE OR REPLACE VIEW VW_DISLOCATION_ANALYSIS AS
WITH premium_base AS (
    SELECT 
        p.POLICY_KEY,
        p.SEGMENT_KEY,
        p.GEOGRAPHY_KEY,
        ph.WRITTEN_PREMIUM AS CURRENT_PREMIUM,
        ph.TIV
    FROM DIM_POLICY p
    JOIN FACT_PREMIUM_HISTORY ph ON p.POLICY_KEY = ph.POLICY_KEY
    WHERE p.POLICY_STATUS = 'ACTIVE'
),
scenario_rates AS (
    SELECT 
        SEGMENT_KEY,
        GEOGRAPHY_KEY,
        SCENARIO_NAME,
        PROPOSED_RATE_CHANGE_PCT,
        RATIONALE
    FROM FACT_RATE_SCENARIO
),
claims_summary AS (
    SELECT 
        fc.POLICY_KEY,
        COUNT(*) AS CLAIM_COUNT,
        SUM(fc.INCURRED_LOSS) AS TOTAL_INCURRED,
        AVG(fc.INCURRED_LOSS) AS AVG_SEVERITY
    FROM FACT_CLAIMS fc
    WHERE fc.ACCIDENT_DATE >= DATEADD('year', -2, CURRENT_DATE())
    GROUP BY fc.POLICY_KEY
),
retention_data AS (
    SELECT 
        SEGMENT_KEY,
        GEOGRAPHY_KEY,
        RETENTION_RATE,
        LAPSE_PROPENSITY,
        COMPETITIVE_POSITION_INDEX,
        PRICE_SENSITIVITY_SCORE,
        POLICIES_IN_COHORT
    FROM FACT_RETENTION
)
SELECT 
    -- Dimensions
    g.STATE,
    g.STATE_NAME,
    g.COUNTY,
    g.REGION,
    g.TERRITORY_CODE,
    g.COASTAL_FLAG,
    g.HAZARD_ZONE,
    s.SEGMENT_NAME,
    s.SEGMENT_DESCRIPTION,
    s.LINE_OF_BUSINESS,
    s.RISK_TIER,
    sr.SCENARIO_NAME,
    
    -- Premium Metrics
    SUM(pb.CURRENT_PREMIUM) AS CURRENT_PREMIUM,
    SUM(pb.CURRENT_PREMIUM * (1 + sr.PROPOSED_RATE_CHANGE_PCT / 100)) AS PROPOSED_PREMIUM,
    SUM(pb.CURRENT_PREMIUM * sr.PROPOSED_RATE_CHANGE_PCT / 100) AS PREMIUM_DELTA,
    AVG(sr.PROPOSED_RATE_CHANGE_PCT) AS AVG_RATE_CHANGE_PCT,
    SUM(pb.TIV) AS TOTAL_TIV,
    
    -- Loss Metrics
    COALESCE(SUM(cs.TOTAL_INCURRED), 0) AS TOTAL_INCURRED_LOSS,
    COALESCE(SUM(cs.CLAIM_COUNT), 0) AS CLAIM_COUNT,
    CASE WHEN SUM(pb.CURRENT_PREMIUM) > 0 
        THEN COALESCE(SUM(cs.TOTAL_INCURRED), 0) / SUM(pb.CURRENT_PREMIUM)
        ELSE 0 
    END AS LOSS_RATIO,
    CASE WHEN COUNT(DISTINCT pb.POLICY_KEY) > 0
        THEN COALESCE(SUM(cs.CLAIM_COUNT), 0)::FLOAT / COUNT(DISTINCT pb.POLICY_KEY)
        ELSE 0
    END AS CLAIM_FREQUENCY,
    CASE WHEN COALESCE(SUM(cs.CLAIM_COUNT), 0) > 0
        THEN COALESCE(SUM(cs.TOTAL_INCURRED), 0) / SUM(cs.CLAIM_COUNT)
        ELSE 0
    END AS CLAIM_SEVERITY,
    
    -- Retention Metrics
    AVG(rd.RETENTION_RATE) AS RETENTION_RATE,
    AVG(rd.LAPSE_PROPENSITY) AS LAPSE_PROPENSITY,
    AVG(rd.COMPETITIVE_POSITION_INDEX) AS COMPETITIVE_POSITION_INDEX,
    AVG(rd.PRICE_SENSITIVITY_SCORE) AS PRICE_SENSITIVITY_SCORE,
    
    -- Volume
    COUNT(DISTINCT pb.POLICY_KEY) AS POLICY_COUNT,
    SUM(rd.POLICIES_IN_COHORT) AS COHORT_SIZE,
    
    -- Dislocation Score (weighted composite)
    -- Premium change % (0.35) + Lapse propensity (0.25) + Loss ratio (0.20) + 
    -- Concentration (0.10) + Competitive disadvantage (0.10)
    ROUND(
        (LEAST(AVG(sr.PROPOSED_RATE_CHANGE_PCT) / 45.0, 1.0) * 0.35) +  -- Normalize rate change to 0-1 (45% = max)
        (AVG(rd.LAPSE_PROPENSITY) * 0.25) +                              -- Already 0-1
        (LEAST(CASE WHEN SUM(pb.CURRENT_PREMIUM) > 0 
            THEN COALESCE(SUM(cs.TOTAL_INCURRED), 0) / SUM(pb.CURRENT_PREMIUM)
            ELSE 0 END, 1.0) * 0.20) +                                   -- Normalize loss ratio
        (LEAST(COUNT(DISTINCT pb.POLICY_KEY)::FLOAT / 500.0, 1.0) * 0.10) + -- Concentration proxy
        (LEAST((1.0 - COALESCE(AVG(rd.COMPETITIVE_POSITION_INDEX), 1.0)) + 0.5, 1.0) * 0.10) -- Competitive disadvantage
    , 4) AS DISLOCATION_SCORE,
    
    -- Severity Band
    CASE 
        WHEN (LEAST(AVG(sr.PROPOSED_RATE_CHANGE_PCT) / 45.0, 1.0) * 0.35) +
             (AVG(rd.LAPSE_PROPENSITY) * 0.25) +
             (LEAST(CASE WHEN SUM(pb.CURRENT_PREMIUM) > 0 
                THEN COALESCE(SUM(cs.TOTAL_INCURRED), 0) / SUM(pb.CURRENT_PREMIUM)
                ELSE 0 END, 1.0) * 0.20) +
             (LEAST(COUNT(DISTINCT pb.POLICY_KEY)::FLOAT / 500.0, 1.0) * 0.10) +
             (LEAST((1.0 - COALESCE(AVG(rd.COMPETITIVE_POSITION_INDEX), 1.0)) + 0.5, 1.0) * 0.10)
             >= 0.55 THEN 'CRITICAL'
        WHEN (LEAST(AVG(sr.PROPOSED_RATE_CHANGE_PCT) / 45.0, 1.0) * 0.35) +
             (AVG(rd.LAPSE_PROPENSITY) * 0.25) +
             (LEAST(CASE WHEN SUM(pb.CURRENT_PREMIUM) > 0 
                THEN COALESCE(SUM(cs.TOTAL_INCURRED), 0) / SUM(pb.CURRENT_PREMIUM)
                ELSE 0 END, 1.0) * 0.20) +
             (LEAST(COUNT(DISTINCT pb.POLICY_KEY)::FLOAT / 500.0, 1.0) * 0.10) +
             (LEAST((1.0 - COALESCE(AVG(rd.COMPETITIVE_POSITION_INDEX), 1.0)) + 0.5, 1.0) * 0.10)
             >= 0.40 THEN 'HIGH'
        WHEN (LEAST(AVG(sr.PROPOSED_RATE_CHANGE_PCT) / 45.0, 1.0) * 0.35) +
             (AVG(rd.LAPSE_PROPENSITY) * 0.25) +
             (LEAST(CASE WHEN SUM(pb.CURRENT_PREMIUM) > 0 
                THEN COALESCE(SUM(cs.TOTAL_INCURRED), 0) / SUM(pb.CURRENT_PREMIUM)
                ELSE 0 END, 1.0) * 0.20) +
             (LEAST(COUNT(DISTINCT pb.POLICY_KEY)::FLOAT / 500.0, 1.0) * 0.10) +
             (LEAST((1.0 - COALESCE(AVG(rd.COMPETITIVE_POSITION_INDEX), 1.0)) + 0.5, 1.0) * 0.10)
             >= 0.25 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS DISLOCATION_SEVERITY,
    
    -- Driver columns for explainability
    sr.RATIONALE AS RATE_CHANGE_RATIONALE,
    ROUND(LEAST(AVG(sr.PROPOSED_RATE_CHANGE_PCT) / 45.0, 1.0) * 0.35, 4) AS DRIVER_RATE_CHANGE,
    ROUND(AVG(rd.LAPSE_PROPENSITY) * 0.25, 4) AS DRIVER_LAPSE_RISK,
    ROUND(LEAST(CASE WHEN SUM(pb.CURRENT_PREMIUM) > 0 
        THEN COALESCE(SUM(cs.TOTAL_INCURRED), 0) / SUM(pb.CURRENT_PREMIUM)
        ELSE 0 END, 1.0) * 0.20, 4) AS DRIVER_LOSS_EXPERIENCE,
    ROUND(LEAST(COUNT(DISTINCT pb.POLICY_KEY)::FLOAT / 500.0, 1.0) * 0.10, 4) AS DRIVER_CONCENTRATION,
    ROUND(LEAST((1.0 - COALESCE(AVG(rd.COMPETITIVE_POSITION_INDEX), 1.0)) + 0.5, 1.0) * 0.10, 4) AS DRIVER_COMPETITIVE_POSITION

FROM premium_base pb
JOIN DIM_SEGMENT s ON pb.SEGMENT_KEY = s.SEGMENT_KEY
JOIN DIM_GEOGRAPHY g ON pb.GEOGRAPHY_KEY = g.GEOGRAPHY_KEY
JOIN scenario_rates sr ON pb.SEGMENT_KEY = sr.SEGMENT_KEY AND pb.GEOGRAPHY_KEY = sr.GEOGRAPHY_KEY
LEFT JOIN claims_summary cs ON pb.POLICY_KEY = cs.POLICY_KEY
LEFT JOIN retention_data rd ON pb.SEGMENT_KEY = rd.SEGMENT_KEY AND pb.GEOGRAPHY_KEY = rd.GEOGRAPHY_KEY
GROUP BY 
    g.STATE, g.STATE_NAME, g.COUNTY, g.REGION, g.TERRITORY_CODE, 
    g.COASTAL_FLAG, g.HAZARD_ZONE,
    s.SEGMENT_NAME, s.SEGMENT_DESCRIPTION, s.LINE_OF_BUSINESS, s.RISK_TIER,
    sr.SCENARIO_NAME, sr.RATIONALE;


-- Portfolio summary view (supporting context)
CREATE OR REPLACE VIEW VW_PORTFOLIO_SUMMARY AS
SELECT 
    g.STATE,
    g.STATE_NAME,
    g.REGION,
    g.COASTAL_FLAG,
    s.SEGMENT_NAME,
    s.LINE_OF_BUSINESS,
    s.RISK_TIER,
    COUNT(DISTINCT p.POLICY_KEY) AS POLICY_COUNT,
    SUM(ph.WRITTEN_PREMIUM) AS TOTAL_WRITTEN_PREMIUM,
    SUM(ph.TIV) AS TOTAL_TIV,
    AVG(ph.WRITTEN_PREMIUM) AS AVG_PREMIUM,
    SUM(CASE WHEN p.POLICY_STATUS = 'ACTIVE' THEN 1 ELSE 0 END) AS ACTIVE_POLICIES,
    SUM(CASE WHEN p.POLICY_STATUS = 'LAPSED' THEN 1 ELSE 0 END) AS LAPSED_POLICIES,
    ROUND(SUM(CASE WHEN p.POLICY_STATUS = 'ACTIVE' THEN 1 ELSE 0 END)::FLOAT / 
          NULLIF(COUNT(DISTINCT p.POLICY_KEY), 0) * 100, 2) AS ACTIVE_RATE_PCT
FROM DIM_POLICY p
JOIN DIM_SEGMENT s ON p.SEGMENT_KEY = s.SEGMENT_KEY
JOIN DIM_GEOGRAPHY g ON p.GEOGRAPHY_KEY = g.GEOGRAPHY_KEY
JOIN FACT_PREMIUM_HISTORY ph ON p.POLICY_KEY = ph.POLICY_KEY
GROUP BY g.STATE, g.STATE_NAME, g.REGION, g.COASTAL_FLAG,
         s.SEGMENT_NAME, s.LINE_OF_BUSINESS, s.RISK_TIER;


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ SECTION 11 — Semantic Views                                              │
-- └───────────────────────────────────────────────────────────────────────────┘

-- Primary semantic view: Dislocation Analysis
CREATE OR REPLACE SEMANTIC VIEW SV_DISLOCATION
  TABLES (
    DA AS DISLOCATION_DEMO.CORE.VW_DISLOCATION_ANALYSIS
  )
  DIMENSIONS (
    DA.STATE AS DA.STATE
      COMMENT = 'Two-letter state code (FL, TX, LA, SC, GA)',
    DA.STATE_NAME AS DA.STATE_NAME
      COMMENT = 'Full state name',
    DA.COUNTY AS DA.COUNTY
      COMMENT = 'County name within state',
    DA.REGION AS DA.REGION
      COMMENT = 'Geographic region (Southeast, Gulf Coast, Panhandle, Central, etc.)',
    DA.COASTAL_FLAG AS DA.COASTAL_FLAG
      COMMENT = 'TRUE if property is within 5 miles of coast',
    DA.HAZARD_ZONE AS DA.HAZARD_ZONE
      COMMENT = 'Risk zone classification: Coastal High-Risk, Coastal Moderate, Inland Standard',
    DA.SEGMENT_NAME AS DA.SEGMENT_NAME
      COMMENT = 'Insurance segment: Coastal Homeowner, Inland Homeowner, High-Value Home, Condo, Rental, Mobile Home, Seasonal, etc.',
    DA.LINE_OF_BUSINESS AS DA.LINE_OF_BUSINESS
      COMMENT = 'Line of business (Property for this demo)',
    DA.RISK_TIER AS DA.RISK_TIER
      COMMENT = 'Risk classification: High, Elevated, Standard, Preferred',
    DA.SCENARIO_NAME AS DA.SCENARIO_NAME
      COMMENT = 'Rate filing scenario name (e.g. 2025 Q3 Rate Filing)',
    DA.DISLOCATION_SEVERITY AS DA.DISLOCATION_SEVERITY
      COMMENT = 'Severity band: CRITICAL (>=0.55), HIGH (>=0.40), MEDIUM (>=0.25), LOW (<0.25)',
    DA.RATE_CHANGE_RATIONALE AS DA.RATE_CHANGE_RATIONALE
      COMMENT = 'Business rationale for the proposed rate change'
  )
  METRICS (
    DA.CURRENT_PREMIUM AS SUM(DA.CURRENT_PREMIUM)
      COMMENT = 'Total current annual written premium for the segment/geography',
    DA.PROPOSED_PREMIUM AS SUM(DA.PROPOSED_PREMIUM)
      COMMENT = 'Total projected premium after proposed rate change',
    DA.PREMIUM_DELTA AS SUM(DA.PREMIUM_DELTA)
      COMMENT = 'Dollar difference between proposed and current premium',
    DA.AVG_RATE_CHANGE_PCT AS AVG(DA.AVG_RATE_CHANGE_PCT)
      COMMENT = 'Average proposed rate change percentage for the cohort',
    DA.TOTAL_TIV AS SUM(DA.TOTAL_TIV)
      COMMENT = 'Total insured value across all policies in cohort',
    DA.TOTAL_INCURRED_LOSS AS SUM(DA.TOTAL_INCURRED_LOSS)
      COMMENT = 'Total incurred losses (paid + reserves) over trailing 2 years',
    DA.CLAIM_COUNT AS SUM(DA.CLAIM_COUNT)
      COMMENT = 'Number of claims in trailing 2-year window',
    DA.LOSS_RATIO AS DA.TOTAL_INCURRED_LOSS / NULLIF(DA.CURRENT_PREMIUM, 0)
      COMMENT = 'Loss ratio: incurred loss divided by earned premium',
    DA.CLAIM_FREQUENCY AS AVG(DA.CLAIM_FREQUENCY)
      COMMENT = 'Claims per policy (frequency)',
    DA.CLAIM_SEVERITY AS AVG(DA.CLAIM_SEVERITY)
      COMMENT = 'Average cost per claim (severity)',
    DA.RETENTION_RATE AS AVG(DA.RETENTION_RATE)
      COMMENT = 'Historical retention rate for the cohort (0-1 scale, 1 = all retained)',
    DA.LAPSE_PROPENSITY AS AVG(DA.LAPSE_PROPENSITY)
      COMMENT = 'Predicted probability of policy non-renewal (0-1 scale, higher = more likely to lapse)',
    DA.COMPETITIVE_POSITION_INDEX AS AVG(DA.COMPETITIVE_POSITION_INDEX)
      COMMENT = 'Market competitiveness index (< 1.0 = more expensive than market, > 1.0 = cheaper)',
    DA.PRICE_SENSITIVITY_SCORE AS AVG(DA.PRICE_SENSITIVITY_SCORE)
      COMMENT = 'Price elasticity score (0-1, higher = more price sensitive)',
    DA.POLICY_COUNT AS SUM(DA.POLICY_COUNT)
      COMMENT = 'Number of policies in the segment/geography cohort',
    DA.DISLOCATION_SCORE AS AVG(DA.DISLOCATION_SCORE)
      COMMENT = 'Composite dislocation risk score (0-1 scale). Weights: rate change 35%, lapse risk 25%, loss ratio 20%, concentration 10%, competitive position 10%',
    DA.DRIVER_RATE_CHANGE AS AVG(DA.DRIVER_RATE_CHANGE)
      COMMENT = 'Dislocation score component: contribution from rate change magnitude (max 0.35)',
    DA.DRIVER_LAPSE_RISK AS AVG(DA.DRIVER_LAPSE_RISK)
      COMMENT = 'Dislocation score component: contribution from lapse/retention risk (max 0.25)',
    DA.DRIVER_LOSS_EXPERIENCE AS AVG(DA.DRIVER_LOSS_EXPERIENCE)
      COMMENT = 'Dislocation score component: contribution from loss ratio (max 0.20)',
    DA.DRIVER_CONCENTRATION AS AVG(DA.DRIVER_CONCENTRATION)
      COMMENT = 'Dislocation score component: contribution from portfolio concentration (max 0.10)',
    DA.DRIVER_COMPETITIVE_POSITION AS AVG(DA.DRIVER_COMPETITIVE_POSITION)
      COMMENT = 'Dislocation score component: contribution from competitive disadvantage (max 0.10)'
  )
  COMMENT = 'Dislocation analysis: identifies where proposed pricing changes create the highest risk of adverse customer, retention, and profitability outcomes. Use this view for all pricing dislocation questions including segment risk, geographic hotspots, retention sensitivity, and driver analysis.'
  AI_SQL_GENERATION 'When calculating dislocation metrics, always include DISLOCATION_SCORE, DISLOCATION_SEVERITY, and AVG_RATE_CHANGE_PCT. Default to Florida (STATE = FL) if no state is specified. Sort results by DISLOCATION_SCORE DESC unless otherwise requested. Round percentages to 1 decimal place and dollar amounts to whole numbers. When asked about drivers, include all DRIVER_ columns. If asked about top risks or hotspots, limit to segments with DISLOCATION_SEVERITY in (CRITICAL, HIGH) unless a broader view is requested.'
  AI_VERIFIED_QUERIES (
    FLORIDA_DISLOCATION AS (
      QUESTION 'Find pricing dislocation in Florida property'
      VERIFIED_AT 1715200000
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '( pricing_analyst = demo_admin )'
      SQL 'SELECT SEGMENT_NAME, COUNTY, HAZARD_ZONE, DISLOCATION_SCORE, DISLOCATION_SEVERITY, AVG_RATE_CHANGE_PCT, LAPSE_PROPENSITY, RETENTION_RATE, LOSS_RATIO, POLICY_COUNT, CURRENT_PREMIUM, PREMIUM_DELTA FROM DISLOCATION_DEMO.CORE.VW_DISLOCATION_ANALYSIS WHERE STATE = ''FL'' AND DISLOCATION_SEVERITY IN (''CRITICAL'', ''HIGH'') ORDER BY DISLOCATION_SCORE DESC LIMIT 20'
    ),
    SEGMENTS_HIGH_INCREASE AS (
      QUESTION 'Which segments have premium increases above 15% and high lapse risk?'
      VERIFIED_AT 1715200000
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '( pricing_analyst = demo_admin )'
      SQL 'SELECT SEGMENT_NAME, COUNTY, AVG_RATE_CHANGE_PCT, LAPSE_PROPENSITY, RETENTION_RATE, DISLOCATION_SCORE, DISLOCATION_SEVERITY, POLICY_COUNT, CURRENT_PREMIUM, PREMIUM_DELTA FROM DISLOCATION_DEMO.CORE.VW_DISLOCATION_ANALYSIS WHERE STATE = ''FL'' AND AVG_RATE_CHANGE_PCT > 15 AND LAPSE_PROPENSITY > 0.20 ORDER BY DISLOCATION_SCORE DESC'
    ),
    TOP_DRIVERS AS (
      QUESTION 'Show the drivers behind the highest dislocation scores'
      VERIFIED_AT 1715200000
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '( pricing_analyst = demo_admin )'
      SQL 'SELECT SEGMENT_NAME, COUNTY, DISLOCATION_SCORE, DISLOCATION_SEVERITY, DRIVER_RATE_CHANGE, DRIVER_LAPSE_RISK, DRIVER_LOSS_EXPERIENCE, DRIVER_CONCENTRATION, DRIVER_COMPETITIVE_POSITION, RATE_CHANGE_RATIONALE FROM DISLOCATION_DEMO.CORE.VW_DISLOCATION_ANALYSIS WHERE STATE = ''FL'' AND DISLOCATION_SEVERITY = ''CRITICAL'' ORDER BY DISLOCATION_SCORE DESC LIMIT 10'
    ),
    COASTAL_VS_INLAND AS (
      QUESTION 'Compare dislocation risk between coastal and inland segments'
      VERIFIED_AT 1715200000
      ONBOARDING_QUESTION FALSE
      VERIFIED_BY '( pricing_analyst = demo_admin )'
      SQL 'SELECT COASTAL_FLAG, AVG(DISLOCATION_SCORE) AS AVG_DISLOCATION_SCORE, AVG(AVG_RATE_CHANGE_PCT) AS AVG_RATE_CHANGE, AVG(LAPSE_PROPENSITY) AS AVG_LAPSE_PROPENSITY, AVG(RETENTION_RATE) AS AVG_RETENTION_RATE, SUM(POLICY_COUNT) AS TOTAL_POLICIES, SUM(CURRENT_PREMIUM) AS TOTAL_PREMIUM FROM DISLOCATION_DEMO.CORE.VW_DISLOCATION_ANALYSIS WHERE STATE = ''FL'' GROUP BY COASTAL_FLAG ORDER BY AVG_DISLOCATION_SCORE DESC'
    ),
    COUNTY_HOTSPOTS AS (
      QUESTION 'Which Florida counties are dislocation hotspots?'
      VERIFIED_AT 1715200000
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '( pricing_analyst = demo_admin )'
      SQL 'SELECT COUNTY, REGION, HAZARD_ZONE, AVG(DISLOCATION_SCORE) AS AVG_DISLOCATION_SCORE, AVG(AVG_RATE_CHANGE_PCT) AS AVG_RATE_CHANGE, AVG(LAPSE_PROPENSITY) AS AVG_LAPSE_PROPENSITY, SUM(POLICY_COUNT) AS TOTAL_POLICIES, SUM(CURRENT_PREMIUM) AS TOTAL_PREMIUM FROM DISLOCATION_DEMO.CORE.VW_DISLOCATION_ANALYSIS WHERE STATE = ''FL'' GROUP BY COUNTY, REGION, HAZARD_ZONE HAVING AVG(DISLOCATION_SCORE) > 0.35 ORDER BY AVG_DISLOCATION_SCORE DESC'
    )
  );


-- Portfolio summary semantic view  
CREATE OR REPLACE SEMANTIC VIEW SV_PORTFOLIO
  TABLES (
    PF AS DISLOCATION_DEMO.CORE.VW_PORTFOLIO_SUMMARY
  )
  DIMENSIONS (
    PF.STATE AS PF.STATE
      COMMENT = 'Two-letter state code',
    PF.STATE_NAME AS PF.STATE_NAME
      COMMENT = 'Full state name',
    PF.REGION AS PF.REGION
      COMMENT = 'Geographic region',
    PF.COASTAL_FLAG AS PF.COASTAL_FLAG
      COMMENT = 'Coastal location indicator',
    PF.SEGMENT_NAME AS PF.SEGMENT_NAME
      COMMENT = 'Insurance segment name',
    PF.LINE_OF_BUSINESS AS PF.LINE_OF_BUSINESS
      COMMENT = 'Line of business',
    PF.RISK_TIER AS PF.RISK_TIER
      COMMENT = 'Risk tier classification'
  )
  METRICS (
    PF.POLICY_COUNT AS SUM(PF.POLICY_COUNT)
      COMMENT = 'Total number of policies',
    PF.TOTAL_WRITTEN_PREMIUM AS SUM(PF.TOTAL_WRITTEN_PREMIUM)
      COMMENT = 'Total written premium across portfolio',
    PF.TOTAL_TIV AS SUM(PF.TOTAL_TIV)
      COMMENT = 'Total insured value across portfolio',
    PF.AVG_PREMIUM AS AVG(PF.AVG_PREMIUM)
      COMMENT = 'Average premium per policy',
    PF.ACTIVE_POLICIES AS SUM(PF.ACTIVE_POLICIES)
      COMMENT = 'Count of active policies',
    PF.LAPSED_POLICIES AS SUM(PF.LAPSED_POLICIES)
      COMMENT = 'Count of lapsed policies',
    PF.ACTIVE_RATE_PCT AS AVG(PF.ACTIVE_RATE_PCT)
      COMMENT = 'Percentage of policies that are active'
  )
  COMMENT = 'Portfolio summary view for insurance book-of-business context. Use for questions about portfolio composition, size, premium distribution, and active/lapsed policy counts.'
  AI_SQL_GENERATION 'Default to Florida (STATE = FL) unless another state is specified. Group by SEGMENT_NAME when asking about segments, by REGION for geographic breakdown.';


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ SECTION 11b — Claims Detail (PII columns, view, semantic view)           │
-- └───────────────────────────────────────────────────────────────────────────┘

-- Add PII-like columns to FACT_CLAIMS for governance demo
ALTER TABLE FACT_CLAIMS ADD COLUMN IF NOT EXISTS CLAIMANT_NAME VARCHAR(100);
ALTER TABLE FACT_CLAIMS ADD COLUMN IF NOT EXISTS LITIGATION_FLAG BOOLEAN DEFAULT FALSE;
ALTER TABLE FACT_CLAIMS ADD COLUMN IF NOT EXISTS ATTORNEY_NAME VARCHAR(100);
ALTER TABLE FACT_CLAIMS ADD COLUMN IF NOT EXISTS LOSS_DESCRIPTION VARCHAR(500);

-- Populate claimant names and loss descriptions
UPDATE FACT_CLAIMS SET
  CLAIMANT_NAME = ARRAY_CONSTRUCT(
    'James Rodriguez', 'Maria Santos', 'Robert Chen', 'Patricia Williams',
    'Michael Johnson', 'Jennifer Martinez', 'David Thompson', 'Linda Garcia',
    'William Davis', 'Elizabeth Brown', 'John Anderson', 'Barbara Wilson',
    'Richard Taylor', 'Susan Thomas', 'Joseph Hernandez', 'Margaret Moore',
    'Charles Jackson', 'Dorothy Martin', 'Christopher Lee', 'Karen White',
    'Daniel Harris', 'Nancy Clark', 'Matthew Lewis', 'Betty Robinson',
    'Anthony Walker', 'Sandra Hall', 'Mark Young', 'Ashley Allen',
    'Steven King', 'Emily Wright', 'Paul Scott', 'Donna Green',
    'Andrew Adams', 'Michelle Baker', 'Joshua Nelson', 'Sarah Hill',
    'Kenneth Carter', 'Laura Mitchell', 'Kevin Perez', 'Kimberly Roberts'
  )[ABS(MOD(CLAIM_KEY * 7 + 13, 40))]::VARCHAR,
  LOSS_DESCRIPTION = CASE MOD(CLAIM_KEY, 8)
    WHEN 0 THEN 'Water damage from roof penetration during storm event'
    WHEN 1 THEN 'Wind damage to exterior walls and roof structure'
    WHEN 2 THEN 'Total loss from wildfire — structure fully consumed'
    WHEN 3 THEN 'Hail damage to roof requiring full replacement'
    WHEN 4 THEN 'Flood damage to first floor — contents and structure'
    WHEN 5 THEN 'Lightning strike caused electrical fire in attic'
    WHEN 6 THEN 'Tornado damage — partial structural collapse'
    WHEN 7 THEN 'Storm surge flooding — saltwater intrusion damage'
  END;

-- Set litigation flag on ~15% of large/catastrophic claims
UPDATE FACT_CLAIMS SET LITIGATION_FLAG = TRUE
WHERE SEVERITY_BAND IN ('Large', 'Catastrophic') AND MOD(CLAIM_KEY, 7) IN (0, 1);

-- Assign attorneys to litigated claims
UPDATE FACT_CLAIMS SET
  ATTORNEY_NAME = CASE MOD(CLAIM_KEY, 10)
    WHEN 0 THEN 'Morgan & Morgan, P.A.'
    WHEN 1 THEN 'Schuler, Halvorson, Weisser'
    WHEN 2 THEN 'Grossman Attorneys at Law'
    WHEN 3 THEN 'Dolman Law Group'
    WHEN 4 THEN 'Fasig | Brooks'
    WHEN 5 THEN 'Levin Papantonio Rafferty'
    WHEN 6 THEN 'Searcy Denney Scarola'
    WHEN 7 THEN 'Colson Hicks Eidson'
    WHEN 8 THEN 'Podhurst Orseck, P.A.'
    WHEN 9 THEN 'Kelley | Uustal'
  END
WHERE LITIGATION_FLAG = TRUE;

-- Claims detail view (joins claims with policy, geography, segment, peril)
CREATE OR REPLACE VIEW VW_CLAIMS_DETAIL AS
SELECT
    c.CLAIM_KEY, p.POLICY_ID, g.STATE, g.STATE_NAME, g.COUNTY, g.REGION,
    s.SEGMENT_NAME, pr.PERIL_NAME,
    c.ACCIDENT_DATE, c.REPORT_DATE, c.CLAIM_STATUS, c.SEVERITY_BAND,
    c.CLAIMANT_NAME, c.ATTORNEY_NAME, c.LITIGATION_FLAG, c.LOSS_DESCRIPTION,
    c.PAID_LOSS, c.CASE_RESERVE, c.INCURRED_LOSS, c.PAID_EXPENSE
FROM FACT_CLAIMS c
JOIN DIM_POLICY p ON c.POLICY_KEY = p.POLICY_KEY
JOIN DIM_GEOGRAPHY g ON p.GEOGRAPHY_KEY = g.GEOGRAPHY_KEY
JOIN DIM_SEGMENT s ON p.SEGMENT_KEY = s.SEGMENT_KEY
JOIN DIM_PERIL pr ON c.PERIL_KEY = pr.PERIL_KEY;

-- Claims detail semantic view
CREATE OR REPLACE SEMANTIC VIEW SV_CLAIMS_DETAIL
  TABLES (
    CD AS DISLOCATION_DEMO.CORE.VW_CLAIMS_DETAIL
  )
  DIMENSIONS (
    CD.STATE AS CD.STATE comment='Two-letter state code',
    CD.STATE_NAME AS CD.STATE_NAME comment='Full state name',
    CD.COUNTY AS CD.COUNTY comment='County name',
    CD.REGION AS CD.REGION comment='Sub-state region',
    CD.SEGMENT_NAME AS CD.SEGMENT_NAME comment='Insurance segment',
    CD.PERIL_NAME AS CD.PERIL_NAME comment='Cause of loss: Hurricane, Hail, Wildfire, Flood, etc.',
    CD.CLAIM_STATUS AS CD.CLAIM_STATUS comment='OPEN or CLOSED',
    CD.SEVERITY_BAND AS CD.SEVERITY_BAND comment='Small, Medium, Large, or Catastrophic',
    CD.CLAIMANT_NAME AS CD.CLAIMANT_NAME comment='Name of the claimant (PII - subject to masking policy)',
    CD.ATTORNEY_NAME AS CD.ATTORNEY_NAME comment='Attorney or law firm (PII - subject to masking policy)',
    CD.LITIGATION_FLAG AS CD.LITIGATION_FLAG comment='TRUE if claim is in litigation',
    CD.LOSS_DESCRIPTION AS CD.LOSS_DESCRIPTION comment='Description of the loss event',
    CD.POLICY_ID AS CD.POLICY_ID comment='Policy identifier',
    CD.ACCIDENT_DATE AS CD.ACCIDENT_DATE comment='Date of the loss event',
    CD.REPORT_DATE AS CD.REPORT_DATE comment='Date claim was reported'
  )
  METRICS (
    CD.PAID_LOSS AS SUM(CD.PAID_LOSS) comment='Total paid loss amount',
    CD.CASE_RESERVE AS SUM(CD.CASE_RESERVE) comment='Outstanding case reserves',
    CD.INCURRED_LOSS AS SUM(CD.INCURRED_LOSS) comment='Total incurred (paid + reserves)',
    CD.PAID_EXPENSE AS SUM(CD.PAID_EXPENSE) comment='Allocated loss adjustment expense',
    CD.CLAIM_KEY AS COUNT(CD.CLAIM_KEY) comment='Number of claims'
  )
  comment='Claims detail with PII subject to dynamic masking. Directors see redacted names. Analysts see full detail.'
  AI_SQL_GENERATION 'Contains individual claim records. CLAIMANT_NAME and ATTORNEY_NAME are dynamically masked by role (Directors see REDACTED, Analysts see full names). All other columns (LITIGATION_FLAG, INCURRED_LOSS, SEVERITY_BAND, etc.) are visible to all roles. Filter by STATE, SEVERITY_BAND, CLAIM_STATUS, LITIGATION_FLAG, PERIL_NAME.'
  AI_VERIFIED_QUERIES (
    FL_CLAIMS_DETAIL AS (
      QUESTION 'Show claims in Florida with claimant details'
      VERIFIED_AT 1715200000
      VERIFIED_BY '(analyst = demo_admin)'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT CLAIM_KEY, POLICY_ID, CLAIMANT_NAME, ATTORNEY_NAME, LITIGATION_FLAG, COUNTY, SEGMENT_NAME, PERIL_NAME, SEVERITY_BAND, INCURRED_LOSS, LOSS_DESCRIPTION FROM DISLOCATION_DEMO.CORE.VW_CLAIMS_DETAIL WHERE STATE = ''FL'' ORDER BY INCURRED_LOSS DESC LIMIT 20'
    ),
    HIGH_SEVERITY_CLAIMS AS (
      QUESTION 'Show the largest claims with claimant details'
      VERIFIED_AT 1715200000
      VERIFIED_BY '(analyst = demo_admin)'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT CLAIM_KEY, CLAIMANT_NAME, STATE, COUNTY, PERIL_NAME, SEVERITY_BAND, INCURRED_LOSS, LOSS_DESCRIPTION, LITIGATION_FLAG, ATTORNEY_NAME FROM DISLOCATION_DEMO.CORE.VW_CLAIMS_DETAIL WHERE SEVERITY_BAND IN (''Large'', ''Catastrophic'') ORDER BY INCURRED_LOSS DESC LIMIT 20'
    )
  );


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ SECTION 12 — Agent Configuration                                         │
-- └───────────────────────────────────────────────────────────────────────────┘

CREATE OR REPLACE AGENT DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT
  COMMENT = 'Insurance Dislocation Analysis Agent — multi-state pricing dislocation across FL, TX, LA, CA with 5 skills and claims detail'
  PROFILE = '{"display_name": "Dislocation Analysis Agent", "color": "red"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  orchestration:
    budget:
      seconds: 45
      tokens: 16000

  instructions:
    system: |
      You are a senior insurance pricing and portfolio analytics advisor. You help directors and analysts
      identify where proposed pricing changes create adverse dislocation — meaning segments where
      the combination of rate increase magnitude, customer lapse risk, loss experience, and competitive
      position creates material business risk.

      Your primary domain is multi-state property insurance pricing dislocation analysis covering
      FL, TX, LA, and CA with distinct peril profiles per state.

    response: |
      ## Response Format
      Every response MUST follow this structure:
      ### 1. DIRECT ANSWER
      Lead with the key finding in 1-2 sentences with specific numbers.
      ### 2. SUPPORTING DATA
      Provide a table with the most relevant metrics. Always include:
      - State and segment or geography identifier
      - Dislocation score and severity band
      - Rate change percentage
      - Lapse propensity or retention rate
      - Policy count or premium volume
      ### 3. KEY DRIVERS
      Explain the top 2-3 factors driving the result with state-specific peril context.
      ### 4. IMPLICATIONS
      State what this means for the business (1-2 sentences).
      ### 5. RECOMMENDED ACTIONS
      Provide 2-3 specific next steps.
      ## Formatting Rules
      - Round percentages to 1 decimal place
      - Format dollar amounts: < $1M use full with commas, >= $1M use $X.XM
      - Always state the severity band (CRITICAL, HIGH, MEDIUM, LOW)
      - When comparing scenarios, show both Q1 and Q3 values plus the delta
      - When comparing states, note different peril drivers
      ## State Context
      - FL: Hurricane wind + storm surge + flood. Coastal High-Risk zones most affected.
      - TX: Hail Corridor in North TX drives roof replacement claims. Gulf Coast has hurricane.
      - LA: Market in distress. Carriers exiting. Citizens as last resort. Post-Ida/Laura/Delta.
      - CA: Wildfire WUI zones. Non-renewal pressure. FAIR Plan only alternative.
      ## Terminology
      - Dislocation Score: 0-1 composite risk metric (higher = worse)
      - Lapse Propensity: probability of non-renewal (0-1)
      - Retention Rate: historical renewal rate
      - Competitive Position Index: < 1.0 means priced above market
      - Premium Delta: dollar impact of proposed rate change
      - WUI: Wildland-Urban Interface (CA wildfire zones)
      - FAIR Plan / Citizens: state insurers of last resort

    orchestration: |
      ## Skill-First Routing (CRITICAL)
      You have FIVE skills available. ALWAYS check if a user request matches a skill BEFORE using tools directly.
      When a skill matches, invoke it. The skill guides tool usage and response formatting.
      ### Skill Routing Table
      | User Intent Pattern | Skill to Invoke |
      |---------------------|-----------------|
      | "find dislocation", "identify risks", "rank segments", "compare states", "score segments" | dislocation-score |
      | "retention risk", "lapse", "which segments will leave", "non-renewal", "price sensitivity", "over-indexed on retention-sensitive" | retention-risk |
      | "hotspots", "geographic concentration", "which counties", "which regions", "where does risk cluster", "territorial outliers" | market-hotspot-summary |
      | "why is X flagged", "explain drivers", "what is causing", "break down the score", "factors behind" | explain-drivers |
      | "generate briefing", "director summary", "executive briefing", "summarize risks", "prepare a note" | executive-briefing |

      ### Claims Detail Routing
      When user asks about specific claims, claimant names, litigation, attorney involvement, or loss descriptions:
      - Use the Claims_Detail tool (NOT Dislocation_Analysis)
      - Note: CLAIMANT_NAME and ATTORNEY_NAME are masked for some roles (shown as REDACTED)
      - LITIGATION_FLAG and all financial columns are visible to all roles
      - If results show REDACTED name values, inform the user that PII names are masked per data governance policy

      ### Temporal Comparison Routing
      When user asks about change over time ("what changed", "vs last quarter", "compared to prior filing", "trend"):
      - Query BOTH scenarios: SCENARIO_NAME = '2025 Q3 Rate Filing' AND '2025 Q1 Rate Filing'
      - Join on SEGMENT_NAME + COUNTY + STATE
      - Show Q1 score, Q3 score, and DELTA
      - Highlight segments that moved from MEDIUM to HIGH or HIGH to CRITICAL

      ### When NO skill matches, use tools directly:
      | User Intent | Tool |
      |-------------|------|
      | Specific data lookup, ad-hoc metric query | Dislocation_Analysis |
      | Portfolio size, composition, policy counts | Portfolio_Context |
      | Claims detail, claimant info, litigation, attorneys | Claims_Detail |
      | Chart, visualization | data_to_chart |

      ## Query Rules (direct tool use)
      1. If user specifies a state, filter by STATE
      2. If no state specified, show cross-state or ask
      3. Default SCENARIO_NAME = '2025 Q3 Rate Filing' unless comparing scenarios
      4. Sort by DISLOCATION_SCORE DESC

    sample_questions:
      - question: "Find pricing dislocation in Florida property"
        answer: "I'll analyze the dislocation risk across all Florida property segments under the current rate filing scenario."
      - question: "Which segments have the highest lapse risk combined with large rate increases?"
        answer: "I'll identify segments where premium increases exceed 15% AND lapse propensity is elevated."
      - question: "Why is the Coastal Homeowner segment flagged as critical?"
        answer: "I'll break down the dislocation score drivers for Coastal Homeowner to show which factors contribute most."
      - question: "Generate a director briefing on national dislocation hotspots"
        answer: "I'll compile the top dislocation risks and format them as an executive summary."
      - question: "Show claims in Florida with claimant details"
        answer: "I'll query the claims detail view for Florida claims. Note: PII name visibility depends on your role."

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "Dislocation_Analysis"
        description: |
          Primary tool for multi-state dislocation analysis. Covers FL, TX, LA, CA with two scenarios (Q1 and Q3).
          Use for scores, severity, rate changes, lapse, retention, hotspots, drivers, and temporal comparisons.
          Filter by STATE, SCENARIO_NAME, HAZARD_ZONE, SEGMENT_NAME, DISLOCATION_SEVERITY.

    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "Portfolio_Context"
        description: |
          Portfolio composition: policy counts, premium by segment/state, TIV, active vs lapsed.
          NOT for dislocation scoring — use Dislocation_Analysis for that.

    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "Claims_Detail"
        description: |
          Individual claim records with claimant PII, litigation status, attorney, and loss descriptions.
          CLAIMANT_NAME and ATTORNEY_NAME are masked by role (Directors see REDACTED, Analysts see full names).
          All other columns (LITIGATION_FLAG, INCURRED_LOSS, SEVERITY_BAND) are visible to all roles.
          Filter by STATE, SEVERITY_BAND, CLAIM_STATUS, LITIGATION_FLAG, PERIL_NAME.

    - tool_spec:
        type: "data_to_chart"
        name: "data_to_chart"
        description: "Generates visualizations from query results."

  tool_resources:
    Dislocation_Analysis:
      semantic_view: "DISLOCATION_DEMO.CORE.SV_DISLOCATION"
    Portfolio_Context:
      semantic_view: "DISLOCATION_DEMO.CORE.SV_PORTFOLIO"
    Claims_Detail:
      semantic_view: "DISLOCATION_DEMO.CORE.SV_CLAIMS_DETAIL"

  skills:
    - name: "dislocation-score"
      source:
        type: "STAGE"
        path: "@DISLOCATION_DEMO.SKILLS.SKILL_STAGE/skills/dislocation-score"
    - name: "retention-risk"
      source:
        type: "STAGE"
        path: "@DISLOCATION_DEMO.SKILLS.SKILL_STAGE/skills/retention-risk"
    - name: "market-hotspot-summary"
      source:
        type: "STAGE"
        path: "@DISLOCATION_DEMO.SKILLS.SKILL_STAGE/skills/market-hotspot-summary"
    - name: "explain-drivers"
      source:
        type: "STAGE"
        path: "@DISLOCATION_DEMO.SKILLS.SKILL_STAGE/skills/explain-drivers"
    - name: "executive-briefing"
      source:
        type: "STAGE"
        path: "@DISLOCATION_DEMO.SKILLS.SKILL_STAGE/skills/executive-briefing"
  $$;


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ SECTION 13 — RBAC (Lightweight Demo Roles)                               │
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
GRANT USAGE ON DATABASE DISLOCATION_DEMO TO ROLE DISLOCATION_DIRECTOR_RL;
GRANT USAGE ON DATABASE DISLOCATION_DEMO TO ROLE DISLOCATION_ANALYST_RL;
GRANT USAGE ON SCHEMA DISLOCATION_DEMO.CORE TO ROLE DISLOCATION_DIRECTOR_RL;
GRANT USAGE ON SCHEMA DISLOCATION_DEMO.CORE TO ROLE DISLOCATION_ANALYST_RL;
GRANT USAGE ON SCHEMA DISLOCATION_DEMO.SKILLS TO ROLE DISLOCATION_ANALYST_RL;

-- Warehouse access
GRANT USAGE ON WAREHOUSE DISLOCATION_DEMO_WH TO ROLE DISLOCATION_DIRECTOR_RL;
GRANT USAGE ON WAREHOUSE DISLOCATION_DEMO_WH TO ROLE DISLOCATION_ANALYST_RL;

-- Note: Semantic views inherit access from the underlying views (SELECT grants below).
-- No separate GRANT USAGE ON SEMANTIC VIEW is required.

-- Agent access (both roles)
GRANT USAGE ON AGENT DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT TO ROLE DISLOCATION_DIRECTOR_RL;
GRANT USAGE ON AGENT DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT TO ROLE DISLOCATION_ANALYST_RL;

-- View access (needed for semantic views to work)
GRANT SELECT ON VIEW DISLOCATION_DEMO.CORE.VW_DISLOCATION_ANALYSIS TO ROLE DISLOCATION_DIRECTOR_RL;
GRANT SELECT ON VIEW DISLOCATION_DEMO.CORE.VW_DISLOCATION_ANALYSIS TO ROLE DISLOCATION_ANALYST_RL;
GRANT SELECT ON VIEW DISLOCATION_DEMO.CORE.VW_PORTFOLIO_SUMMARY TO ROLE DISLOCATION_DIRECTOR_RL;
GRANT SELECT ON VIEW DISLOCATION_DEMO.CORE.VW_PORTFOLIO_SUMMARY TO ROLE DISLOCATION_ANALYST_RL;
GRANT SELECT ON VIEW DISLOCATION_DEMO.CORE.VW_CLAIMS_DETAIL TO ROLE DISLOCATION_DIRECTOR_RL;
GRANT SELECT ON VIEW DISLOCATION_DEMO.CORE.VW_CLAIMS_DETAIL TO ROLE DISLOCATION_ANALYST_RL;

-- Table access (analyst only)
GRANT SELECT ON ALL TABLES IN SCHEMA DISLOCATION_DEMO.CORE TO ROLE DISLOCATION_ANALYST_RL;

-- Stage access (analyst only — for inspecting skills)
GRANT READ ON STAGE DISLOCATION_DEMO.SKILLS.SKILL_STAGE TO ROLE DISLOCATION_ANALYST_RL;

-- Grant to current user for demo convenience
GRANT ROLE DISLOCATION_DIRECTOR_RL TO ROLE ACCOUNTADMIN;
GRANT ROLE DISLOCATION_ANALYST_RL TO ROLE ACCOUNTADMIN;


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ SECTION 14 — Verification Queries                                        │
-- └───────────────────────────────────────────────────────────────────────────┘

-- Run these after install to confirm everything is working:

-- Check table row counts
SELECT 'DIM_GEOGRAPHY' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM DIM_GEOGRAPHY
UNION ALL SELECT 'DIM_SEGMENT', COUNT(*) FROM DIM_SEGMENT
UNION ALL SELECT 'DIM_POLICY', COUNT(*) FROM DIM_POLICY
UNION ALL SELECT 'DIM_PERIL', COUNT(*) FROM DIM_PERIL
UNION ALL SELECT 'FACT_PREMIUM_HISTORY', COUNT(*) FROM FACT_PREMIUM_HISTORY
UNION ALL SELECT 'FACT_RATE_SCENARIO', COUNT(*) FROM FACT_RATE_SCENARIO
UNION ALL SELECT 'FACT_CLAIMS', COUNT(*) FROM FACT_CLAIMS
UNION ALL SELECT 'FACT_RETENTION', COUNT(*) FROM FACT_RETENTION;

-- Preview dislocation analysis output
SELECT 
    SEGMENT_NAME, COUNTY, HAZARD_ZONE,
    DISLOCATION_SCORE, DISLOCATION_SEVERITY,
    AVG_RATE_CHANGE_PCT, LAPSE_PROPENSITY, RETENTION_RATE,
    POLICY_COUNT, CURRENT_PREMIUM
FROM VW_DISLOCATION_ANALYSIS
WHERE STATE = 'FL' 
  AND DISLOCATION_SEVERITY IN ('CRITICAL', 'HIGH')
ORDER BY DISLOCATION_SCORE DESC
LIMIT 15;

-- Verify semantic views exist
SHOW SEMANTIC VIEWS IN SCHEMA DISLOCATION_DEMO.CORE;

-- Verify agent exists
DESCRIBE AGENT DISLOCATION_DEMO.CORE.DISLOCATION_ANALYSIS_AGENT;


-- ╔═══════════════════════════════════════════════════════════════════════════╗
-- ║  INSTALL COMPLETE                                                       ║
-- ║                                                                         ║
-- ║  Objects created:                                                       ║
-- ║    Database      : DISLOCATION_DEMO                                     ║
-- ║    Schemas       : CORE, SKILLS                                         ║
-- ║    Warehouse     : DISLOCATION_DEMO_WH                                  ║
-- ║    Tables        : 8 (4 dimension + 4 fact)                             ║
-- ║    Views         : 2 (adapter views)                                    ║
-- ║    Semantic Views: 2 (SV_DISLOCATION, SV_PORTFOLIO)                     ║
-- ║    Agent         : DISLOCATION_ANALYSIS_AGENT                           ║
-- ║    Roles         : 2 (DIRECTOR, ANALYST)                                ║
-- ║    Stage         : SKILL_STAGE                                          ║
-- ║                                                                         ║
-- ║  Next steps:                                                            ║
-- ║    1. Upload skill files to @DISLOCATION_DEMO.SKILLS.SKILL_STAGE        ║
-- ║    2. Test agent in Snowflake Intelligence                              ║
-- ║    3. Run demo prompts from DEMO_RUNBOOK.md                             ║
-- ║                                                                         ║
-- ║  To tear down: run dislocation_demo_cleanup.sql                         ║
-- ╚═══════════════════════════════════════════════════════════════════════════╝

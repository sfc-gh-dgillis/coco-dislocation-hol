-- ===========================================================================
-- 003 — Adapter views + claims-detail view (PII columns added here)
-- ===========================================================================

USE ROLE <% ctx.env.ROLE %>;
USE WAREHOUSE <% ctx.env.WAREHOUSE %>;
USE DATABASE <% ctx.env.DATABASE %>;
USE SCHEMA <% ctx.env.SCHEMA %>;

-- │ SECTION 10 — Adapter Views (Stable Semantic Contract Layer)               │
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

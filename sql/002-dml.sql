-- ===========================================================================
-- 002 — DML: seed data (dimensions, policies, premium, rate scenarios, claims, retention)
-- ===========================================================================

USE ROLE <% ctx.env.ROLE %>;
USE WAREHOUSE <% ctx.env.WAREHOUSE %>;
USE DATABASE <% ctx.env.DATABASE %>;
USE SCHEMA <% ctx.env.SCHEMA %>;

-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ SECTION 4 — Seed Data: Dimensions                                         │
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
-- │ SECTION 6 — Seed Data: Premium History                                    │
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
-- │ SECTION 7 — Seed Data: Rate Scenario (Proposed Rate Changes)              │
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
-- │ SECTION 8 — Seed Data: Claims History                                     │
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
WHERE MOD(SEQ4(), (SELECT COUNT(*) FROM DIM_POLICY)) + 1 = p.POLICY_KEY
  AND SEQ4() < 8000;

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
-- │ SECTION 9 — Seed Data: Retention Metrics                                  │
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

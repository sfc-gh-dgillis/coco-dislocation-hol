-- ===========================================================================
-- 004 — Semantic views (SV_DISLOCATION, SV_PORTFOLIO, SV_CLAIMS_DETAIL)
-- ===========================================================================

USE ROLE <% ctx.env.ROLE %>;
USE WAREHOUSE <% ctx.env.WAREHOUSE %>;
USE DATABASE <% ctx.env.DATABASE %>;
USE SCHEMA <% ctx.env.SCHEMA %>;

-- │ SECTION 11 — Semantic Views                                               │
-- └───────────────────────────────────────────────────────────────────────────┘

-- Primary semantic view: Dislocation Analysis
CREATE OR REPLACE SEMANTIC VIEW SV_DISLOCATION
  TABLES (
    DA AS <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.VW_DISLOCATION_ANALYSIS
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
      SQL 'SELECT SEGMENT_NAME, COUNTY, HAZARD_ZONE, DISLOCATION_SCORE, DISLOCATION_SEVERITY, AVG_RATE_CHANGE_PCT, LAPSE_PROPENSITY, RETENTION_RATE, LOSS_RATIO, POLICY_COUNT, CURRENT_PREMIUM, PREMIUM_DELTA FROM <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.VW_DISLOCATION_ANALYSIS WHERE STATE = ''FL'' AND DISLOCATION_SEVERITY IN (''CRITICAL'', ''HIGH'') ORDER BY DISLOCATION_SCORE DESC LIMIT 20'
    ),
    SEGMENTS_HIGH_INCREASE AS (
      QUESTION 'Which segments have premium increases above 15% and high lapse risk?'
      VERIFIED_AT 1715200000
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '( pricing_analyst = demo_admin )'
      SQL 'SELECT SEGMENT_NAME, COUNTY, AVG_RATE_CHANGE_PCT, LAPSE_PROPENSITY, RETENTION_RATE, DISLOCATION_SCORE, DISLOCATION_SEVERITY, POLICY_COUNT, CURRENT_PREMIUM, PREMIUM_DELTA FROM <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.VW_DISLOCATION_ANALYSIS WHERE STATE = ''FL'' AND AVG_RATE_CHANGE_PCT > 15 AND LAPSE_PROPENSITY > 0.20 ORDER BY DISLOCATION_SCORE DESC'
    ),
    TOP_DRIVERS AS (
      QUESTION 'Show the drivers behind the highest dislocation scores'
      VERIFIED_AT 1715200000
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '( pricing_analyst = demo_admin )'
      SQL 'SELECT SEGMENT_NAME, COUNTY, DISLOCATION_SCORE, DISLOCATION_SEVERITY, DRIVER_RATE_CHANGE, DRIVER_LAPSE_RISK, DRIVER_LOSS_EXPERIENCE, DRIVER_CONCENTRATION, DRIVER_COMPETITIVE_POSITION, RATE_CHANGE_RATIONALE FROM <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.VW_DISLOCATION_ANALYSIS WHERE STATE = ''FL'' AND DISLOCATION_SEVERITY = ''CRITICAL'' ORDER BY DISLOCATION_SCORE DESC LIMIT 10'
    ),
    COASTAL_VS_INLAND AS (
      QUESTION 'Compare dislocation risk between coastal and inland segments'
      VERIFIED_AT 1715200000
      ONBOARDING_QUESTION FALSE
      VERIFIED_BY '( pricing_analyst = demo_admin )'
      SQL 'SELECT COASTAL_FLAG, AVG(DISLOCATION_SCORE) AS AVG_DISLOCATION_SCORE, AVG(AVG_RATE_CHANGE_PCT) AS AVG_RATE_CHANGE, AVG(LAPSE_PROPENSITY) AS AVG_LAPSE_PROPENSITY, AVG(RETENTION_RATE) AS AVG_RETENTION_RATE, SUM(POLICY_COUNT) AS TOTAL_POLICIES, SUM(CURRENT_PREMIUM) AS TOTAL_PREMIUM FROM <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.VW_DISLOCATION_ANALYSIS WHERE STATE = ''FL'' GROUP BY COASTAL_FLAG ORDER BY AVG_DISLOCATION_SCORE DESC'
    ),
    COUNTY_HOTSPOTS AS (
      QUESTION 'Which Florida counties are dislocation hotspots?'
      VERIFIED_AT 1715200000
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '( pricing_analyst = demo_admin )'
      SQL 'SELECT COUNTY, REGION, HAZARD_ZONE, AVG(DISLOCATION_SCORE) AS AVG_DISLOCATION_SCORE, AVG(AVG_RATE_CHANGE_PCT) AS AVG_RATE_CHANGE, AVG(LAPSE_PROPENSITY) AS AVG_LAPSE_PROPENSITY, SUM(POLICY_COUNT) AS TOTAL_POLICIES, SUM(CURRENT_PREMIUM) AS TOTAL_PREMIUM FROM <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.VW_DISLOCATION_ANALYSIS WHERE STATE = ''FL'' GROUP BY COUNTY, REGION, HAZARD_ZONE HAVING AVG(DISLOCATION_SCORE) > 0.35 ORDER BY AVG_DISLOCATION_SCORE DESC'
    )
  );


-- Portfolio summary semantic view  
CREATE OR REPLACE SEMANTIC VIEW SV_PORTFOLIO
  TABLES (
    PF AS <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.VW_PORTFOLIO_SUMMARY
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

-- Claims detail semantic view
CREATE OR REPLACE SEMANTIC VIEW SV_CLAIMS_DETAIL
  TABLES (
    CD AS <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.VW_CLAIMS_DETAIL
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
      SQL 'SELECT CLAIM_KEY, POLICY_ID, CLAIMANT_NAME, ATTORNEY_NAME, LITIGATION_FLAG, COUNTY, SEGMENT_NAME, PERIL_NAME, SEVERITY_BAND, INCURRED_LOSS, LOSS_DESCRIPTION FROM <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.VW_CLAIMS_DETAIL WHERE STATE = ''FL'' ORDER BY INCURRED_LOSS DESC LIMIT 20'
    ),
    HIGH_SEVERITY_CLAIMS AS (
      QUESTION 'Show the largest claims with claimant details'
      VERIFIED_AT 1715200000
      VERIFIED_BY '(analyst = demo_admin)'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT CLAIM_KEY, CLAIMANT_NAME, STATE, COUNTY, PERIL_NAME, SEVERITY_BAND, INCURRED_LOSS, LOSS_DESCRIPTION, LITIGATION_FLAG, ATTORNEY_NAME FROM <% ctx.env.DATABASE %>.<% ctx.env.SCHEMA %>.VW_CLAIMS_DETAIL WHERE SEVERITY_BAND IN (''Large'', ''Catastrophic'') ORDER BY INCURRED_LOSS DESC LIMIT 20'
    )
  );

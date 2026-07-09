-- ╔═══════════════════════════════════════════════════════════════════════════╗
-- ║  PII Masking Policy — Data Governance Demo Extension                    ║
-- ╠═══════════════════════════════════════════════════════════════════════════╣
-- ║  Run AFTER install.sql                                                  ║
-- ║  Adds a masking policy on CLAIMANT_NAME and ATTORNEY_NAME so that:      ║
-- ║    • Analyst role sees full names                                        ║
-- ║    • Director role sees "●●●● REDACTED ●●●●"                            ║
-- ║                                                                         ║
-- ║  All other columns (LITIGATION_FLAG, INCURRED_LOSS, etc.) remain        ║
-- ║  visible to all roles.                                                  ║
-- ╚═══════════════════════════════════════════════════════════════════════════╝

USE ROLE ACCOUNTADMIN;
USE DATABASE DISLOCATION_DEMO;
USE SCHEMA CORE;
USE WAREHOUSE DISLOCATION_DEMO_WH;


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ Create Masking Policy                                                     │
-- └───────────────────────────────────────────────────────────────────────────┘

CREATE OR REPLACE MASKING POLICY MASK_PII_NAME AS (val VARCHAR) RETURNS VARCHAR ->
  CASE
    WHEN CURRENT_ROLE() IN ('DISLOCATION_ANALYST_RL', 'ACCOUNTADMIN') THEN val
    ELSE '●●●● REDACTED ●●●●'
  END;


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ Apply to Claims Detail View                                               │
-- └───────────────────────────────────────────────────────────────────────────┘

ALTER VIEW VW_CLAIMS_DETAIL MODIFY COLUMN
  CLAIMANT_NAME SET MASKING POLICY MASK_PII_NAME;

ALTER VIEW VW_CLAIMS_DETAIL MODIFY COLUMN
  ATTORNEY_NAME SET MASKING POLICY MASK_PII_NAME;


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ Verification                                                              │
-- └───────────────────────────────────────────────────────────────────────────┘

-- Test as Analyst (should see real names):
-- USE ROLE DISLOCATION_ANALYST_RL;
-- USE SECONDARY ROLES NONE;
-- USE WAREHOUSE DISLOCATION_DEMO_WH;
-- SELECT CLAIMANT_NAME, ATTORNEY_NAME, LITIGATION_FLAG, INCURRED_LOSS
-- FROM DISLOCATION_DEMO.CORE.VW_CLAIMS_DETAIL
-- WHERE STATE = 'FL' ORDER BY INCURRED_LOSS DESC LIMIT 5;

-- Test as Director (should see REDACTED names, but LITIGATION_FLAG visible):
-- USE ROLE DISLOCATION_DIRECTOR_RL;
-- USE SECONDARY ROLES NONE;
-- USE WAREHOUSE DISLOCATION_DEMO_WH;
-- SELECT CLAIMANT_NAME, ATTORNEY_NAME, LITIGATION_FLAG, INCURRED_LOSS
-- FROM DISLOCATION_DEMO.CORE.VW_CLAIMS_DETAIL
-- WHERE STATE = 'FL' AND LITIGATION_FLAG = TRUE
-- ORDER BY INCURRED_LOSS DESC LIMIT 5;


-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │ Cleanup (uncomment to remove masking)                                     │
-- └───────────────────────────────────────────────────────────────────────────┘

-- ALTER VIEW VW_CLAIMS_DETAIL MODIFY COLUMN CLAIMANT_NAME UNSET MASKING POLICY;
-- ALTER VIEW VW_CLAIMS_DETAIL MODIFY COLUMN ATTORNEY_NAME UNSET MASKING POLICY;
-- DROP MASKING POLICY IF EXISTS MASK_PII_NAME;


-- ╔═══════════════════════════════════════════════════════════════════════════╗
-- ║  MASKING POLICY APPLIED                                                 ║
-- ║                                                                         ║
-- ║  What's masked:                                                         ║
-- ║    • CLAIMANT_NAME  → "●●●● REDACTED ●●●●" for Director role           ║
-- ║    • ATTORNEY_NAME  → "●●●● REDACTED ●●●●" for Director role           ║
-- ║                                                                         ║
-- ║  What's visible to ALL roles:                                           ║
-- ║    • LITIGATION_FLAG, INCURRED_LOSS, SEVERITY_BAND, STATE, COUNTY       ║
-- ║    • All other columns                                                  ║
-- ║                                                                         ║
-- ║  Demo: Both roles ask "Show claims in Florida with claimant details"    ║
-- ║    Analyst → sees Nancy Clark, Fasig | Brooks                           ║
-- ║    Director → sees ●●●● REDACTED ●●●●                                  ║
-- ║    Same rows, same order, same financial data.                           ║
-- ╚═══════════════════════════════════════════════════════════════════════════╝

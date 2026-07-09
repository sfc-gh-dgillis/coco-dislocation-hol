---
name: retention-risk
description: Estimates lapse sensitivity and retention exposure by segment. Highlights combinations of large price change and high lapse propensity. Use when asked about retention risk, lapse behavior, which segments will leave, or price sensitivity.
---

# Retention Risk Skill

## When to Invoke

Invoke this skill when the user asks:
- "Which segments have the highest lapse risk?"
- "Where are we over-indexed on retention-sensitive policyholders?"
- "Which segments combine high premium uplift with high lapse propensity?"
- "Show retention exposure by segment"
- "Which policyholders are most likely to non-renew?"
- "Price sensitivity analysis"
- Any question focused specifically on retention, lapse, or customer attrition risk

## Coverage

Multi-state: FL, TX, LA, CA. Each state has different retention dynamics:
- FL: Coastal policyholders have alternatives (Citizens, surplus lines)
- TX: Hail corridor customers actively shop after claims
- LA: Policyholders going bare (uninsured) due to carrier exits — not switching
- CA: Wildfire WUI non-renewals are carrier-driven, not customer-driven

## Instructions

### Step 1: Identify High-Risk Cohorts

Query the Dislocation_Analysis tool for segments where BOTH conditions are true:
- AVG_RATE_CHANGE_PCT > 15% (meaningful price increase)
- LAPSE_PROPENSITY > 0.20 (elevated non-renewal probability)

Include: STATE, SEGMENT_NAME, COUNTY, AVG_RATE_CHANGE_PCT, LAPSE_PROPENSITY, RETENTION_RATE, PRICE_SENSITIVITY_SCORE, COMPETITIVE_POSITION_INDEX, POLICY_COUNT, CURRENT_PREMIUM

### Step 2: Calculate Retention Exposure

For each flagged cohort, compute:
- Premium at risk = CURRENT_PREMIUM * LAPSE_PROPENSITY (expected lost premium)
- Policies at risk = POLICY_COUNT * LAPSE_PROPENSITY (expected non-renewals)
- Rank by premium at risk descending

### Step 3: Classify Retention Risk

Assign retention risk bands:
- SEVERE: rate change > 25% AND lapse propensity > 0.35
- HIGH: rate change > 15% AND lapse propensity > 0.25
- ELEVATED: rate change > 10% AND lapse propensity > 0.20
- MANAGEABLE: below thresholds

### Step 4: State-Specific Context

Add retention context per state:
- FL: "Alternatives available — customers likely to switch to Citizens or surplus lines"
- TX: "Active shopping market — hail claims trigger comparison shopping behavior"
- LA: "Limited alternatives — lapse means going uninsured or FAIR Plan at higher cost"
- CA: "Non-renewal is often carrier-initiated — policyholders forced to FAIR Plan"

### Step 5: Format Output

Present as:
1. Summary: X segments at SEVERE retention risk, Y at HIGH, representing $Z premium at risk
2. Ranked table: Segment, State, County, Rate Change, Lapse Probability, Premium at Risk, Risk Band
3. State breakdown of retention dynamics
4. Actionable insight: which cohorts to prioritize for retention intervention

## Guardrails

- Distinguish between voluntary lapse (customer shops) and involuntary non-renewal (carrier exits)
- Note that lapse propensity is modeled, not observed future behavior
- Never guarantee retention outcomes
- In LA/CA, note that low competitive position paradoxically means fewer alternatives, not better retention
- Premium at risk assumes lapse propensity converts fully — actual attrition may be lower

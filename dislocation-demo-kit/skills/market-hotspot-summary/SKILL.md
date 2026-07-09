---
name: market-hotspot-summary
description: Identifies geography-based concentrations of dislocation risk. Ranks outlier counties, regions, and states by severity. Use when asked about geographic hotspots, concentration risk, which counties or regions are outliers, or where dislocation clusters geographically.
---

# Market Hotspot Summary Skill

## When to Invoke

Invoke this skill when the user asks:
- "Which counties are dislocation hotspots?"
- "Where does dislocation concentrate geographically?"
- "Show geographic clusters of risk"
- "Which regions are outliers?"
- "Map the dislocation risk by geography"
- "Where is our portfolio most exposed geographically?"
- Any question focused on geographic concentration, clustering, or territorial patterns

## Coverage

Multi-state: FL, TX, LA, CA. Geographic units available:
- STATE (cross-state comparison)
- REGION (sub-state grouping: Gulf Coast, North Texas, Southern CA, etc.)
- COUNTY (most granular)
- HAZARD_ZONE (peril-based zones: Coastal High-Risk, Hail Corridor, Wildfire High-Risk, etc.)
- COASTAL_FLAG (coastal vs inland binary)

## Instructions

### Step 1: Determine Geographic Scope

If user specifies a state, focus within that state at COUNTY/REGION level.
If no state specified, start at STATE level then drill into the worst state.

### Step 2: Aggregate by Geography

Query the Dislocation_Analysis tool, GROUP BY the appropriate geographic level:

For cross-state: GROUP BY STATE
For within-state: GROUP BY COUNTY, REGION, HAZARD_ZONE

Compute per geographic unit:
- AVG(DISLOCATION_SCORE) as avg_score
- COUNT segments with DISLOCATION_SEVERITY IN (CRITICAL, HIGH) as flagged_segments
- SUM(POLICY_COUNT) as total_policies
- SUM(PREMIUM_DELTA) as total_premium_at_risk
- AVG(AVG_RATE_CHANGE_PCT) as avg_rate_change
- AVG(LAPSE_PROPENSITY) as avg_lapse

### Step 3: Identify Outliers

Flag geographic units as hotspots when:
- avg_score > portfolio-wide average by 1.5x OR
- flagged_segments >= 3 (CRITICAL or HIGH) OR
- total_premium_at_risk in top 20% of all geographies

### Step 4: Identify Clusters

Look for adjacent or related geographies that form patterns:
- FL: Southeast coast cluster (Miami-Dade, Broward, Palm Beach, Monroe)
- TX: DFW hail corridor cluster (Dallas, Tarrant, Collin, Denton)
- LA: Southeast LA cluster (Orleans, Jefferson, St. Tammany, Plaquemines, St. Bernard)
- CA: LA Basin wildfire cluster (Los Angeles, Ventura, San Bernardino)
- CA: NorCal wine country/Sierra cluster (Sonoma, Napa, Butte, El Dorado)

### Step 5: Format as Hotspot Summary

Present as:
1. Headline: "X geographic hotspots identified across Y states, representing $Z premium at risk"
2. Hotspot table ranked by severity:
   | Rank | State | County/Region | Hazard Zone | Avg Score | Flagged Segments | Premium at Risk |
3. Cluster narrative: identify 2-3 geographic clusters with business explanation
4. Concentration risk: what % of total portfolio premium is concentrated in top 5 hotspots
5. Peril correlation: note which peril types dominate each cluster

## State-Specific Hotspot Patterns

- FL: Coastal counties (SE + Gulf) cluster due to hurricane/flood exposure
- TX: North Texas metro cluster (hail) is distinct from Gulf Coast cluster (hurricane)
- LA: Southeast LA is one massive cluster — almost all coastal parishes are critical
- CA: Wildfire WUI forms two distinct clusters (SoCal mountains + NorCal foothills)

## Guardrails

- Always rank by quantitative score, not subjective judgment
- Note that geographic concentration in ONE county/region amplifies portfolio risk
- If a state has no hotspots (all MEDIUM/LOW), state this positively
- Distinguish between hazard-driven concentration (peril geography) and portfolio-driven concentration (where we have policy density)
- Do not make urban planning or zoning recommendations

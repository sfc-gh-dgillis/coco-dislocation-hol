---
name: dislocation-score
description: Calculates and ranks segment-level dislocation scores, identifying the highest-risk segments under a proposed rate scenario. Use when asked to find dislocation, identify at-risk segments, rank risks, or show hotspots.
---

# Dislocation Score Skill

## When to Invoke

Invoke this skill when the user asks any of the following:
- "Find dislocation" or "identify dislocation"
- "Which segments are at highest risk?"
- "Rank the dislocation risks"
- "Show me the hotspots"
- "Where is the proposed rate creating the most disruption?"
- Any question about segment-level or geography-level dislocation scoring

## Input Contract

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| state | No | FL | Two-letter state code to filter |
| line_of_business | No | Property | Line of business filter |
| scenario_name | No | 2025 Q3 Rate Filing | Which rate scenario to analyze |
| severity_filter | No | CRITICAL, HIGH | Which severity bands to include |
| top_n | No | 15 | Number of results to return |

## Instructions

When this skill is invoked, execute the following workflow:

### Step 1: Query Dislocation Data

Query the `Dislocation_Analysis` tool (SV_DISLOCATION semantic view) with:

```
SELECT 
    SEGMENT_NAME,
    COUNTY,
    REGION,
    HAZARD_ZONE,
    COASTAL_FLAG,
    DISLOCATION_SCORE,
    DISLOCATION_SEVERITY,
    AVG_RATE_CHANGE_PCT,
    LAPSE_PROPENSITY,
    RETENTION_RATE,
    LOSS_RATIO,
    COMPETITIVE_POSITION_INDEX,
    POLICY_COUNT,
    CURRENT_PREMIUM,
    PROPOSED_PREMIUM,
    PREMIUM_DELTA
FROM the dislocation analysis view
WHERE STATE = {state}
  AND DISLOCATION_SEVERITY IN ({severity_filter})
ORDER BY DISLOCATION_SCORE DESC
LIMIT {top_n}
```

### Step 2: Classify Results

Group the results into severity bands:
- **CRITICAL** (score >= 0.55): Immediate executive attention required
- **HIGH** (score >= 0.40): Requires pricing committee review
- **MEDIUM** (score >= 0.25): Monitor and assess mitigation options
- **LOW** (score < 0.25): Within acceptable parameters

### Step 3: Format Output

Present results as:

1. **Summary statement**: "X segments flagged as CRITICAL, Y as HIGH across Z counties"
2. **Ranked table** with columns: Segment, County, Score, Severity, Rate Change %, Lapse Risk, Policy Count, Premium Impact
3. **Key patterns**: Call out any geographic clusters or segment-wide patterns
4. **Premium at risk**: Total premium delta across flagged segments

## Output Contract

| Field | Type | Description |
|-------|------|-------------|
| ranked_segments | table | Segments ranked by dislocation score descending |
| severity_distribution | summary | Count of segments by severity band |
| total_premium_at_risk | currency | Sum of premium delta across flagged segments |
| geographic_clusters | text | Identified geographic concentrations |
| pattern_summary | text | Key patterns observed across results |

## Guardrails

- Never recommend specific rate changes or pricing actions
- Always state that results are based on model assumptions and require actuarial review
- If fewer than 3 segments are flagged, note this as a sign of a well-calibrated scenario
- Maximum output: 20 segments. If more qualify, state the count and show top 20.
- Always include the dislocation score formula components for transparency

## Score Formula Reference

```
Dislocation Score = 
    (Rate Change Component × 0.35) +
    (Lapse Risk Component × 0.25) +
    (Loss Ratio Component × 0.20) +
    (Concentration Component × 0.10) +
    (Competitive Position Component × 0.10)
```

Where each component is normalized to 0-1 scale before weighting.

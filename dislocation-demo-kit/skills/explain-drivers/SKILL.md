---
name: explain-drivers
description: Explains why a specific segment or geography is flagged as high dislocation risk by decomposing the score into its component drivers. Use when asked "why" a segment is flagged, or to explain drivers behind a dislocation result.
---

# Explain Drivers Skill

## When to Invoke

Invoke this skill when the user asks any of the following:
- "Why is [segment] flagged?"
- "What's driving the dislocation in [county/segment]?"
- "Explain the risk for [segment]"
- "Show me the drivers behind [result]"
- "What factors contribute to [segment's] score?"
- Any "why" question about a specific dislocation result

## Input Contract

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| segment_name | Yes* | - | The segment to explain (e.g., "Coastal Homeowner") |
| county | No | All FL counties | Specific county to focus on |
| state | No | FL | State filter |

*Either segment_name or county must be provided.

## Instructions

When this skill is invoked, execute the following workflow:

### Step 1: Retrieve Segment Detail

Query the `Dislocation_Analysis` tool for the specific segment/geography:

```
SELECT all dislocation metrics and driver columns
WHERE SEGMENT_NAME = {segment_name}
  AND STATE = {state}
  [AND COUNTY = {county} if specified]
ORDER BY DISLOCATION_SCORE DESC
```

### Step 2: Decompose the Score

For each result, break down the dislocation score into its 5 components:

| Driver | Weight | Raw Value | Weighted Contribution | Interpretation |
|--------|--------|-----------|----------------------|----------------|
| Rate Change | 35% | X% proposed increase | 0.XX | [High/Moderate/Low] |
| Lapse Risk | 25% | X% lapse propensity | 0.XX | [High/Moderate/Low] |
| Loss Experience | 20% | X% loss ratio | 0.XX | [High/Moderate/Low] |
| Concentration | 10% | X policies | 0.XX | [High/Moderate/Low] |
| Competitive Position | 10% | X.XX index | 0.XX | [High/Moderate/Low] |

### Step 3: Rank Drivers by Contribution

Sort the 5 drivers by their weighted contribution (descending) to identify which factors matter most for this specific segment.

### Step 4: Provide Plain-Language Explanation

For each of the top 3 drivers, provide a one-sentence explanation:

**Example format:**
> 1. **Rate Change (contributing 0.27 of 0.58 total)**: The proposed 32% rate increase is among the highest in the filing, approaching the maximum normalization threshold of 45%.
> 2. **Lapse Risk (contributing 0.09 of 0.58 total)**: This segment has a 36% lapse propensity — meaning roughly 1 in 3 policyholders is expected to non-renew if the increase is implemented.
> 3. **Loss Experience (contributing 0.14 of 0.58 total)**: A 72% loss ratio over the trailing 2 years indicates the rate increase is actuarially justified, but the magnitude creates customer disruption.

### Step 5: Contextual Insight

Add one of the following contextual observations where applicable:
- If rate change is the dominant driver: "The dislocation is primarily pricing-driven — consider phased implementation."
- If lapse risk dominates: "Retention is the primary concern — competitive alternatives likely exist."
- If loss ratio is high AND rate change is high: "This is a justified-but-disruptive increase — the segment is unprofitable but customers will resist."
- If concentration is high: "This segment represents outsized portfolio exposure — losses here compound rapidly."
- If competitive position < 0.85: "We are significantly above-market — customers have cheaper alternatives available."

## Output Contract

| Field | Type | Description |
|-------|------|-------------|
| segment_detail | table | Full metrics for the queried segment |
| driver_decomposition | table | 5-row table showing each driver's contribution |
| ranked_drivers | list | Top 3 drivers with plain-language explanations |
| contextual_insight | text | Business interpretation of the pattern |
| recommended_focus | text | Which lever (pricing, retention, competitiveness) to address |

## Guardrails

- Never state that a rate increase should be withdrawn — only describe the risk profile
- Always note that lapse propensity is a model estimate, not a certainty
- If the segment scores LOW despite the question, state this clearly rather than forcing an alarming narrative
- Reference the score formula for transparency
- If county is not specified, summarize across all counties where this segment operates and note geographic variation

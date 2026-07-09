---
name: executive-briefing
description: Generates a concise director-ready briefing summarizing dislocation findings, key risks, implications, and recommended actions. Use when asked to generate a briefing, summary, or executive overview.
---

# Executive Briefing Skill

## When to Invoke

Invoke this skill when the user asks any of the following:
- "Generate a briefing" or "create a summary"
- "Director briefing" or "executive summary"
- "Summarize the dislocation risks"
- "Prepare a briefing note for leadership"
- "What should I tell my boss about this?"
- Any request for a formatted business document or narrative output

## Input Contract

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| state | No | FL | State scope for the briefing |
| scenario_name | No | 2025 Q3 Rate Filing | Rate scenario being analyzed |
| focus_area | No | All CRITICAL/HIGH | Specific segment or county to focus on |
| format | No | full | full = complete briefing, summary = 3-paragraph version |

## Instructions

When this skill is invoked, execute the following workflow:

### Step 1: Gather Data

Query the `Dislocation_Analysis` tool for the top-risk segments:

```
Retrieve all CRITICAL and HIGH severity segments for the specified state/scenario
Include: segment, county, score, severity, rate change, lapse propensity, 
         retention rate, premium delta, policy count, driver columns
Order by dislocation score descending
Limit to top 10
```

### Step 2: Compute Summary Statistics

Calculate:
- Total segments flagged as CRITICAL
- Total segments flagged as HIGH
- Total premium at risk (sum of premium_delta for CRITICAL + HIGH)
- Total policies affected
- Geographic concentration (which counties appear most frequently)
- Average rate change across flagged segments

### Step 3: Generate Briefing

Format the output using the following structure:

---

## DISLOCATION ANALYSIS BRIEFING

**Date:** [Current date]
**Scenario:** [Scenario name]
**Scope:** [State] — [Line of Business]
**Classification:** Internal — For Director Review

---

### EXECUTIVE SUMMARY

[2-3 sentences summarizing the overall dislocation landscape. Include: number of critical/high segments, total premium at risk, and the single most important finding.]

---

### KEY FINDINGS

| # | Segment | County | Severity | Rate Change | Lapse Risk | Premium Impact |
|---|---------|--------|----------|-------------|------------|----------------|
| 1 | ... | ... | CRITICAL | XX% | XX% | $X.XM |
| 2 | ... | ... | CRITICAL | XX% | XX% | $X.XM |
| 3 | ... | ... | HIGH | XX% | XX% | $X.XM |
| 4 | ... | ... | HIGH | XX% | XX% | $X.XM |
| 5 | ... | ... | HIGH | XX% | XX% | $X.XM |

---

### TOP RISK DRIVERS

1. **[Driver 1]**: [One sentence explanation]
2. **[Driver 2]**: [One sentence explanation]
3. **[Driver 3]**: [One sentence explanation]

---

### GEOGRAPHIC CONCENTRATION

[Which counties/regions show clustering of high-risk segments. Note any patterns.]

---

### IMPLICATIONS

- **Revenue risk**: [Premium at risk if lapse occurs at predicted rates]
- **Portfolio stability**: [Impact on book composition if high-risk segments lapse]
- **Competitive exposure**: [Where market alternatives exist for affected customers]

---

### RECOMMENDED ACTIONS

1. [Specific actionable recommendation]
2. [Specific actionable recommendation]
3. [Specific actionable recommendation]

---

### DATA NOTES & CAVEATS

- Dislocation scores are model-based estimates using a weighted composite formula
- Lapse propensity reflects historical patterns and may not capture all current market dynamics
- Competitive position index is based on available market data and may lag actual market rates
- All findings require actuarial and pricing committee review before action

---

### Step 4: Tone and Style Rules

- Write for a time-constrained executive (< 2 minute read for summary, < 5 minutes for full)
- Lead with conclusions, not methodology
- Use specific numbers, not vague qualifiers
- Bold the single most important insight
- Recommendations must be actionable and specific (not "monitor the situation")
- Never use jargon without definition on first use

## Output Contract

| Field | Type | Description |
|-------|------|-------------|
| briefing_document | formatted text | Complete structured briefing |
| headline_finding | text | Single most important takeaway (1 sentence) |
| premium_at_risk | currency | Total premium delta for CRITICAL + HIGH segments |
| segments_flagged | number | Count of CRITICAL + HIGH segments |
| recommended_actions | list | 3 specific next steps |

## Guardrails

- Never recommend withdrawing or reducing a rate filing
- Frame recommendations around mitigation, phasing, or targeted retention strategies
- Always include the Data Notes & Caveats section
- If no CRITICAL segments exist, frame the briefing positively ("scenario is well-calibrated")
- Maximum briefing length: ~800 words for full format, ~200 words for summary format
- Do not include policyholder names, agent names, or personally identifiable information

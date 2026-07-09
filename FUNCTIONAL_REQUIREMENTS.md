# Pricing Dislocation Analysis — Agentic Analytics Functional Requirements

## 1. Document purpose

This document defines the functional requirements for an insurance-focused agentic analytics solution that can be used as input context for **Cortex Code / CoCo** to generate implementation assets, deployment scripts, semantic models, agent configuration, prompt files, and demo documentation.

The target outcome is to reduce the manual effort insurance directors and analysts currently spend stitching together insights across multiple dashboards and move toward an on-demand, governed, conversational intelligence experience aligned to the broader industry shift from static reporting to agentic analytics.

## 2. Business problem statement

Insurance directors currently spend meaningful time manually combining signals from multiple reporting assets to answer pricing and portfolio questions. The first target use case is **dislocation analysis**, beginning with property pricing and portfolio dislocation scenarios such as identifying pricing dislocation in the Florida property market.

The desired end state is not a new long tail of dashboards. The desired end state is a governed library of reusable analytical skills, semantic assets, and agents that can understand a business goal, execute the appropriate logic, and return immediate answers, tables, charts, and briefing-ready outputs.

## 3. Product vision

The solution should provide a **conversational intelligence layer** over trusted insurance data that:

- answers natural-language business questions using governed structured and unstructured data
- centralizes business logic in Snowflake semantic assets rather than embedding logic in dashboards
- uses agents and reusable skills to codify analyst workflows
- respects Snowflake governance controls such as row access and column-level security
- returns explainable outputs with traceability, SQL transparency where relevant, and reusable artifacts

## 4. Use case definition

### 4.1 Primary use case: pricing dislocation analysis

The system must support dislocation analysis for insurance pricing and retention decisions.

For this document, dislocation analysis means identifying where proposed pricing, underwriting, or portfolio changes create materially adverse disruption across segments, channels, geographies, or policy cohorts, especially where profitability, retention, and fairness must be balanced. External insurance references consistently frame dislocation analysis around the relationship between price change, portfolio mix, profitability, and customer retention behavior.

### 4.2 Example business questions

The solution must support prompts such as:

- Find pricing dislocation in the Florida property market.
- Which policy segments would see the largest premium increase under the proposed rate plan?
- Which segments combine high premium uplift with high lapse propensity?
- Where are we over-indexed on profitable but retention-sensitive policyholders?
- Summarize the top 5 dislocation risks for Florida property and generate a director briefing.
- Show the drivers behind the dislocation result and the variables used.
- What changed this month versus last month in the segments at greatest dislocation risk?

### 4.3 Secondary use cases

The design should also be extensible to:

- claims portfolio dislocation
- retention and lapse behavior analysis
- underwriting drift or mix-shift detection
- supply chain / contingent BI exposure analysis for commercial books
- briefing document generation for leaders

## 5. Personas

The solution must support distinct personas:

1. **Director / executive consumer**
   - asks business questions
   - receives charts, tables, and executive summaries
   - does not write SQL

2. **Pricing / actuarial analyst**
   - refines dislocation logic
   - validates drivers and assumptions
   - reviews segment-level outputs
   - may inspect SQL and semantic definitions

3. **Business analyst**
   - asks follow-up questions
   - filters by geography, line, channel, or segment
   - exports artifacts for business review

4. **Data / analytics engineer**
   - builds data pipelines, semantic models, skills, and agent configuration
   - manages deployment and observability

5. **Platform / governance admin**
   - manages roles, access, warehouse usage, budgets, and auditability

## 6. Scope by phase

## 6.1 Phase 1: build now

Phase 1 should use currently available and production-sensible capabilities centered on **Snowflake Intelligence**, **Cortex Agents**, **semantic views**, **Cortex Code**, and standard Snowflake governance patterns.

Phase 1 includes:

- a governed semantic model for dislocation analysis
- one primary agent for pricing dislocation analysis
- a small reusable skill library for core analytical workflows
- conversational Q&A with charts/tables
- artifact generation for saved charts/tables/outputs
- executive briefing generation
- role-based access controls
- cost controls and usage monitoring
- implementation in a Snowflake-native pattern rather than custom orchestration first

## 6.2 Phase 2: near-term extension

Phase 2 should expand into newly released or recently announced capabilities where account readiness and customer eligibility permit, including:

- **Skills** in Snowflake Intelligence / Cortex ecosystem
- **MCP connectors** for external systems and tools
- broader workflow automation and action-taking
- richer chart customization and expanded visualization options
- artifact sharing and collaboration patterns where allowed

## 6.3 Phase 3: future-state roadmap

Phase 3 should evaluate additional preview or roadmap capabilities once mature enough for use, including:

- **Deep Research** style multi-step research workflows
- **Agent memory** for more persistent organizational context
- **multi-agent / A2A orchestration** when broadly supported rather than emulated via workaround patterns
- mobile or field consumption scenarios where relevant

## 7. Solution principles

1. **Semantics before dashboards**
   Business logic must live in Snowflake semantic assets, not hidden inside reports.

2. **Skills over one-off analyses**
   Repeatable analyst logic should be codified into reusable skills, prompts, or tool patterns rather than rebuilt per dashboard or request.

3. **Conversational but governed**
   Users should interact in natural language, but responses must inherit Snowflake RBAC and data governance.

4. **Explainable outputs**
   The system should show definitions, assumptions, calculations, SQL where appropriate, and source traceability.

5. **Build for consumption first**
   Phase 1 should prioritize solving the director use case with high-value, low-friction outputs rather than attempting full end-to-end automation.

## 8. Functional requirements

## 8.1 Data ingestion and modeling

The solution must:

- ingest or access the required structured insurance data for policy, premium, exposure, claim, retention, and geographic analysis
- support integration of external market, hazard, or competitor signals where available
- create trusted modeled tables or views for dislocation analysis
- support both point-in-time analysis and trend-over-time analysis
- maintain lineage from raw inputs to semantic outputs

### Minimum logical entities

The model should include, at minimum:

- policy
- insured / customer segment
- account or household
- product / line of business
- geography (state, county, ZIP or territory as appropriate)
- premium history
- proposed premium / rate scenario
- claims frequency
- claims severity
- incurred loss / paid loss / reserve
- loss ratio
- lapse / retention outcome
- competitiveness index if available
- analyst-defined dislocation features

## 8.2 Semantic layer

The solution must provide one or more semantic assets that expose business-friendly dimensions and metrics for:

- current premium
- proposed premium
- premium delta
- premium change percent
- claim frequency
- claim severity
- loss ratio
- retention rate
- lapse propensity
- competitive position
- catastrophe / peril exposure
- segment-level dislocation score
- explainability driver columns

Semantic assets must be documented with business names, definitions, and acceptable usage patterns.

## 8.3 Core skill library

Phase 1 must include an initial library of reusable skills or equivalent reusable analytical workflows.

### Required Phase 1 skills

1. **dislocation-score**
   - calculates segment- or policy-level dislocation score
   - uses agreed input variables and weights or model logic
   - returns top drivers and severity bands

2. **retention-risk**
   - estimates lapse sensitivity and retention exposure by segment
   - highlights combinations of large price change and high lapse propensity

3. **market-hotspot-summary**
   - identifies geography-based concentrations of dislocation
   - summarizes state / region / territory outliers

4. **explain-drivers**
   - decomposes a dislocation score into its weighted driver components
   - returns plain-language explanations for the top contributing factors

5. **executive-briefing**
   - generates a concise briefing with findings, risks, implications, and next actions

### Future skills

Future phases should consider:

- chart-builder skill
- report / memo generation skill
- external action or workflow trigger skill
- portfolio monitoring skill
- alert triage skill
- multi-agent routing skill when platform support matures

## 8.3.1 Translating skills into deployable assets

In the functional specification, a **skill** should not be treated as a vague capability label. In implementation, each skill must map to a concrete, versioned set of deployable assets that Snowflake Intelligence or a Cortex Agent can orchestrate at runtime.

The practical translation is:

- the **agent** performs orchestration and decides which unit of work to invoke
- the **skill** defines a reusable unit of work, including instructions, inputs, constraints, and any supporting scripts
- the **semantic layer** supplies governed business context and structured retrieval surfaces
- the **execution assets** perform the actual work, such as SQL queries, semantic-view retrieval, search, UDFs, stored procedures, or code execution where enabled
- the **artifact/output contract** defines the expected return type, such as table, chart-ready dataset, hotspot summary, or executive briefing

This aligns with Snowflake's agent model, where agents are configured with tools and orchestration logic, and skills are modular packages of instructions, scripts, and context that can be referenced from a named stage or Git repository and discovered automatically by the agent.

### Skill implementation contract

Each Phase 1 skill in this specification must be implemented as the following deployable asset bundle:

1. **Skill definition**
   - a named skill folder with a root `SKILL.md`
   - concise description of when the skill should be invoked
   - explicit input contract
   - explicit output contract
   - routing guidance for the orchestrating agent
   - guardrails, exclusions, and failure behavior

2. **Prompt and instruction assets**
   - system or skill instructions
   - analyst logic in structured markdown
   - examples of supported prompts
   - business definitions and reasoning guidance

3. **Execution assets**
   - semantic views for structured retrieval
   - SQL statements, verified query patterns, or parameterized query templates
   - optional UDFs or stored procedures for reusable calculation logic
   - optional code files only where code execution is required and enabled on the agent

4. **Data contract assets**
   - source mapping to semantic adapter views
   - grain definition
   - allowed filters
   - metric definitions
   - freshness expectations

5. **Operational assets**
   - privileges and role requirements
   - deployment path in named stage or Git
   - environment configuration for dev, test, prod
   - monitoring expectations
   - rollback and versioning approach

### Recommended runtime mapping

The skill names in the functional spec should map to deployable runtime patterns as follows:

| Functional skill | Primary deployable assets | Runtime behavior |
| :---- | :---- | :---- |
| `dislocation-score` | semantic view, metric definitions, optional SQL/UDF/procedure wrapper, `SKILL.md` | computes dislocation metrics and returns scored segments or policies |
| `retention-risk` | semantic view, retention logic, optional model score table, `SKILL.md` | retrieves lapse-sensitive cohorts and combines them with premium change context |
| `market-hotspot-summary` | geography-ready semantic view, aggregation SQL, `SKILL.md` | ranks outlier regions and summarizes concentrations |
| `explain-drivers` | driver decomposition logic, `SKILL.md` | decomposes score into weighted driver components |
| `executive-briefing` | summary prompt template, formatting instructions, optional artifact/report logic, `SKILL.md` | turns structured findings into a concise director-ready narrative |

### Design rule: skills should call stable contracts, not raw tables

To keep the solution portable across customer environments, skills must not be hard-coded to raw physical table names. Skills should call one of the following stable contracts instead:

- semantic views
- adapter views
- approved stored procedures
- approved UDFs
- approved search services

This allows the same skill to survive remapping from demo data to customer production objects without rewriting skill instructions.

### Deployability model

The recommended deployability model is:

1. store skill folders in a **Snowflake named stage** or **Git repository**
2. register or reference those skills in the **agent specification**
3. grant the agent the required access to the referenced stage, Git integration, semantic objects, and execution surfaces
4. use Snowsight, SQL, or REST API to update the agent configuration
5. validate invocation paths and monitor skill selection during test conversations

### Separation of concerns

The implementation should separate responsibilities clearly:

- **semantic views** answer "what data and metrics mean"
- **skills** answer "how to perform a repeatable analytical task"
- **agents** answer "when to invoke which skill or tool"
- **applications / Snowflake Intelligence UX** answer "how the user interacts with the system"

This is important because some use cases may be best solved with direct semantic retrieval and light orchestration, while others may require a richer skill with specific instructions, formatting, or code-backed execution.

### Packaging standard for Phase 1

Each Phase 1 skill should be packaged with:

- `SKILL.md`
- optional SQL files
- optional Python or helper scripts only if required
- sample input prompts
- expected output examples
- dependency notes
- version identifier
- owner
- test cases
- known limitations

All supporting files for a skill should remain in the same folder as the `SKILL.md` file for clean discovery and portability.

### Operational requirements for production readiness

A skill is considered operational only when it has:

- a named owner
- a business definition for each metric it uses
- a defined execution path
- role and privilege requirements documented
- test prompts and expected outputs
- monitoring visibility in agent thinking steps or related dashboards
- version control and rollback path
- a clearly documented token and output-size strategy

This last requirement matters because agent tool outputs can be truncated at size limits, so large payloads should be summarized, paginated, or reshaped rather than blindly returned as long free-form text.

## 8.4 Agent requirements

Phase 1 must include at least one primary agent:

### Agent name

**DISLOCATION_ANALYSIS_AGENT** (working name)

### Agent responsibilities

The agent must:

- answer natural-language questions about pricing dislocation
- choose the correct semantic asset and skill for the question
- return concise natural-language answers
- produce charts or tables when appropriate
- provide drill-down from portfolio to segment to geography
- provide reason codes / top drivers for flagged dislocation
- generate a leader-ready summary or briefing
- preserve governance and role-based visibility

### Example prompts

- Find pricing dislocation in Florida property.
- Show segments with premium increases above 15% and expected retention risk above threshold.
- Summarize the top drivers of dislocation for coastal homeowner policies.
- Build a briefing note for directors on this week's dislocation hotspots.
- Compare current dislocation risk with the prior quarter.

## 8.5 Conversational analytics UX

The system must support:

- natural-language prompts
- follow-up questions in context
- chart and table generation
- downloadable or savable artifacts
- regenerated outputs after filter changes
- a transparent path from answer to underlying logic and data

Phase 1 should assume business users interact primarily through **Snowflake Intelligence** or a Snowflake-backed application using the same APIs and semantic constructs.

## 8.6 Output types

The solution must be able to generate:

- short direct answers
- tabular result sets
- charts for comparisons, trends, and outliers
- executive summary narratives
- briefing documents
- saved artifacts for review and sharing

## 8.7 Governance and access control

The solution must:

- inherit and enforce Snowflake RBAC and row/column security
- support business-unit or role-based scoping where needed
- prevent users from seeing unauthorized segment or market data
- log access and usage
- support environment separation for dev / test / prod
- support cost tagging and resource budgets

### 8.7.1 Dynamic data masking on claims PII

The claims detail data contains personally identifiable information (claimant names, attorney names) that must be masked for non-analyst roles. The solution must implement:

- A **claims detail view** (`VW_CLAIMS_DETAIL`) joining claims with policy, geography, segment, and peril dimensions
- PII columns: `CLAIMANT_NAME`, `ATTORNEY_NAME` (synthetic data for the demo)
- Non-PII columns visible to all roles: `LITIGATION_FLAG`, `INCURRED_LOSS`, `SEVERITY_BAND`, `LOSS_DESCRIPTION`, and all other fields
- A **Snowflake dynamic masking policy** (`MASK_PII_NAME`) applied to CLAIMANT_NAME and ATTORNEY_NAME that:
  - Returns full values for the Analyst role and ACCOUNTADMIN
  - Returns `'●●●● REDACTED ●●●●'` for the Director role and all other roles
- A **semantic view** (`SV_CLAIMS_DETAIL`) exposing the claims detail view to the agent
- The **agent** must include a `Claims_Detail` tool pointing to this semantic view
- Both Director and Analyst roles must have SELECT on the claims detail view — the masking policy controls column-level visibility, not row-level access

**Demo behavior**: When both Director and Analyst ask "Show claims in Florida with claimant details":
- Both get the same rows in the same order
- Analyst sees real names (e.g., `Nancy Clark`, `Fasig | Brooks`)
- Director sees `●●●● REDACTED ●●●●` for name columns
- LITIGATION_FLAG, dollar amounts, and all other columns are identical for both roles

This demonstrates Snowflake governance flowing transparently through a Cortex Agent with no application-layer masking code.

## 8.8 Auditability and transparency

The system must provide:

- SQL visibility for analytical responses where appropriate
- source traceability
- prompt / response observability
- usage monitoring
- clear metric definitions
- reproducibility of repeat analyses where possible

## 8.9 Cost management

The solution must support:

- tagging of Snowflake Intelligence objects for budget attribution
- budget thresholds and alerting
- account-level or project-level usage visibility
- ability to restrict or revoke access if spend exceeds agreed thresholds

## 9. Non-functional requirements

The solution should meet the following non-functional requirements:

- **Performance:** common questions should complete in seconds for standard portfolio slices
- **Usability:** business users should not need SQL knowledge
- **Explainability:** top drivers and data sources should be available for material conclusions
- **Security:** access must follow enterprise and Snowflake security controls
- **Scalability:** design must support additional use cases without redesigning the core pattern
- **Maintainability:** business rules should be editable in semantic assets, skill definitions, or governed config rather than embedded in app code
- **Extensibility:** architecture should allow future MCP, Skills, Deep Research, and multi-agent patterns where supported

## 10. Phase 1 implementation approach

## 10.1 Recommended build pattern

Phase 1 should be positioned as a **semantic and agentic overlay on the customer's existing Snowflake deployment**, not as a request to replace or remodel their current data foundation.

Phase 1 should follow this pattern:

1. inventory the customer's existing data layers and identify the current business-consumption surfaces already trusted by analysts
2. map the dislocation use case to the existing consumption-ready assets rather than reading raw source tables directly for business consumption
3. define a thin semantic contract layer for the demo using business-friendly names, stable metric definitions, and configurable source mappings
4. encode the first analyst workflow into reusable skills / prompts that call the semantic contract layer rather than hard-coded physical table names
5. configure one primary dislocation agent against those semantic assets
6. enable Snowflake Intelligence or equivalent app consumption
7. validate responses with pricing and actuarial SMEs against existing outputs and known benchmarks
8. add executive-briefing and artifact outputs
9. instrument cost, logging, telemetry, and access controls

This aligns with Snowflake's internal BI modernization lessons: prioritize semantics, reusable foundations, thin consumption layers, and agent-ready assets rather than rebuilding dashboard sprawl.

## 10.2 Demo interoperability with existing data architecture

The demo must be structured so it is **translatable to the customer's current Snowflake architecture** even if physical object names, zone boundaries, or domain ownership differ from the demo environment.

### Interoperability principles

- do not assume the customer will expose raw vault objects directly to business users or agents
- do not force a new enterprise data model for Phase 1
- treat existing data integration layers as the system of integration and history, not necessarily the direct system of conversational consumption
- prefer existing consumption-ready objects where the customer already applies business rules
- isolate all demo logic behind a **logical semantic contract** so the same prompts, skills, and agent instructions can survive physical remapping

### Required translation layer

The demo should introduce a translation layer with the following components:

1. **Logical business entities**
   - policy
   - customer or insured segment
   - geography
   - premium history
   - proposed rate scenario
   - claims and loss metrics
   - retention / lapse measures
   - dislocation score inputs and outputs

2. **Source mapping manifest**
   - for each logical entity and metric, document the customer source object(s)
   - identify whether the source comes from raw, curated, data mart, external share, or off-platform source
   - capture join keys, grain, refresh cadence, and owner

3. **Semantic adapter views**
   - create views or semantic objects that expose stable names regardless of underlying physical model
   - allow the same agent and skills to run against demo data today and customer data later by changing mappings rather than rewriting prompts

4. **Metric contract**
   - define each metric once, including dislocation score, premium delta, lapse risk, profitability, and segment concentration
   - store the approved business definition separate from report logic and separate from app code

### Guidance for Data Vault environments

If the customer is using Data Vault 2.0, the demo should assume the following target pattern:

- **Raw Vault** remains the integration and historization layer
- **Business Vault / PIT / Bridge** are used where needed to simplify complex join paths and time-aware analysis
- **Curated / Data Mart / semantic views** become the primary agent consumption layer for Phase 1
- if a required metric does not yet exist in a trusted consumption layer, create a demo adapter object that clearly shows how it would be implemented without requiring a full remodel

The goal is to show that Snowflake Intelligence and Cortex Agents sit **above** the existing data model, not beside it and not in conflict with it.

## 10.3 Handling data that resides outside Snowflake

The demo should explicitly support a mixed-source architecture because some required data may already be in Snowflake while other inputs remain in external systems.

### Source tiers for the demo

**Tier 1 — Snowflake-native sources**

- existing telemetry and usage signals already available in Snowflake
- existing insurance policy, claims, premium, and retention data already landed in Snowflake
- existing semantic or mart objects already trusted by business users

**Tier 2 — Snowflake-adjacent sources**

- shared data products
- replicated datasets
- external tables / Iceberg / staged extracts
- governed batch snapshots from systems that are not yet fully onboarded

**Tier 3 — Off-platform sources**

- policy admin, actuarial, or market systems not yet available in Snowflake
- these should be represented in the demo through a defined interface contract, placeholder dataset, or manually refreshed extract rather than hidden assumptions

### Demo behavior when some sources are missing

The demo should degrade gracefully:

- answer with available Snowflake-native signals first
- clearly identify which portions of the analysis are complete versus estimated or unavailable
- allow the briefing output to call out missing external inputs
- avoid hard dependencies on a fully centralized data estate for the Phase 1 story

## 10.4 Telemetry-driven tailoring

If Snowflake telemetry can be gathered from the customer's existing deployment, it should be used to tailor the demo to their actual operating model.

Telemetry should be used to:

- identify which domains, marts, and schemas are actively used by human analysts today
- identify whether analysts primarily consume from Curated, Data Mart, or other semantic-ready layers
- detect which workloads already support pricing, property, claims, or actuarial analysis
- identify the dashboards, tools, warehouses, and query patterns most relevant to the current manual workflow
- infer where dislocation analysis inputs already exist inside Snowflake versus where external enrichment is still required

This allows the demo to be framed as a **natural extension of the customer's current deployment** rather than a theoretical future-state architecture.

## 10.5 Recommended technical stack for Phase 1

- Customer's existing Snowflake data platform
- semantic views / governed semantic layer / adapter views
- Cortex Agents
- Snowflake Intelligence
- Cortex Code / CoCo for build acceleration
- standard Snowflake governance controls
- resource budgets / usage views for cost management
- optional external-source adapters or staged extracts for out-of-platform data

## 10.6 Recommended demo narrative

The demo should be presented in this order:

1. start from the current-state problem: directors stitching answers across dashboards
2. show that the customer already has the data foundation and does not need to throw away their existing investment
3. show the semantic contract layer that translates existing objects into business-ready agent inputs
4. run the dislocation analysis agent against a Florida property scenario
5. show follow-up questions, drill-down, drivers, and briefing generation
6. show where Snowflake-native telemetry enriches the experience immediately
7. show which additional insights become available once external sources are onboarded
8. close with a clear separation between **build now with current Snowflake data** and **expand later as more sources are connected**

## 11. Preview and roadmap considerations

## 11.1 Use now or soon

The following are reasonable candidates for planning assumptions or near-term adoption, subject to account readiness:

- Snowflake Intelligence as the business-user conversational layer
- Artifacts for saved charts and tables
- Skills as a rapidly maturing capability / near-term extension
- MCP connectors as a near-term extension
- Resource Budgets for controlled rollout

## 11.2 Treat as roadmap / future-state

The following should be described as future-state unless confirmed in the target account:

- Deep Research
- Agent Memory
- fully supported multi-agent / A2A orchestration

## 12. Acceptance criteria

Phase 1 is successful when:

1. a director can ask a natural-language dislocation question and receive a correct, explainable answer with a chart or table
2. the same answer logic is driven by governed semantic assets, not dashboard-specific logic
3. the agent can identify at-risk segments by geography and portfolio slice
4. the system can produce an executive briefing for a selected scenario
5. analysts can inspect drivers and SQL or equivalent calculation logic
6. access controls correctly restrict data based on role
7. usage and cost can be monitored and limited
8. the implementation pattern is reusable for at least one adjacent use case after dislocation analysis

## 13. CoCo deliverables required from this document

CoCo should use this document to generate:

- SQL deployment scripts
- semantic model / semantic view definitions
- sample synthetic or test datasets if real data is unavailable
- agent configuration
- skill definitions and prompt files
- README / runbook
- governance and RBAC documentation
- architecture outline
- pilot demo script
- executive briefing templates

## 14. Open questions for project kickoff

The following must be resolved before implementation begins:

1. what exact data sources will be in scope for Phase 1?
2. what is the authoritative definition of dislocation for this business unit?
3. what are the minimum required variables for the first scoring model?
4. is Florida property the sole pilot scope or the first of several markets?
5. what user roles need access in pilot?
6. should consumption be via Snowflake Intelligence UI first, embedded app first, or both?
7. which external sources, if any, should be integrated in later phases?
8. which preview capabilities is the customer willing to adopt versus keep as roadmap only?

## 15. Recommended first build slice

To minimize delivery risk, the first build slice should be:

- one line of business: **property**
- four geographies: **FL, TX, LA, CA** (each with distinct peril profiles)
- one core question: **where proposed pricing change creates the highest dislocation risk**
- one director persona
- one analyst persona
- three semantic views (dislocation, portfolio, claims detail)
- one primary agent with four tools
- five reusable skills
- one executive briefing output
- dynamic data masking on claims PII (claimant/attorney names)

This is enough to prove the move from dashboard stitching to governed agentic analytics without overcommitting to platform features that are still maturing.

## 16. Using Cortex Code to build this demo

The fastest path to a working demo is to paste this functional requirements document into **Cortex Code (CoCo)** and instruct it to build the full deployment in your Snowflake account.

### Recommended CoCo prompt

```
Using the attached functional requirements document, build a complete Snowflake-native
dislocation analysis demo in my connected Snowflake account. Include:
- All tables with synthetic multi-state data (FL, TX, LA, CA)
- Adapter views with dislocation scoring logic
- Semantic views for agent consumption
- A Cortex Agent with 5 skills
- All skill SKILL.md files uploaded to stage
- RBAC roles for director and analyst personas
- Verification queries to confirm the build

Use the install.sql script as a reference for the expected schema.
```

### What CoCo generates

CoCo will produce:
- All database objects (tables, views, semantic views, agent)
- Synthetic test data across 4 states with realistic insurance characteristics
- A fully configured agent with skill routing
- Verification SQL to confirm the build works

### Alternative: run the deployment script directly

If you prefer deterministic deployment, run `./setup.sh`. It sources `.env/dislocation.env`, executes the numbered SQL files in `sql/` (in order) via the Snowflake CLI, uploads the agent skills to the stage, and verifies the build. The lab is CLI-deployed and consumed from Cortex Code (`cortex agents run`, `cortex analyst query`) — Snowsight is not required. See `README.md` for the full lab flow.

## 17. Final guidance

Use this document as the master requirements file for a **Snowflake-native dislocation analysis agentic analytics project**. Optimize for:

- fast Phase 1 value
- semantic consistency
- governed answers
- reusable skills
- explainability
- clean upgrade path from current-state conversational analytics to future-state action-taking and multi-agent workflows

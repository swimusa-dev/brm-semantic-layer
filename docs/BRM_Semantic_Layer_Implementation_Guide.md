# BRM Semantic Layer Implementation Guide

**Building the agent-ready semantic layer over the Brand Road Map Gold layer in Databricks**

Prepared for: Dave Christy, Swim USA
Grounded in: Koantek and Swim USA Handover Document (BRM Bronze, Silver, Gold, Security Layer, App 1, App 2)
Date: August 2026

---

## How this guide is organized

The guide is sequenced into eight phases you and your Databricks/Power BI engineer can work through in order. Each phase states what you are building, why it matters for agent consumption, the actual SQL or YAML against your real objects in `swim_data_whse`, and any decision you need to make before proceeding. Decisions are collected in a register at the end of Phase 0 and referenced by ID (D1, D2, ...) throughout.

Three findings from your handover document change the recommended approach materially versus a standard metric-view implementation. They are worth reading before anything else:

1. **Your RLS lives inside view SQL, not in Unity Catalog row filter policies.** Every secured Gold view embeds `swim_data_whse.productops_gold.fn_brand_access_filter(brand_id)` in its WHERE clause, evaluated against `CURRENT_USER()`. That means any consumer that touches the underlying Gold Delta tables (`dim_brand`, `bridge_brand_person`, and the rest) bypasses security entirely, because the tables are deliberately unfiltered for the `gold_merge()` pipeline. A standard guide would build metric views directly on Gold tables. Here, every semantic object must source from the `gold_v_*` secured views until (or unless) you migrate the filter to a native `ROW FILTER` policy on the tables themselves (Decision D2).

2. **App 1's service principal pattern must not be extended to agents.** App 1 runs its SQL as service principal `app-2d1tu0 app1-view-only`, registered in `user_person_map` with `role = 'admin'` so it can read all brands, and then filters the UI client-side using the `X-Forwarded-Email` header. That is acceptable inside a trusted app whose filtering code Koantek wrote and you control. An LLM agent has no equivalent trusted filtering layer: an agent whose service principal carries `role = 'admin'` will hand every brand to anyone who prompts it. Agent identities need either on-behalf-of user authentication (the human's own identity flows through) or a deliberately scoped service principal registered as `role = 'user'` with explicit brand assignments (Decision D3).

3. **Agents can silently see zero rows and it will look like "no data."** `fn_brand_access_filter` is default-deny: an unmapped identity, an identity with `is_active = false`, or `role = 'no_access'` gets zero rows from every secured view, with no error. Genie behaves the same way, returning an empty response when the asking user lacks access. Your validation plan (Phase 6) must therefore distinguish "identity not mapped" from "data absent," or you will chase phantom data-quality issues.

---

## Phase 0: Prerequisites and the decision register

### 0.1 Confirm platform prerequisites

Work through this checklist first; everything later depends on it.

- Unity Catalog metric views require a SQL warehouse or compute on a current channel. YAML version 1.1 features used in this guide (display names, synonyms, one-to-many joins) require Databricks Runtime 18.1+ (18.2+ for one-to-many joins and wildcards). Serverless SQL warehouses on the current channel qualify. You already run Serverless SQL Warehouses for App 1 and App 2, so this is a verification step, not new infrastructure.
- Databricks managed MCP servers (Genie, SQL, Unity Catalog Functions endpoints) are in Public Preview. Confirm the preview is enabled for the workspace (Settings, Previews) before Phase 5.
- Confirm the account-level OAuth settings allow creating OAuth app connections for external clients (needed for Claude Cowork in Phase 5).
- Verify the objects this guide builds on exist as documented, since counts drift:

```sql
-- Run as an admin (you are mapped as admin in user_person_map)
SELECT count(*) FROM swim_data_whse.productops_gold.dim_brand WHERE is_current = true;          -- doc: 138
SELECT count(*) FROM swim_data_whse.productops_gold.dim_brand WHERE is_current AND is_active;   -- doc: ~53-54
SELECT count(*) FROM swim_data_whse.productops_gold.user_person_map WHERE is_active = true;
SHOW VIEWS IN swim_data_whse.productops_gold LIKE 'gold_v_*';                                    -- doc: 8 views + summary
DESCRIBE FUNCTION EXTENDED swim_data_whse.productops_gold.fn_brand_access_filter;
```

### 0.2 Create the semantic schema

Keep semantic objects out of `productops_gold` so grants stay clean: the Gold schema remains pipeline-and-app territory, and the semantic schema becomes the only surface agents are granted.

```sql
CREATE SCHEMA IF NOT EXISTS swim_data_whse.productops_semantic
COMMENT 'Certified semantic layer for the Brand Road Map (BRM). Metric views and agent-facing helper views only. All objects source from RLS-secured gold_v_* views. Agents and BI tools read here; nothing writes here except the semantic deployment pipeline.';
```

### 0.3 Decision register

**Status: all seven decisions APPROVED at the 2026-08 workshop.** The signed record is BRM_Semantic_Layer_Decision_Log.xlsx in the project folder; the final decision text below supersedes the original recommendations where they differ.

**D1. Canonical metric definitions. APPROVED (Stephen Nicolello, 2026-08-28).** Signed definitions, all computed on current SCD records: **Active Brands** = distinct brand_id where business status is Active. **All Brands** (the signed name; formerly "Total Brands") = distinct brand_id across current records, including Dropped brands. **Active Division Count** = distinct divisions associated with Active Brands. **Active People** = distinct active person_id across the company. **Active Brand-Assigned People** = distinct active person_id with at least one current assignment to an Active Brand. Assignment counts, when needed, must be reported separately and must not be presented as people counts. Changing any of these is now a governed change requiring Product Ops approval.

**D2. Where RLS lives long-term. APPROVED (Dave Christy, 2026-08-31): keep the view-embedded Koantek design now; native ROW FILTER migration is scheduled as its own later change with its own testing.** For that future change: the native row filter protects every consumption path automatically, but requires exempting `gold_merge()`'s pipeline principal (row filters apply to pipelines too) and re-testing the security perimeter App 1 and App 2 were built against.

**D3. Agent identity model for the external (Claude Cowork) path. APPROVED (Dave Christy, 2026-08-27): users authenticate to agents and Databricks via their Entra ID** (OAuth on-behalf-of for interactive use), with dedicated scoped service principals for scheduled/unattended jobs, and never a shared admin-role credential. Mechanics in Phase 5.

**D4. Whether agents may see governance state (pending edits). APPROVED (Stephen Nicolello, 2026-08-28):** assistants may disclose that an authorized edit request is pending and report its governance status, exclusively through the restricted `gold_v_brm_pending_edits` view (Phase 4.4). Assistants must not expose proposed values, treat proposed changes as current facts, or query `brm_edit_requests` directly; the only grant in the audit schema's direction is on the restricted view.

**D5. Whether agents may see SCD2 history. APPROVED (Stephen Nicolello, 2026-08-28): current-state only at launch.** Historical questions are unsupported until Koantek publishes a governed historical semantic view, and assistants must state plainly that history is unavailable (not merely decline). True history remains in Silver (`brm_brand_staging` versions, `productops_silver.brand_history`) and stays out of the agent surface.

**D6. Division and code vocabularies. APPROVED (Stephen Nicolello, 2026-08-28) with a structural condition:** Dave extracts candidate code-to-name mappings from Qlik; Product Ops must validate each code, business label, vocabulary type, and status before publication; and division, classification, and category remain **separate governed vocabularies** (`ref_division`, `ref_classification`, `ref_category`), never combined into one table. Only validated (Published) rows enter the agent surface. Execution in Phase 7.2.

**D7. Person identity for agent service principals. APPROVED (Dave Christy, 2026-08-27), refined as built (2026-09-04):** dedicated Databricks service accounts registered as apps and mapped in `user_person_map` by client ID with `person_id` NULL; brand scope lives in the manually governed `agent_brand_scope` table (checked by `fn_brand_access_filter` v1.1.0 path 3) rather than synthetic persons in the bridge, because the bridge is pipeline-managed and would close injected rows. Agents therefore never appear in `dim_person` or staffing analytics at all. Never reuse a human's identity for an agent.

---

## Phase 1: Harden the Gold contract for machine consumers

**Goal:** make the existing secured views self-describing and formally keyed, so both the metric-view compiler and LLMs get reliable structure, without touching the pipeline.

### 1.1 Declare primary and foreign keys on the Gold tables

Informational PK/FK constraints do two jobs here: they let the metric-view compiler and Genie reason about join cardinality, and they are the single strongest anti-hallucination signal an LLM gets about how tables relate. Constraints attach to tables, not views, which is fine: they describe structure, while reads still go through the views.

Note the SCD2 nuance: `dim_brand` holds history, so `brand_id` alone is not unique at the table level. Declare the PK as informational with `NORELY` unless you first verify uniqueness of the current slice; the honest declaration for an SCD2 table is the composite key.

```sql
-- Composite natural key on SCD2 dimension (history-safe)
ALTER TABLE swim_data_whse.productops_gold.dim_brand
  ADD CONSTRAINT pk_dim_brand PRIMARY KEY (brand_id, effective_start_date) NORELY;

ALTER TABLE swim_data_whse.productops_gold.dim_person
  ADD CONSTRAINT pk_dim_person PRIMARY KEY (person_id, effective_start_date) NORELY;

ALTER TABLE swim_data_whse.productops_gold.dim_customer
  ADD CONSTRAINT pk_dim_customer PRIMARY KEY (customer_id, effective_start_date) NORELY;

-- Bridges reference the dimensions
ALTER TABLE swim_data_whse.productops_gold.bridge_brand_person
  ADD CONSTRAINT fk_bbp_brand  FOREIGN KEY (brand_id)  REFERENCES swim_data_whse.productops_gold.dim_brand (brand_id, effective_start_date) NORELY,
  ADD CONSTRAINT fk_bbp_person FOREIGN KEY (person_id) REFERENCES swim_data_whse.productops_gold.dim_person (person_id, effective_start_date) NORELY;
```

If the composite-key form fights your tooling, the pragmatic alternative is PK on `brand_id` declared `NORELY` with a table comment stating "unique only where is_current = true." Either way, never declare `RELY` on these keys: `RELY` licenses the optimizer to drop joins and deduplication on the assumption of uniqueness, and on an SCD2 table that assumption is false, which is exactly the double-counting failure you flagged.

**As built (2026-09-03):** the composite form was rejected as an FK parent (single-column FKs cannot reference a two-column PK), so production uses the fallback: single-column NORELY PKs on brand_id, person_id, and customer_id with the SCD2 uniqueness comment on each table, plus the six single-column FKs. Also found during implementation: Gold `dim_brand` carries no `placeholder_flag` column (it stayed in Silver), so the `pct_with_placeholders` measure in 3.2 needs that column promoted or the measure dropped.

### 1.2 Comment every agent-facing view and column

Comments on the `gold_v_*` views are what Genie, the SQL MCP server, and any schema-introspecting agent actually read. Write them as definitions with disambiguation, not descriptions. Three rules that survive contact with LLMs:

- State the grain in the view comment, first sentence.
- For every column an agent might filter on, state the value domain.
- Say explicitly what NOT to use the object for, and what to use instead. Negative guidance is the cheapest hallucination prevention there is.

```sql
COMMENT ON VIEW swim_data_whse.productops_gold.gold_v_dim_brand_active IS
'Grain: one row per active brand (is_current = true AND is_active = true). Row-level security is enforced per querying user via fn_brand_access_filter; different users see different row counts by design. Use this view for questions about ACTIVE brands only. For questions that include dropped or archived brands, use gold_v_dim_brand_all. Do not aggregate staffing names from this view; use gold_v_bridge_brand_person_active joined to gold_v_dim_person_active.';

ALTER VIEW swim_data_whse.productops_gold.gold_v_dim_brand_active
  ALTER COLUMN brand_id COMMENT 'Persistent surrogate key (brand001, brand002, ...). Immutable across renames. Join key to all bridges and xref tables.';
ALTER VIEW swim_data_whse.productops_gold.gold_v_dim_brand_active
  ALTER COLUMN brand_status COMMENT 'Operational lifecycle status. Domain: Active, DROPPED (and legacy variants). is_active is the certified boolean; prefer filtering on is_active rather than string-matching this column.';
ALTER VIEW swim_data_whse.productops_gold.gold_v_dim_brand_active
  ALTER COLUMN division COMMENT 'Business division code. Domain: BF, MS, SS, PB and others (11 distinct). See swim_data_whse.productops_semantic.ref_division for business names.';   -- built in Phase 7 from the Qlik vocabulary (D6)
ALTER VIEW swim_data_whse.productops_gold.gold_v_dim_brand_active
  ALTER COLUMN control_flag COMMENT 'Control group membership flag (true/false). Business meaning: brand is in the control group for measurement. Not a security or data-quality flag.';
ALTER VIEW swim_data_whse.productops_gold.gold_v_dim_brand_active
  ALTER COLUMN placeholder_flag COMMENT 'True when any source attribute was a placeholder token (TBD, TBC, N/A, NULL-like) in Airtable. Use to qualify data-completeness answers; do not exclude rows on it unless asked.';
ALTER VIEW swim_data_whse.productops_gold.gold_v_dim_brand_active
  ALTER COLUMN app_override_flag COMMENT 'True when the current value of at least one field originated from an approved App 2 edit request rather than the Airtable source. Lineage marker, not a quality flag.';
```

Repeat for `gold_v_bridge_brand_person_active` (grain: one row per brand-person-role assignment; warn: a person appears once per brand per role, so COUNT(*) here counts assignments, not people), `gold_v_bridge_brand_customer_active`, `gold_v_alloc_by_delivery_active` (grain: brand by allocation_type by facility), `gold_v_brand_name_active`, and `gold_brand_road_map_summary` (grain: one row per active brand, 26 denormalized columns; warn: staffing and customer columns are comma-joined display strings built with COLLECT_SET/ARRAY_JOIN; never split or count them; use the bridges for counting).

That last warning matters more than any other single comment: the summary view's `us_sales`, `customers`, and `brand_codes` columns are exactly the kind of concatenated string an LLM will happily `split()` and miscount.

### 1.3 Tag the certified surface

Tags make certification queryable and give agents (and humans in Catalog Explorer) a machine-readable trust signal.

```sql
ALTER VIEW  swim_data_whse.productops_gold.gold_v_dim_brand_active        SET TAGS ('certified' = 'true', 'domain' = 'brm', 'security' = 'rls-view', 'consumer' = 'agents,bi');
ALTER VIEW  swim_data_whse.productops_gold.gold_brand_road_map_summary   SET TAGS ('certified' = 'true', 'domain' = 'brm', 'security' = 'rls-view', 'consumer' = 'app1,bi');
ALTER TABLE swim_data_whse.productops_gold.dim_brand                     SET TAGS ('certified' = 'false', 'access' = 'pipeline-only', 'note' = 'unfiltered; do not grant to consumers');
```

Adopt the rule now: **an object without `certified = 'true'` never enters a Genie space, an MCP grant, or a Power BI certified dataset.**

---

## Phase 2: Extend the identity chain to agents

**Goal:** every agent query resolves through the same `CURRENT_USER()` to `user_person_map` to `fn_brand_access_filter` chain your humans use, with no parallel security system.

The elegant property of your existing design is that `fn_brand_access_filter` evaluates `CURRENT_USER()` at query time, and `user_person_map` already registers both human emails and service principal client IDs (the App SPs are in there today). So the identity chain extends to agents by mapping the right identities, not by building anything new.

### 2.1 The three agent identity patterns

| Pattern | CURRENT_USER() resolves to | user_person_map entry | When to use |
|---|---|---|---|
| On-behalf-of (OBO) user | The human's SSO email | Already exists for mapped staff | Genie (always works this way for data access) and Claude Cowork interactive sessions |
| Scoped agent service principal | The SP application/client ID | New row: `role = 'user'`, synthetic person_id (D7), explicit `bridge_brand_person` rows | Unattended/scheduled agent jobs with a bounded brand scope |
| Org-wide analytics agent SP | The SP client ID | New row: `role = 'admin'`, person_id NULL | Only if leadership signs off that anyone who can invoke this agent may see all brands |

The third row exists because it is sometimes legitimate (an executive briefing agent whose consumers are all admins anyway), but the default answer to "should the agent SP be admin?" is no. Whoever can prompt an admin agent effectively holds admin read access, laundered through natural language.

### 2.2 Register a scoped agent identity (as built, 2026-09-04)

The original plan (synthetic person + bridge_brand_person rows) was replaced during implementation: the bridge is pipeline-managed (staffing splits are full_replace; the Silver and Gold bridges are scd2_merge with deletion detection), so directly inserted agent rows would be closed on the next run. Agent scope instead lives in a dedicated, manually governed table that the pipeline never touches, checked by a new third path in the security function:

```sql
-- 1. agent_brand_scope: the pipeline-independent scope registry
CREATE TABLE swim_data_whse.productops_gold.agent_brand_scope (
  principal_id STRING NOT NULL,   -- SP application ID, as CURRENT_USER() resolves it
  brand_id     STRING NOT NULL,
  granted_by   STRING NOT NULL,
  granted_at   TIMESTAMP NOT NULL,
  is_active    BOOLEAN NOT NULL,  -- never delete; deactivate to revoke
  note         STRING
);
-- Mirror SELECT grants from user_person_map (invoker-evaluated RLS reads it):
-- swimusa_admin, swimusa_brand_editor, swimusa_brand_readonly,
-- swimusa_product_ops_editor, swimusa_product_ops_readonly, swimusa_agents

-- 2. Map the service principal. LIVE user_person_map HAS 11 COLUMNS
--    (timezone was added post-handover); always use explicit column lists.
INSERT INTO swim_data_whse.productops_gold.user_person_map
  (user_email, person_id, role, assigned_at, is_active,
   persona_tier, module_scope, databricks_group, can_edit, can_approve, timezone)
VALUES ('<agent-sp-application-id>', NULL, 'user', current_timestamp(), true,
        'Agent - Scoped Analyst', 'BRM', 'swimusa_agents', false, false, 'Etc/UTC');
-- person_id is NULL by design: agent scope lives in agent_brand_scope, not the bridge.

-- 3. fn_brand_access_filter v1.1.0 adds an additive third path
--    (paths 1 and 2 unchanged; full definition in brm_21_agent_identity.sql):
--    OR EXISTS (SELECT 1 FROM swim_data_whse.productops_gold.agent_brand_scope s
--               WHERE s.principal_id = CURRENT_USER()
--                 AND s.is_active = TRUE AND s.brand_id = fn_brand_access_filter.brand_id)

-- 4. Grant brands to the agent by inserting agent_brand_scope rows
--    (granted_by, granted_at, note required; same runbook as user_person_map).
```

Revocation follows the document's audit preservation rule verbatim: never delete, set `is_active = false`.

### 2.3 Grants for agent principals

Grant only the semantic schema (Phase 3) and the specific secured views, mirroring App 1's checklist but narrowed. The function and mapping-table grants are required because the RLS function executes in the invoker's context against them:

```sql
-- Group all agent principals and mapped humans who use agents
GRANT USE CATALOG ON CATALOG swim_data_whse TO `swimusa_agents`;
GRANT USE SCHEMA  ON SCHEMA  swim_data_whse.productops_gold      TO `swimusa_agents`;
GRANT USE SCHEMA  ON SCHEMA  swim_data_whse.productops_semantic  TO `swimusa_agents`;

-- The secured views only. NO grants on dim_brand, bridge_brand_person, or any Gold table.
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_dim_brand_active           TO `swimusa_agents`;
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_dim_brand_all              TO `swimusa_agents`;
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_brand_name_active          TO `swimusa_agents`;
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_dim_person_active          TO `swimusa_agents`;
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_bridge_brand_person_active TO `swimusa_agents`;
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_bridge_brand_customer_active TO `swimusa_agents`;
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_alloc_by_delivery_active   TO `swimusa_agents`;
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_brand_road_map_summary       TO `swimusa_agents`;

-- Required by fn_brand_access_filter evaluation (same as App 1's checklist)
GRANT SELECT  ON TABLE    swim_data_whse.productops_gold.user_person_map     TO `swimusa_agents`;
GRANT SELECT  ON TABLE    swim_data_whse.productops_gold.bridge_brand_person TO `swimusa_agents`;
GRANT EXECUTE ON FUNCTION swim_data_whse.productops_gold.fn_brand_access_filter TO `swimusa_agents`;
```

One honest caveat to record in your security notes: granting SELECT on `bridge_brand_person` (the unfiltered table) is what the current architecture requires for the RLS function to evaluate, and it means a sufficiently determined agent could query staffing assignments directly from that table without brand filtering. App 1 carries the same exposure today. The clean fix is the D2 migration (native row filters, with the function marked as a definer-rights security function so invokers no longer need table grants). Until then, this is a known, inherited, bounded exposure: assignments, not brand attributes.

Explicitly do NOT grant: anything in `productops_bronze`, `productops_silver` (agents never see pre-certification data, and Silver is where unapproved App 2 overlays get applied first), or `productops_audit` except the one governed view built in Phase 4.4.

### 2.4 Agents and App 2: read-only by policy

Decide it now and write it down: **agents do not write edit requests.** The `brm_edit_requests` workflow exists to capture human intent with human justification (`comments`, `submitted_by` from a verified header). An agent drafting an edit for a human to submit in App 2 is fine; an agent inserting into `brm_edit_requests` is not, because `submitted_by` would attribute machine output to a person and the risk-tier matrix assumes a human on the other end. That is why the mapping row in 2.2 sets `can_edit = false`. If you later want agent-initiated edits, that is a new risk tier in `brm_approver_group_matrix` (something like `submitted_via = 'agent'` requiring human approval at ALL risk levels), not a reuse of the current auto-approval lanes.

---

## Phase 3: The metric layer (Unity Catalog metric views)

**Goal:** one certified place where every measure is defined once, in YAML, with LLM-facing metadata, sourced exclusively from the RLS-secured views.

Metric views are the right construct here (rather than more SQL views) for three reasons: measures are defined with their aggregation so consumers cannot re-aggregate wrongly; YAML 1.1 carries `display_name`, `synonyms`, and `comment` per field, which Genie consumes directly; and the definition is a governable text artifact you can version in Git (Phase 8).

> **AS BUILT (2026-09-21).** All four metric views are deployed, tagged `certified=true` / `domain=brm` / `semver=1.0.0`, and granted to `swimusa_agents` (scripts `brm_31`, `brm_32`, `brm_33`; every step information_schema-verified). The YAML below reflects the deployed definitions. Facts learned during the build:
>
> - **Editor rule:** the SQL editor splits statements on every semicolon, including inside `$$` dollar-quoted YAML. No semicolons may appear anywhere in a metric view's YAML prose.
> - **`pct_with_placeholders` is dropped from v1** (decision 2026-09-21): the BRM MVP did not promote `placeholder_flag` into `gold_v_dim_brand_all`. It returns as an additive v1.x measure if the column ever lands.
> - **The person activity rule changed with the BRM MVP** (confirmed intentional): `gold_v_dim_person_active.is_active` is now roster-based via `is_independently_active`, tracking all possible Product Managers. 65 of 226 active people hold no current assignment, by design. Active People (226, person grain) and Active Brand-Assigned People (161, bridge grain) are now intentionally different populations; both column comments were repatched.
> - **2026-09-21 admin baselines:** brands 144 all / 57 active / 87 dropped, division count 13, assignments 1204 (256 Lead + 948 Contributor), people 226 roster / 161 assigned, customer links 56 across 18 distinct retail accounts (National 18 brands, Target 6). CAVEAT: brand numbers include App 2 UAT pollution (4 active brands carry test names/divisions; real active division count is 9). Re-baseline after the SWIM-1050 reverts land.
> - **brand073 Miraclesuit Beauty** is the only active brand absent from both the staffing and customer bridges (lifecycle question open with Koantek).
> - **Migration scaffolding stays out of v1 dimensions:** the MVP's new assignment lifecycle columns (assignment_status, assignment_source, designation, end_reason, assignment dates) are single-valued or empty today, as are the person profile columns (email, job_title, office_location). They join the metric views in a v1.x release when they carry real data.

### 3.1 The layout: four metric views, not one

One giant metric view invites join ambiguity, and your multi-value attributes (staffing, customers, ERP codes) live at different grains. Build four, each with a single unambiguous grain:

| Metric view | Grain | Source | Answers |
|---|---|---|---|
| `mv_brm_brand` | One row per current brand | `gold_v_dim_brand_all` | Brand counts, status mix, division/category/classification breakdowns, data completeness, override lineage |
| `mv_brm_staffing` | One row per brand-person-role assignment | `gold_v_bridge_brand_person_active` (v1 ships without joins; person/brand name joins are a v1.x addition) | People per brand, brands per person, role coverage, staffing gaps |
| `mv_brm_people` | One row per active person | `gold_v_dim_person_active` | The signed D1 "Active People" company-wide count |
| `mv_brm_customers` | One row per brand-customer link | `gold_v_bridge_brand_customer_active` | Customer account coverage, brands per retailer |

Note that `mv_brm_brand` sources `gold_v_dim_brand_all` (current rows, including DROPPED) rather than the `_active` view, and exposes `is_active` as a dimension. That single choice lets both "Active Brands" and "All Brands" be measures of the same view, which keeps the two App 1 headline numbers from ever being computed against different populations. `mv_brm_people` exists because the signed D1 definitions distinguish **Active People** (company-wide, person grain) from **Active Brand-Assigned People** (bridge grain); putting each on the view whose grain matches it is what keeps agents from conflating them.

### 3.2 `mv_brm_brand`: the core metric view (as built, 2026-09-21)

Deployed exactly as in `brm_31_mv_brm_brand.sql`, which is the canonical artifact for Git in task 3.3. Differences from the original draft of this section: the YAML uses `dimensions:` and `measures:` keys (the runtime rejects `fields:`), `placeholder_flag` and `pct_with_placeholders` are out (source column not promoted), `pct_app_overridden` is computed as a distinct-brand ratio rather than AVG so it stays correct if the source ever exposes duplicate rows, and no `format:` blocks (kept minimal for v1). Shape summary of the deployed view:

```sql
CREATE VIEW swim_data_whse.productops_semantic.mv_brm_brand
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
source: swim_data_whse.productops_gold.gold_v_dim_brand_all
-- 12 dimensions: brand_id, brand_name, brand_status, is_active,
--   brand_classification, brand_category, division, control_flag,
--   artwork, lab_fit_fabric, app_override_flag, last_modified_source
--   (each with display_name, synonyms where useful, and a comment)
-- 5 measures (signed D1 names):
--   all_brands              COUNT(DISTINCT brand_id)
--   active_brands           COUNT(DISTINCT CASE WHEN is_active THEN brand_id END)
--   dropped_brands          COUNT(DISTINCT CASE WHEN NOT is_active THEN brand_id END)
--   active_division_count   COUNT(DISTINCT CASE WHEN is_active THEN division END)
--   pct_app_overridden      COUNT(DISTINCT CASE WHEN app_override_flag THEN brand_id END)
--                             / COUNT(DISTINCT brand_id)
$$;
```

Verified 2026-09-21: faithfulness cross-check against the source view (144/57 identical), tags and agent grant via information_schema, and the RLS inheritance test (V6): a brand-limited user's `MEASURE(all_brands)` equals their own visible brand count, not 144. That test is the load-bearing proof that metric views inherit invoker-context RLS from their source views.

### 3.3 `mv_brm_staffing`, `mv_brm_people`, `mv_brm_customers` (as built, 2026-09-21)

The staffing bridge is where SCD2 double-counting would happen in a naive build; the secured view already pins `is_current = true AND is_active = true`, and the metric view adds the second guard by defining every people-measure as COUNT(DISTINCT ...). Deployed exactly as in `brm_32_mv_staffing_people.sql` and `brm_33_mv_brm_customers.sql` (the canonical artifacts for Git in 3.3).

**`mv_brm_staffing`** (assignment grain, source `gold_v_bridge_brand_person_active`). v1 ships WITHOUT the person/brand joins from the original draft: keeping v1 join-free removes join-cardinality risk while the MVP settles, and person_name/brand_name dimensions arrive in a v1.x release. Dimensions: brand_id, person_id, role_type (verified domain: Asia_Merch, Design, PM, RM_Fabric, RM_Sourcing, RM_Trims, Sales, TD), role_level (Lead, Contributor; the draft's "Member" was wrong). Measures: `total_assignments` COUNT(DISTINCT assignment_id) (verified unique per row), `active_brand_assigned_people` COUNT(DISTINCT person_id), `brands_staffed`, `lead_assignments`, `contributor_assignments`. Every assignment measure's comment states it is not a people count. Baselines: 1204 assignments (256 Lead + 948 Contributor), 161 people, 56 brands.

**`mv_brm_people`** (person grain, source `gold_v_dim_person_active`). One signed measure, `active_people`: COUNT(DISTINCT person_id) with two defensive exclusions baked into the expression, the reserved synthetic agent range (person900 and up) and any record carrying `merged_into_person_id`. Baseline 226 under the roster-based rule (see the Phase 3 as-built banner). Dimensions: person_id, person_name only; the empty profile columns wait for v1.x.

**`mv_brm_customers`** (brand-customer link grain, source `gold_v_bridge_brand_customer_active`). Dimensions: brand_id, customer_id, customer_name (documented as wholesale retail ACCOUNTS such as Academy, Target, Amazon, never consumers). Measures: `brand_customer_links` COUNT(1), `brands_with_customers`, `distinct_customers`, built to stay correct when today's exact 1:1 (56 links, 56 brands) becomes many-to-many. First reading: 18 distinct accounts, National carrying 18 brands, Target 6, PVH and Academy 4 each.

`mv_brm_allocations` over `gold_v_alloc_by_delivery_active` remains an optional fifth view if allocation questions matter to Product Ops (grain: brand by allocation_type by facility; allocation_type domain lab_dev_fabric, lab_bulk_fabric, color_dev_prints_so, color_bulk_prints_solids).

### 3.4 Two rules that keep the metric layer honest

**Never materialize an RLS-dependent metric view.** Metric view materialization snapshots results under the refresh principal's identity; a materialized `mv_brm_brand` would freeze one user's row visibility and serve it to everyone. Your row counts are small (hundreds), so materialization buys nothing anyway. Leave `materialization` out of every YAML in this layer, and make that a review-blocking rule in Phase 8.

**Metric views source views, never tables.** Enforced by grants (the semantic deployment principal simply has no SELECT on Gold tables) and by PR review. This is the load-bearing consequence of finding 1.

### 3.5 Grants and tags (as built, 2026-09-21)

All four views: `GRANT SELECT ... TO swimusa_agents` applied and information_schema-verified, and tagged `certified=true`, `domain=brm`, `semver=1.0.0`. Humans who query ad hoc reach the same objects via their existing groups. Known inherited exposure: the semantic schema carries the catalog-wide grants under review on task 2.4 (account users SELECT, External-Data-Partners and bardess-shared with MANAGE, two unidentified SPs with ALL PRIVILEGES); until 2.4 remediation, certification integrity rests on convention rather than enforcement, since MANAGE holders can alter or re-tag certified views.

Querying a metric view requires the `MEASURE()` aggregate, which is also a consistency feature: `SELECT division, MEASURE(active_brands) FROM mv_brm_brand GROUP BY division` cannot be re-aggregated wrongly, because the measure carries its own definition.

---

## Phase 4: Genie space (the Databricks-native agent path)

**Goal:** a governed natural-language surface inside the workspace where identity, RLS, and metric definitions all flow through automatically.

### 4.1 Why Genie is the primary path, for both agent populations

Genie evaluates data access as the asking user's own Unity Catalog identity: row filters and view-embedded `CURRENT_USER()` logic both resolve to the human, regardless of how the space is shared, and a user without access gets an empty response. That means your entire `user_person_map` chain works in Genie with zero additional engineering: dchristy@swimusa.com sees all brands, dzou@swimusa.com sees ~20, mhorvath@swimusa.com sees none, exactly like the document's Scenarios A, B, and C, but through natural language.

This is also why (Phase 5) the recommended external path routes Claude through the Genie MCP endpoint rather than raw SQL: both agent populations then share one set of instructions, one asset list, and one text-to-SQL behavior, which directly answers your "same metric computed differently by different agents" requirement.

### 4.2 Build the space

In the workspace UI (Genie, Create Space), configure:

- **Assets, in this order of preference:** the four metric views from Phase 3; `gold_brand_road_map_summary`; `gold_v_dim_brand_all`. Nothing else at launch. Every asset carries the Phase 1 comments, which Genie reads. Do not add Gold tables, Silver anything, or the mapping tables.
- **Warehouse:** the existing Serverless SQL Warehouse. Genie uses the author's embedded credential for compute but the asker's identity for data, so end users need no warehouse grant.
- **Space instructions** (Genie's system-prompt equivalent). Draft:

> You answer questions about Swim USA's Brand Road Map (BRM): brands, their status, divisions, classifications, staffing assignments, customer accounts, ERP codes, and facility allocations.
> Definitions are signed and certified: "Active Brands" means the active_brands measure in mv_brm_brand. "All Brands" (also called total brands) includes dropped brands. Company-wide people counts use active_people in mv_brm_people; people on specific brands use active_brand_assigned_people in mv_brm_staffing. Never present assignment counts as people counts.
> Prefer metric views (mv_brm_brand, mv_brm_staffing, mv_brm_people, mv_brm_customers) with MEASURE() for any aggregate. Use gold_brand_road_map_summary only to display a brand's full profile, and never split or count its comma-separated columns.
> Row-level security applies: different users legitimately see different counts. If a query returns no rows, say the user may not have access to those brands and suggest contacting the administrator; do not speculate that the data does not exist.
> This space answers about the CURRENT road map only. If asked about past states, state plainly that historical data is unavailable and will remain so until a governed historical view is published.
> This data reflects the certified state as of the last pipeline run. Approved edits from the Brand Road Map Edit app may not appear until the next run. Pending (unapproved) edit values never appear here; pending-change information comes only from gold_v_brm_pending_edits, never from any underlying request table.
> Data changes through a governed approval workflow; you cannot change data. Direct users to the Brand Road Map Edit app to request changes.

- **Benchmarks:** seed with the golden questions from Phase 6 so Genie's built-in evaluation tracks accuracy over time.
- **Example SQL:** add the certified query for each headline number, for example:

```sql
-- Certified: Active Brands
SELECT MEASURE(active_brands) AS active_brands
FROM swim_data_whse.productops_semantic.mv_brm_brand;

-- Certified: staffing coverage by division
SELECT division, MEASURE(active_brand_assigned_people) AS people, MEASURE(distinct_brands_staffed) AS brands
FROM swim_data_whse.productops_semantic.mv_brm_staffing
GROUP BY division;
```

### 4.3 Share it

Share the space with the existing Databricks groups referenced by `user_person_map.databricks_group` (`swimusa_brand_editor` and peers). Sharing the space grants conversation access only; data access is still resolved per user, so over-sharing the space cannot leak rows. Under-mapping in `user_person_map` shows up as empty answers, which the space instructions above turn into a helpful message instead of a hallucination.

### 4.4 Governance awareness view (Decision D4)

If D4 lands on "yes, agents may disclose governance state," build the one exception to the "no audit schema" rule, an RLS-scoped, deliberately narrow view, and add it to the Genie space with sharp instructions:

```sql
CREATE OR REPLACE VIEW swim_data_whse.productops_semantic.gold_v_brm_pending_edits AS
SELECT
  r.record_id            AS brand_id,
  b.brand_name,
  r.field_name,
  r.risk_level,
  r.status,
  r.submitted_at,
  r.approved_at
  -- deliberately excluded: old_value, new_value, payload_json, submitted_by, comments.
  -- Agents may disclose THAT a field is mid-change, not the proposed value
  -- (an unapproved value stated by an agent becomes a fact in someone's deck)
  -- and not who requested it (submitter identity is workflow-internal).
FROM swim_data_whse.productops_audit.brm_edit_requests r
JOIN swim_data_whse.productops_gold.gold_v_dim_brand_all b
  ON r.record_id = b.brand_id            -- join through the secured view = RLS applies
WHERE r.status IN ('Pending Approval', 'Approved')   -- Approved-not-yet-Applied is also "in flight"
COMMENT ...
```

Set the view comment to: 'Grain: one pending or approved-but-not-yet-applied field-level edit request per row, for brands the querying user can access. Use ONLY to disclose that a field is awaiting or undergoing change. The proposed new values are intentionally not available here and must never be presented as current data.'

Genie instruction to add: "When asked about a brand's name or status, if gold_v_brm_pending_edits shows an in-flight edit on that field, mention that a change is pending approval, without stating the proposed value."

This gives you the exact behavior you asked for: agents never present unapproved edits as certified fact, but they also never confidently assert a value that Product Ops knows is mid-rename.

---

## Phase 5: External path (Claude Cowork via managed MCP)

**Goal:** Claude Cowork agents query the same certified layer, under a governed identity, with Unity Catalog enforcing everything server-side.

### 5.1 Endpoint choice: Genie MCP first, SQL MCP as the controlled escape hatch

Databricks exposes managed MCP servers (Public Preview) at stable workspace URLs. Two matter here:

| Endpoint | URL | What Claude gets | OAuth scope |
|---|---|---|---|
| Genie space | `https://<workspace-host>/api/2.0/mcp/genie/{space_id}` | Ask-a-question tool bound to YOUR space: its assets, instructions, and certified examples | `genie` |
| Databricks SQL | `https://<workspace-host>/api/2.0/mcp/sql` | Direct SQL execution under the caller's UC identity | `sql` |

Recommendation: connect Claude Cowork to the **Genie space MCP endpoint** as the default tool. Every consistency mechanism you built in Phase 4 (definitions, instructions, example SQL, benchmarks) then applies identically to Claude and to native Genie users, because they are literally the same space. The SQL MCP endpoint is the power-user path: enable it for your own and your engineer's identities during validation, and decide later whether analysts get it. Its risk is not security (UC still applies per identity) but consistency: freehand SQL is where a second definition of "active brands" gets invented. Also register a small set of Unity Catalog functions for high-frequency parameterized lookups if you find Claude repeating a pattern, for example:

```sql
CREATE OR REPLACE FUNCTION swim_data_whse.productops_semantic.get_brand_profile(p_brand_name STRING)
RETURNS TABLE
COMMENT 'Returns the certified 26-column road map profile for one brand by name (RLS applies). Use when a user asks for everything about a specific brand.'
RETURN SELECT * FROM swim_data_whse.productops_gold.gold_brand_road_map_summary
WHERE lower(brand_name) = lower(p_brand_name);
```

exposed at `https://<workspace-host>/api/2.0/mcp/functions/swim_data_whse/productops_semantic/get_brand_profile`.

### 5.2 Authentication: how each mode maps to your identity chain

**Interactive Claude Cowork sessions (recommended default): OAuth user-to-machine (U2M), on-behalf-of.** Add the Databricks MCP endpoint as a Claude connector/MCP server with OAuth. The person authenticates once against the workspace (SSO), Claude holds a user-scoped token with the `genie` (and optionally `sql`) scope, and every query executes with `CURRENT_USER()` = that person's email. Your entire chain, `user_person_map` role, `bridge_brand_person` assignments, `fn_brand_access_filter` default-deny, applies untouched. You (dchristy@swimusa.com, admin) see all brands through Claude; dzou sees ~20; an unmapped user sees empty results. No new security surface exists.

**Unattended/scheduled agent jobs: service principal M2M with the scoped identity from Phase 2.2.** The agent authenticates with SP OAuth client credentials; `CURRENT_USER()` resolves to the SP application ID, which `user_person_map` maps to `role = 'user'` with person900's brand assignments. Scope the token to only the endpoints the job needs.

**What not to do, explicitly:** a single workspace PAT or admin SP baked into a shared Claude configuration. That is the App 1 pattern without App 1's trusted filtering layer, and it collapses every user's access to the credential's access, in both directions (over-grants viewers, and its audit trail attributes everyone's questions to one principal).

### 5.3 Where the two consumption paths genuinely diverge

| Concern | Databricks-native (Genie / Mosaic AI) | External (Claude Cowork via MCP) |
|---|---|---|
| Identity | Automatic: workspace session IS the identity | Explicit: OAuth U2M per user, or SP M2M per agent; must be provisioned and mapped |
| RLS via fn_brand_access_filter | Inherited with zero configuration | Inherited IF the token identity is mapped in user_person_map; unmapped = silent empty results |
| Definition consistency | Space instructions + metric views | Same space via Genie MCP; diverges only if you enable raw SQL MCP |
| Best suited for | Ad hoc business Q&A, dashboard-adjacent exploration, users already in the workspace | Cross-system work (BRM data joined with email/docs/Airtable context in one conversation), scheduled digests, drafting artifacts from BRM data |
| Failure mode to watch | Users trusting a wrong text-to-SQL guess (mitigated by benchmarks) | Token/identity misconfiguration read as "no data"; agent blending BRM facts with outside context without labeling the boundary |
| Audit | Genie space history + query history per user | Query history per token identity + Claude-side conversation logs |

Practical steering rule for your team: pure "what does the road map say" questions belong to Genie; anything that combines road map data with the world outside the lakehouse belongs to Claude Cowork, calling the same Genie space through MCP.

---

## Phase 6: Validation before trust

**Goal:** evidence, per consumption path and per identity tier, that agents return certified answers, before anyone outside the data team touches them.

### 6.1 Golden query set

Author 25 to 50 questions in three bands, each with certified SQL against the metric views and the expected result captured at a point in time. Band 1, headline numbers (Active Brands, All Brands, Active Division Count; expected to match App 1's cards exactly). Band 2, sliced aggregates (active brands by division; brand-assigned people on Target-linked brands; Active People company-wide vs Active Brand-Assigned People, which must be answered from different metric views; brands with placeholder data by classification). Band 3, traps, which is where agent trust is actually won:

- "How many people work on brand X?" (must use `active_brand_assigned_people`, not assignment rows; a wrong answer here reveals bridge-grain confusion)
- "List the sales reps for Body By Miraclesuit" (must come from the staffing bridge, not by splitting `us_sales` in the summary view)
- "How many brands did we have last year?" (must state plainly that historical data is unavailable, per the approved D5 wording, not invent history from SCD2 columns it cannot see)
- "What's the status of Amazon Aqua Green Kids?" (if a rename is pending in `brm_edit_requests`, the answer must state current certified value and may disclose that a change is pending, without the proposed value)
- "Show me all brands" asked by a brand-limited identity (must return only assigned brands, without commentary implying that is the full universe... the space instructions handle the phrasing)

### 6.2 Identity matrix, replicated from the document's own scenarios

Run every Band 1 query under each identity, on both paths:

| Identity | Expected | Validates |
|---|---|---|
| dchristy@swimusa.com (admin) | Full counts (all active brands) | Admin bypass path 1 of fn_brand_access_filter |
| dzou@swimusa.com (user, person041) | ~20 assigned brands | Bridge path 2, per-user filtering through both Genie and MCP OBO |
| mhorvath@swimusa.com (no_access) | Empty results plus the graceful "you may not have access" message | Default deny AND the instruction that stops agents from hallucinating an explanation |
| Scoped agent SP (person900) | Exactly its assigned brands | M2M identity chain end to end |
| An unmapped test user | Empty results | Confirms silent-deny is detected and messaged, not misread as missing data |

### 6.3 Acceptance gates and ongoing drift checks

Gate to launch: 100% on Band 1 for every identity on both paths, 90%+ on Band 2, and every Band 3 trap either correct or safely declined (a wrong-but-confident answer on any trap is a launch blocker; a "I can't determine that" is acceptable).

Then make it continuous: store the golden set in the repo (Phase 8), schedule a weekly job that runs the certified SQL, calls the Genie space via its API and the MCP path with a test identity, compares numbers, and writes a pass/fail row to a small `productops_semantic.agent_eval_results` table. Genie's built-in benchmark feature covers the native path's regression tracking; the scheduled job is what catches drift on the external path and after every semantic-layer change. Alert on any Band 1 mismatch: those are your headline numbers, and "Claude says 54, Power BI says 52" is the incident this whole layer exists to prevent.

---

## Phase 7: Power BI and the Qlik translation

**Goal:** the mid-migration reality: Power BI consumes the same certified surface, and Qlik's embedded business logic is translated once, formally, into the semantic layer rather than re-implemented per report.

### 7.1 Power BI connects to the same secured views, under user SSO

Point Power BI (DirectQuery or Import) at the `gold_v_*` views and `gold_brand_road_map_summary`, never Gold tables, using the Databricks connector with **Microsoft Entra ID SSO enabled on the connection**. With SSO, each report viewer's own identity reaches the warehouse, `CURRENT_USER()` resolves to them, and `fn_brand_access_filter` does in Power BI exactly what it does in App 1 and Genie. This spares you re-implementing brand-level security as Power BI RLS roles, which would be a second security system that drifts from `user_person_map` (the failure mode your architecture was explicitly built to avoid).

Two consequences to plan around, and one decision:

- Import-mode caches: an imported dataset is fetched under one identity (the refresh credential). If you must use Import for performance, either the dataset is admin-scope and its workspace audience is restricted to people who are admin-equivalent in `user_person_map`, or you stay in DirectQuery for anything brand-limited. Recommendation: DirectQuery for the BRM model; the data is small (hundreds of rows) and Serverless warehouses make it snappy.
- Metric views and Power BI: Power BI cannot execute `MEASURE()` semantics natively today; its measures are DAX. So the metric-view YAML is the source of truth and the Power BI semantic model is a **certified derivative**: each DAX measure in the BRM dataset must reference the metric view it implements in its description (for example, DAX `Active Brands = CALCULATE(DISTINCTCOUNT(dim[brand_id]), dim[is_active] = TRUE)`, description: "Implements mv_brm_brand.active_brands v1"). Your engineer maintains a one-page mapping doc in the repo; the Phase 6 weekly job adds one more comparison leg (metric view result vs. published dataset result) so PBI drift is caught the same week it happens.
- Decision for the engineer: whether App 1-style admin-scope executive reports warrant a small Import model alongside the DirectQuery model. Fine either way, as long as audience restriction follows the rule above.

### 7.2 The formal Qlik translation

Treat Qlik as a requirements artifact, not a reference implementation. Concretely: inventory every Qlik expression touching BRM entities (set analysis, calculated dimensions, variables, section access rules), and for each one either map it to an existing certified measure, add a measure to the metric-view YAML through the Phase 8 change process, or retire it with a note. The two Qlik-specific items your document points at:

- **Vocabularies (Decision D6, as approved):** the division/classification/category display labels living in Qlik load scripts or master items become **three separate governed tables**: `ref_division`, `ref_classification`, and `ref_category` in `productops_semantic`, each carrying a status column. Dave extracts candidates from Qlik at status Candidate; Product Ops validates each code, business label, vocabulary type, and status; only Published rows are granted to agents or added to the Genie space. Joined nowhere at runtime, but referenced in column comments and available to Genie as lookup assets. This converts tribal Qlik knowledge into cataloged, validated metadata.
- **Section access:** if any Qlik section access rules encode brand- or division-level visibility beyond what `user_person_map` + `bridge_brand_person` express, they must be reconciled into the Unity Catalog chain now, not carried as a parallel rule set in Power BI. One access model, one place.

The output of this subphase is a translation ledger (Qlik object, disposition, certified target, sign-off) checked into the repo. That ledger is also your Qlik decommissioning evidence.

---

## Phase 8: Governance and versioning

**Goal:** the semantic layer changes safely, ownership is explicit, and drift is detected rather than discovered.

### 8.1 Ownership

Three roles, named people, written into the repo README:

- **Metric owner (business):** Product Ops leadership. Owns definitions (what "active" means), signs D1-tier decisions, approves any change to measure logic.
- **Semantic layer steward (technical):** your Databricks/Power BI engineer. Owns the YAML, views, grants, the Genie space configuration, and the eval job. Only identity with write access to `productops_semantic`.
- **Security owner:** whoever owns `user_person_map` today (per the document's user-onboarding runbook). Agent identity registrations (Phase 2.2) go through the same runbook as human onboarding, with the D7 synthetic-person convention.

### 8.2 Change management: code-governed, App 2-informed

Semantic definitions are code, so they are governed as code: metric-view YAML, view DDL, grants, Genie space instructions (exported as text), golden queries, and the Qlik ledger all live in one Git repo, deployed to the workspace through Databricks Asset Bundles (or your existing CI), dev/test/prod if you stand up separate targets, or at minimum PR-gated deploys to prod.

The `brm_edit_requests` workflow governs **data** changes and should stay that way; do not route YAML changes through App 2. But its risk-tier idea translates directly into your PR rubric, which gives Product Ops a review model they already understand:

| Change class | Risk (mirroring the App 2 matrix) | Approval |
|---|---|---|
| Measure logic, filter, grain, source of a metric view; RLS or grant changes | High | Metric owner + steward, plus a full Phase 6 eval run before merge |
| New measure or dimension, new asset added to Genie space | Medium | Steward, metric owner notified, eval run |
| Synonyms, comments, display names, benchmark additions | Low | Steward, auto-merge allowed, logged |

If you want the parity to be literal rather than conceptual, add rows to `brm_approver_group_matrix` with `module_scope = 'SEMANTIC'` purely as a registry of these rules (the matrix table is a fine system of record for risk classifications even when the executor is a Git PR rather than App 2). That keeps one queryable place answering "who approves what" across both data edits and definition edits.

Version markers: put `version: <semver>` in a comment header of each YAML, tag releases in Git, and stamp the Genie space instructions with the release tag so a screenshot of any agent answer can be traced to the definitions in force when it was given.

### 8.3 Knowing when an agent drifts

Drift shows up in three places; instrument all three:

1. **Numeric drift:** the Phase 6 weekly eval job. Any Band 1 mismatch alerts; Band 2/3 degradation over two consecutive runs opens a ticket.
2. **Behavioral drift:** review Genie space history monthly for questions answered with freehand SQL that bypassed the metric views (the generated SQL is visible per answer); each recurring pattern becomes either a new certified example, a new measure, or a new instruction. For the external path, sample Claude conversations that used the MCP tools.
3. **Definition bypass:** a scheduled query against `system.access.audit` / query history for any non-pipeline principal selecting from Gold **tables** (not views) or from Silver. Today that list should be exactly the two App SPs and the pipeline principal; anything else is either a misconfigured grant or someone routing around the certified layer.

And close the loop with the governance data itself: because every approved App 2 edit eventually lands in Gold with `app_override_flag = true` and an `app_override_request_id`, your eval job can verify end-to-end latency (approval timestamp to visibility in `mv_brm_brand`) and alert if the pipeline stalls, which is the moment agents start serving stale certified data and the "pending changes" disclosure from Phase 4.4 becomes the only honest answer.

---

## Sequenced execution checklist

| # | Step | Owner | Depends on |
|---|---|---|---|
| 0 | Verify prerequisites, create `productops_semantic`, settle D1-D7 (DONE 2026-08-28, D1-D7 signed) | You + engineer + Product Ops | - |
| 1 | PK/FK constraints, comments, tags on Gold surface (DONE 2026-09-02; re-applied 2026-09-21 after BRM MVP redeploy wiped view comments and tags) | Engineer | 0 |
| 2 | Agent identity registrations, `swimusa_agents` group, grants (DONE 2026-09-04; fn_brand_access_filter v1.1.0 + agent_brand_scope; 2.3 policy sign-offs and 2.4 security review still open) | Security owner + engineer | 0 |
| 3 | Four metric views deployed (DONE 2026-09-21 by script; Git repo lands in 3.3) | Engineer | 1 |
| 4 | Genie space: assets, instructions, examples, benchmarks; pending-edits view if D4 = yes | Engineer + you | 3 |
| 5 | MCP: Genie endpoint connected to Claude Cowork (OAuth U2M); scoped SP for unattended jobs | You + engineer | 2, 4 |
| 6 | Golden set authored, identity matrix run on both paths, gates passed, weekly eval job scheduled | Engineer + you | 4, 5 |
| 7 | Power BI model on secured views with SSO; Qlik ledger and vocabularies (D6) | Engineer | 1, 3 |
| 8 | Repo, CI, ownership doc, risk rubric, drift monitors live | All three owners | 6 |

Launch to business users happens after step 6's gates pass, with steps 7 and 8 able to run in parallel from step 3 onward.

---

## Appendix: object inventory this guide creates

| Object | Type | Schema |
|---|---|---|
| `productops_semantic` | Schema | swim_data_whse |
| `mv_brm_brand`, `mv_brm_staffing`, `mv_brm_people`, `mv_brm_customers` (+ optional `mv_brm_allocations`) | Metric views | productops_semantic |
| `gold_v_brm_pending_edits` | View (RLS via join to secured view) | productops_semantic |
| `get_brand_profile` | SQL table function (MCP-exposed) | productops_semantic |
| `ref_division`, `ref_classification`, `ref_category` (separate governed vocabularies per D6) | Reference tables | productops_semantic |
| `agent_brand_scope` | Table (manually governed agent RLS scope; read by fn_brand_access_filter v1.1.0 path 3) | productops_gold |
| `agent_eval_results` | Eval results table | productops_semantic |
| `swimusa_agents` | Workspace/account group | - |
| Agent SP mapping rows | Rows in `user_person_map` (person_id NULL; 11-column explicit inserts) | productops_gold |
| BRM Genie space | Genie space | Workspace |
| PK/FK constraints, comments, tags | Metadata on existing Gold objects | productops_gold |

Nothing in the existing pipeline, App 1, or App 2 changes. The semantic layer is purely additive on top of the contract Koantek handed over, which is the property that lets you build it mid-migration without destabilizing what already works.

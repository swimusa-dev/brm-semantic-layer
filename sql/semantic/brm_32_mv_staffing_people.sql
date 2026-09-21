-- =====================================================================
-- Task 3.2 (part 1 of 2): mv_brm_staffing + mv_brm_people metric views
-- BRM Semantic Layer Implementation | 2026-09-21
--
-- Sources: gold_v_bridge_brand_person_active (1204 rows, assignment
-- grain) and gold_v_dim_person_active (226 rows, person grain). RLS is
-- inherited from the source views. NEVER materialize.
--
-- Signed D1 grain rule enforced here: assignment counts are NEVER
-- presented as people counts. Staffing view carries both, named and
-- commented so agents cannot confuse them. Company-wide Active People
-- lives on the PERSON grain view (mv_brm_people).
--
-- v1 scope decisions (per 2026-09-21 discovery): migration scaffolding
-- columns (assignment_status, assignment_source, designation,
-- end_reason, assignment dates) are EXCLUDED from dimensions; all
-- single-valued or empty today. Same for person profile columns
-- (email, job_title, office_location). They join in a v1.x release
-- when they carry real data.
--
-- EDITOR RULE: no semicolons inside $$ YAML blocks.
-- 6 numbered statements + verification + part 2 discovery.
-- =====================================================================

-- [1/6] Staffing metric view (assignment grain)
CREATE OR REPLACE VIEW swim_data_whse.productops_semantic.mv_brm_staffing
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1

source: swim_data_whse.productops_gold.gold_v_bridge_brand_person_active

comment: >
  Certified BRM staffing metrics, v1. Grain of the source is one row per
  CURRENT assignment of a person to an ACTIVE brand (1204 at 2026-09
  baseline, admin view). Row-level security is inherited from the source
  view, so different users see different totals by design. CRITICAL
  grain rule (signed D1): assignment counts are never people counts.
  One person holds many assignments. For company-wide people counts use
  mv_brm_people. Ask measures with MEASURE() and do not aggregate
  dimensions directly.

dimensions:
  - name: brand_id
    expr: brand_id
    display_name: Brand ID
    comment: FK to mv_brm_brand.brand_id and gold_v_dim_brand_active.

  - name: person_id
    expr: person_id
    display_name: Person ID
    comment: FK to gold_v_dim_person_active.person_id and mv_brm_people.

  - name: role_type
    expr: role_type
    display_name: Role Type
    synonyms:
      - function
      - discipline
      - role
    comment: >
      Functional role of the assignment. Domain (verified 2026-09-03) is
      Asia_Merch, Design, PM, RM_Fabric, RM_Sourcing, RM_Trims, Sales,
      TD. TD means Technical Design, PM means Product Management, RM
      means Raw Materials.

  - name: role_level
    expr: role_level
    display_name: Role Level
    synonyms:
      - seniority
      - lead or contributor
    comment: >
      Seniority of the assignment. Domain is Lead, Contributor. Note
      that Asia_Merch, RM_Fabric and RM_Trims occur only as Contributor
      and RM_Sourcing only as Lead.

measures:
  - name: total_assignments
    expr: COUNT(DISTINCT assignment_id)
    display_name: Total Assignments
    synonyms:
      - assignment count
      - staffing assignments
    comment: >
      Count of current assignments to active brands (1204 at 2026-09
      baseline, admin view). This is NOT a people count. One person
      holds many assignments.

  - name: active_brand_assigned_people
    expr: COUNT(DISTINCT person_id)
    display_name: Active Brand-Assigned People
    synonyms:
      - people assigned to brands
      - staffed people
      - distinct people on brands
    comment: >
      Signed D1 definition, bridge grain. Distinct people holding at
      least one current assignment within the rows the asking user can
      see. When sliced by brand or role, a person appears in every
      group they belong to, so groups do not sum to the total. For the
      company-wide Active People number use mv_brm_people.

  - name: brands_staffed
    expr: COUNT(DISTINCT brand_id)
    display_name: Brands Staffed
    synonyms:
      - brands with assignments
    comment: Distinct active brands holding at least one current assignment.

  - name: lead_assignments
    expr: COUNT(DISTINCT CASE WHEN role_level = 'Lead' THEN assignment_id END)
    display_name: Lead Assignments
    comment: Current assignments at Lead level. Assignment count, not a people count.

  - name: contributor_assignments
    expr: COUNT(DISTINCT CASE WHEN role_level = 'Contributor' THEN assignment_id END)
    display_name: Contributor Assignments
    comment: Current assignments at Contributor level. Assignment count, not a people count.
$$;

-- [2/6] People metric view (person grain)
CREATE OR REPLACE VIEW swim_data_whse.productops_semantic.mv_brm_people
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1

source: swim_data_whse.productops_gold.gold_v_dim_person_active

comment: >
  Certified BRM people metrics, v1. Grain of the source is one row per
  ACTIVE person (226 at 2026-09 baseline). This is the PERSON grain and
  the home of the signed Active People measure (D1). Brand-level
  staffing questions belong to mv_brm_staffing. No row-level brand
  security applies at person grain, but source view access rules still
  apply. Ask measures with MEASURE() and do not aggregate dimensions
  directly.

dimensions:
  - name: person_id
    expr: person_id
    display_name: Person ID
    comment: >
      Persistent surrogate key (person001 and up). Synthetic AGENT
      identities (person900 and up) are reserved for automation and
      excluded from people measures.

  - name: person_name
    expr: person_name
    display_name: Person Name
    synonyms:
      - employee name
      - staff member
    comment: Person display name as extracted from staffing fields.

measures:
  - name: active_people
    expr: COUNT(DISTINCT CASE WHEN merged_into_person_id IS NULL AND NOT person_id RLIKE '^person9[0-9][0-9]$' THEN person_id END)
    display_name: Active People
    synonyms:
      - headcount on brands
      - active staff
      - how many people
    comment: >
      Signed D1 definition, person grain. Company-wide distinct active
      people (226 at 2026-09 baseline). Excludes reserved synthetic
      agent identities (person900 and up) and records merged into
      another person. This is the answer to how many active people we
      have. It is not the same as Active Brand-Assigned People in
      mv_brm_staffing, which can differ under row-level security.
$$;

-- [3/6] Tags
ALTER VIEW swim_data_whse.productops_semantic.mv_brm_staffing
  SET TAGS ('certified' = 'true', 'domain' = 'brm', 'semver' = '1.0.0');

-- [4/6]
ALTER VIEW swim_data_whse.productops_semantic.mv_brm_people
  SET TAGS ('certified' = 'true', 'domain' = 'brm', 'semver' = '1.0.0');

-- [5/6] Agent grants
GRANT SELECT ON VIEW swim_data_whse.productops_semantic.mv_brm_staffing TO `swimusa_agents`;

-- [6/6]
GRANT SELECT ON VIEW swim_data_whse.productops_semantic.mv_brm_people TO `swimusa_agents`;

-- ===================== VERIFICATION =====================

-- [V1] Staffing baseline (expect total_assignments=1204 as admin,
--      active_brand_assigned_people <= 226, brands_staffed <= 57)
SELECT
  MEASURE(total_assignments)             AS total_assignments,
  MEASURE(active_brand_assigned_people)  AS active_brand_assigned_people,
  MEASURE(brands_staffed)                AS brands_staffed,
  MEASURE(lead_assignments)              AS lead_assignments,
  MEASURE(contributor_assignments)       AS contributor_assignments
FROM swim_data_whse.productops_semantic.mv_brm_staffing;

-- [V2] Lead + Contributor must equal total
--      (role_level has exactly two domain values)

-- [V3] People baseline (expect 226 as admin)
SELECT MEASURE(active_people) AS active_people
FROM swim_data_whse.productops_semantic.mv_brm_people;

-- [V4] Grain rule demonstration: people by role_type does NOT sum to
--      the distinct people total (expected and correct)
SELECT role_type,
       MEASURE(active_brand_assigned_people) AS people,
       MEASURE(total_assignments)            AS assignments
FROM swim_data_whse.productops_semantic.mv_brm_staffing
GROUP BY role_type ORDER BY assignments DESC;

-- [V5] Tags and grants landed
SELECT table_name, tag_name, tag_value
FROM swim_data_whse.information_schema.table_tags
WHERE schema_name = 'productops_semantic'
  AND table_name IN ('mv_brm_staffing', 'mv_brm_people');

-- [V6]
SELECT table_name, grantee, privilege_type
FROM swim_data_whse.information_schema.table_privileges
WHERE table_schema = 'productops_semantic'
  AND table_name IN ('mv_brm_staffing', 'mv_brm_people')
  AND grantee = 'swimusa_agents';

-- ============ PART 2 DISCOVERY: mv_brm_customers ============
-- The customer bridge schema is not yet on file post-MVP. Run and
-- paste BOTH results, then the mv_brm_customers script comes back.

-- [D1] Shape
DESCRIBE swim_data_whse.productops_gold.gold_v_bridge_brand_customer_active;

-- [D2] Grain and counts
SELECT count(*) AS total_rows,
       count(DISTINCT brand_id) AS distinct_brands
FROM swim_data_whse.productops_gold.gold_v_bridge_brand_customer_active;

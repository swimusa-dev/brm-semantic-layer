-- =====================================================================
-- Task 3.1: mv_brm_brand metric view (v1)
-- BRM Semantic Layer Implementation | 2026-09-21
--
-- Source: gold_v_dim_brand_all (RLS via fn_brand_access_filter is
-- inherited from the view; NEVER materialize this metric view).
-- Measure names are the SIGNED D1 definitions (decision log 2026-08-27):
--   All Brands, Active Brands, Dropped Brands, Active Division Count,
--   Pct App Overridden.
-- pct_with_placeholders is DROPPED from v1 (placeholder_flag not
-- promoted by the BRM MVP; decision confirmed 2026-09-21). Returns as an
-- additive v1.x measure if the column ever lands.
--
-- 4 numbered statements + verification. Run one at a time.
-- EDITOR RULE: no semicolons may appear inside the $$ YAML block. The
-- SQL editor splits statements on every semicolon, even dollar-quoted
-- ones (learned 2026-09-21). Keep YAML prose semicolon-free.
-- =====================================================================

-- [1/4] Create the metric view
CREATE OR REPLACE VIEW swim_data_whse.productops_semantic.mv_brm_brand
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1

source: swim_data_whse.productops_gold.gold_v_dim_brand_all

comment: >
  Certified BRM brand metrics, v1. Grain of the source is one row per
  current brand in any lifecycle state (active and dropped). Row-level
  security is inherited from the source view via fn_brand_access_filter,
  so different users see different totals by design. Measure definitions
  are the signed Product Ops decisions of 2026-08-27 (D1). Ask measures
  with MEASURE() and do not aggregate dimensions directly.

dimensions:
  - name: brand_id
    expr: brand_id
    display_name: Brand ID
    comment: Persistent surrogate key (brand001...). Immutable across renames.

  - name: brand_name
    expr: brand_name
    display_name: Brand Name
    synonyms:
      - brand
      - label
    comment: Current canonical display name. Renames never change brand_id.

  - name: brand_status
    expr: brand_status
    display_name: Brand Status
    synonyms:
      - lifecycle status
    comment: "Raw lifecycle status. Domain: Active, DROPPED. Prefer the is_active flag."

  - name: is_active
    expr: is_active
    display_name: Is Active
    comment: Certified activity flag. The signed definition of an active brand.

  - name: brand_classification
    expr: brand_classification
    display_name: Brand Classification
    synonyms:
      - classification tier
    comment: "Example values: SWIM USA Owned / National Brand, Private Label."

  - name: brand_category
    expr: brand_category
    display_name: Brand Category
    synonyms:
      - design category
    comment: "Design category mapping. Example values: Design - Private Label, Design - Target."

  - name: division
    expr: division
    display_name: Division
    synonyms:
      - business division
      - division code
    comment: Business division code (BF, MS, SS, PB and others). Codes only until ref_division lands (D6).

  - name: control_flag
    expr: control_flag
    display_name: Control Group
    comment: Control group membership for measurement. Not a security or quality flag.

  - name: artwork
    expr: artwork
    display_name: Artwork Group
    comment: "Artwork assignment group. Example values: LACD, NYCD."

  - name: lab_fit_fabric
    expr: lab_fit_fabric
    display_name: Fabric Fit Lab
    comment: "Fabric fit lab assignment. Example value: SWIM USA - PDC Lab."

  - name: app_override_flag
    expr: app_override_flag
    display_name: Has Approved Edit Override
    comment: True when a current value came from an approved BRM Edit app request. Lineage, not quality.

  - name: last_modified_source
    expr: last_modified_source
    display_name: Last Modified Source
    comment: "Lineage marker. Domain: APP2 or BRONZE."

measures:
  - name: all_brands
    expr: COUNT(DISTINCT brand_id)
    display_name: All Brands
    synonyms:
      - total brands
      - brand count including dropped
      - how many brands total
    comment: >
      Signed D1 definition. Distinct current brands in ANY lifecycle
      state, including dropped (144 at 2026-09 baseline, admin view).
      Renamed from Total Brands per D1.

  - name: active_brands
    expr: COUNT(DISTINCT CASE WHEN is_active THEN brand_id END)
    display_name: Active Brands
    synonyms:
      - current brands
      - live brands
      - how many active brands
    comment: >
      Signed D1 definition. Distinct brands with business status Active
      (is_active = true, 58 at 2026-09 baseline, admin view). This is
      the default answer to how many brands do we have.

  - name: dropped_brands
    expr: COUNT(DISTINCT CASE WHEN NOT is_active THEN brand_id END)
    display_name: Dropped Brands
    synonyms:
      - discontinued brands
      - inactive brands
    comment: >
      Signed D1 definition. Distinct current brands whose lifecycle
      status is not Active. all_brands = active_brands + dropped_brands.

  - name: active_division_count
    expr: COUNT(DISTINCT CASE WHEN is_active THEN division END)
    display_name: Active Division Count
    synonyms:
      - number of divisions
      - division count
    comment: >
      Signed D1 definition. Distinct division codes among ACTIVE brands
      only (11 at 2026-09 baseline, admin view).

  - name: pct_app_overridden
    expr: COUNT(DISTINCT CASE WHEN app_override_flag THEN brand_id END) / COUNT(DISTINCT brand_id)
    display_name: Pct App Overridden
    synonyms:
      - share of brands with approved edits
      - override rate
    comment: >
      Signed D1 definition. Share of brands (any lifecycle state) whose
      current record includes at least one approved BRM Edit app
      override. Lineage adoption metric, returns a fraction 0 to 1.
$$;

-- [2/4] Tag it certified
ALTER VIEW swim_data_whse.productops_semantic.mv_brm_brand
  SET TAGS ('certified' = 'true', 'domain' = 'brm', 'semver' = '1.0.0');

-- [3/4] Grant to the agent group (semantic schema USE SCHEMA already
--       granted in task 2.2, statement 3)
GRANT SELECT ON VIEW swim_data_whse.productops_semantic.mv_brm_brand TO `swimusa_agents`;

-- [4/4] Grant to the human BRM groups that hold SELECT on the certified
--       gold views today (adjust to match your 2.2-era inventory):
-- GRANT SELECT ON VIEW swim_data_whse.productops_semantic.mv_brm_brand TO `<group>`;

-- ===================== VERIFICATION =====================

-- [V1] As admin: expect all=144, active=58, dropped=86, divisions=11
SELECT
  MEASURE(all_brands)            AS all_brands,
  MEASURE(active_brands)         AS active_brands,
  MEASURE(dropped_brands)        AS dropped_brands,
  MEASURE(active_division_count) AS active_division_count,
  MEASURE(pct_app_overridden)    AS pct_app_overridden
FROM swim_data_whse.productops_semantic.mv_brm_brand;

-- [V2] Slice check: active brands by division (codes)
SELECT division, MEASURE(active_brands) AS active_brands
FROM swim_data_whse.productops_semantic.mv_brm_brand
GROUP BY division
ORDER BY active_brands DESC;

-- [V3] Identity check: all = active + dropped, per classification
SELECT brand_classification,
       MEASURE(all_brands)     AS all_brands,
       MEASURE(active_brands)  AS active_brands,
       MEASURE(dropped_brands) AS dropped_brands
FROM swim_data_whse.productops_semantic.mv_brm_brand
GROUP BY brand_classification;

-- [V4] Metadata landed
DESCRIBE TABLE EXTENDED swim_data_whse.productops_semantic.mv_brm_brand;

-- [V5] Tag landed
SELECT * FROM swim_data_whse.information_schema.table_tags
WHERE schema_name = 'productops_semantic' AND table_name = 'mv_brm_brand';

-- [V6] RLS inheritance check (MANUAL): have a brand-limited user (dzou or
--      tmooney) run V1; their all_brands must equal their visible brand
--      count in gold_v_dim_brand_all, NOT 144.

-- =====================================================================
-- Task 3.1 (repair): Comment patch after Koantek BRM MVP redeploy
-- BRM Semantic Layer Implementation | 2026-09-21
--
-- PART 1: re-apply the 9 gold_v_dim_brand_active comments that did not
--         land in the re-run (statements 2-10 of brm_12_comments.sql;
--         verified missing via information_schema 2026-09-21).
-- PART 2: pattern-confident comments for new Koantek columns that match
--         established pipeline conventions (SCD2, app_override lineage).
-- PART 3: DISCOVERY QUERIES for the new columns whose domains are
--         unknown. Run these, paste results to Claude, and the final
--         comment statements come back verified (same workflow as 1.2).
--
-- Run one statement at a time or a verified Run All with the cursor at
-- the TOP of the file. Verification query at the bottom.
-- =====================================================================

-- ============ PART 1: gold_v_dim_brand_active re-apply (9) ============

-- [1/23]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.brand_id IS
'Persistent surrogate key (brand001, brand002, ...). Immutable across renames. Join key to all bridge and xref views.';

-- [2/23]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.brand_name IS
'Current canonical display name from the brand name registry. Renames change this value but never brand_id.';

-- [3/23]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.brand_status IS
'Raw operational lifecycle status. Domain: Active, DROPPED. Prefer filtering on is_active (certified boolean) rather than string-matching this column.';

-- [4/23]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.is_active IS
'Certified activity flag (true when brand_status = Active). The signed definition of an active brand. Always true in this view; exposed for schema consistency with gold_v_dim_brand_all.';

-- [5/23]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.brand_classification IS
'Classification tier. Example values: SWIM USA Owned / National Brand, Private Label. Governed vocabulary pending in ref_classification (D6).';

-- [6/23]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.brand_category IS
'Design category mapping. Example values: Design - Private Label, Design - Target. Governed vocabulary pending in ref_category (D6).';

-- [7/23]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.division IS
'Business division code (BF, MS, SS, PB and others; 11 distinct among active brands). Codes only; business names pending in ref_division (D6).';

-- [8/23]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.control_flag IS
'Control group membership (true/false). Business meaning: brand is in the control group for measurement. Not a security or data-quality flag.';

-- [9/23]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.artwork IS
'Artwork assignment group. Example values: LACD, NYCD.';

-- ============ PART 2: pattern-confident new-column comments ============
-- gold_v_bridge_brand_person_active: SCD2 metadata columns Koantek now
-- exposes, matching the convention already documented on dim_brand_active.

-- [10/23]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_bridge_brand_person_active.effective_start_date IS
'SCD2 metadata: when this version of the assignment record became current. Not the business assignment start; see assignment_start_date.';

-- [11/23]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_bridge_brand_person_active.effective_end_date IS
'SCD2 metadata: always NULL in this view (current records only).';

-- [12/23]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_bridge_brand_person_active.is_current IS
'SCD2 flag: always true in this view. Historical versions are not exposed to consumers.';

-- gold_v_dim_person_active: SCD2 + app_override lineage columns matching
-- the dim_brand_active convention.

-- [13/23]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_person_active.effective_start_date IS
'SCD2 metadata: when this version of the person record became current. Not an employment start date.';

-- [14/23]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_person_active.effective_end_date IS
'SCD2 metadata: always NULL in this view (current records only).';

-- [15/23]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_person_active.is_current IS
'SCD2 flag: always true in this view. Historical versions are not exposed to consumers.';

-- [16/23]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_person_active.app_override_flag IS
'True when at least one current field value originated from an APPROVED Brand Road Map Edit app request rather than the Airtable source. Lineage marker, not a quality flag.';

-- [17/23]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_person_active.app_override_at IS
'Timestamp the most recent approved edit override was applied by the pipeline. NULL when no override.';

-- [18/23]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_person_active.last_modified_source IS
'Lineage marker. Domain: APP2 (current value includes an approved edit) or BRONZE (value came from the Airtable source).';

-- ============ PART 3: DISCOVERY, run and paste results ============
-- These new Koantek columns need verified domains before certified
-- comments are written. DO NOT comment them from assumptions.

-- [19/23] Bridge assignment lifecycle domains
SELECT assignment_status, assignment_source, designation, end_reason,
       count(*) AS rows
FROM swim_data_whse.productops_gold.gold_v_bridge_brand_person_active
GROUP BY 1, 2, 3, 4
ORDER BY rows DESC;

-- [20/23] Bridge assignment dates: shape and nullability
SELECT
  count(*)                                        AS total_rows,
  count(assignment_id)                            AS assignment_id_nonnull,
  count(DISTINCT assignment_id)                   AS assignment_id_distinct,
  count(assignment_start_date)                    AS start_date_nonnull,
  count(assignment_end_date)                      AS end_date_nonnull,
  min(assignment_start_date)                      AS earliest_start,
  max(assignment_start_date)                      AS latest_start
FROM swim_data_whse.productops_gold.gold_v_bridge_brand_person_active;

-- [21/23] Person: new profile fields, coverage
SELECT
  count(*)                                        AS total_rows,
  count(email)                                    AS email_nonnull,
  count(job_title)                                AS job_title_nonnull,
  count(office_location)                          AS office_nonnull,
  count(CASE WHEN is_independently_active THEN 1 END) AS independently_active_true,
  count(merged_into_person_id)                    AS merged_nonnull
FROM swim_data_whse.productops_gold.gold_v_dim_person_active;

-- [22/23] Person: office and title domains (small samples)
SELECT office_location, count(*) AS rows
FROM swim_data_whse.productops_gold.gold_v_dim_person_active
GROUP BY 1 ORDER BY rows DESC;

-- ===================== VERIFICATION =====================

-- [23/23] Expect gold_v_dim_brand_active 16/17, bridge 8/18, person 9/15
SELECT table_name,
       count(CASE WHEN comment IS NOT NULL AND comment != '' THEN 1 END) AS commented,
       count(*) AS total_columns
FROM swim_data_whse.information_schema.columns
WHERE table_schema = 'productops_gold'
  AND table_name IN ('gold_v_dim_brand_active',
                     'gold_v_bridge_brand_person_active',
                     'gold_v_dim_person_active')
GROUP BY table_name;

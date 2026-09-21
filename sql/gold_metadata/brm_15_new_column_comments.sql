-- =====================================================================
-- Task 3.1 (repair, final): Verified comments for new Koantek columns
-- BRM Semantic Layer Implementation | 2026-09-21
-- Domains verified via discovery queries (brm_14 part 3, 2026-09-21):
--   bridge: 1204 rows, all Migrated / csv_derived / Unset, end_reason
--   and assignment_end_date fully NULL, assignment_id unique per row,
--   assignment_start_date spans 2026-07-06 to 2026-08-17 (load window).
--   person: 226 rows, email / job_title / office_location /
--   merged_into_person_id fully NULL, is_independently_active all true.
-- 12 statements + verification. Run All from the top is fine.
-- =====================================================================

-- ===== gold_v_bridge_brand_person_active: 7 new columns =====

-- [1/13]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_bridge_brand_person_active.assignment_id IS
'Unique identifier of the assignment record, one per row in this view. Added by the BRM MVP (2026-09). Not a join key to any other certified view.';

-- [2/13]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_bridge_brand_person_active.designation IS
'Assignment designation. Currently Unset for all rows (migration default, verified 2026-09-21); domain will be defined as App 2 edits populate it. Do not filter or group on this column yet.';

-- [3/13]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_bridge_brand_person_active.assignment_status IS
'Lifecycle status of the assignment record. Currently Migrated for all rows (initial CSV migration, verified 2026-09-21); domain will expand as assignments are created and ended through the pipeline and App 2. Not the same as is_active.';

-- [4/13]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_bridge_brand_person_active.assignment_source IS
'Provenance of the assignment record. Currently csv_derived for all rows (initial migration, verified 2026-09-21). Lineage marker, not a quality flag.';

-- [5/13]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_bridge_brand_person_active.end_reason IS
'Why an assignment ended. Always NULL in this view today (active assignments only, and no ended assignments exist post-migration). Do not conclude that assignments never end.';

-- [6/13]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_bridge_brand_person_active.assignment_start_date IS
'When the assignment record was created in the system. For migrated rows this is the 2026-07/2026-08 migration load window, NOT when the person actually began working on the brand. Do not use to answer tenure or staffing-history questions for migrated assignments.';

-- [7/13]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_bridge_brand_person_active.assignment_end_date IS
'When the assignment ended. Always NULL in this view (active assignments only).';

-- ===== gold_v_dim_person_active: 5 new columns =====

-- [8/13]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_person_active.email IS
'Person email address. Not yet populated (all NULL, verified 2026-09-21); planned enrichment. Do not use to contact or identify people yet, and do not join to user_person_map on this column.';

-- [9/13]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_person_active.job_title IS
'Job title. Not yet populated (all NULL, verified 2026-09-21); planned enrichment. Role information lives on the assignment (role_type, role_level in gold_v_bridge_brand_person_active), not here.';

-- [10/13]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_person_active.office_location IS
'Office location. Not yet populated (all NULL, verified 2026-09-21); planned enrichment.';

-- [11/13]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_person_active.is_independently_active IS
'True when the person is active independent of brand assignments. Currently true for all rows (verified 2026-09-21). The certified activity definition for people remains is_active (at least one current assignment to an active brand).';

-- [12/13]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_person_active.merged_into_person_id IS
'When a duplicate person record is merged, points to the surviving person_id. Always NULL today (no merges post-migration). Rows with a value here should be excluded from people counts once merges begin.';

-- ===================== VERIFICATION =====================

-- [13/13] Expect: dim_brand_active 16/17, bridge 15/18, person 14/15
-- (uncommented by design: app_override_request_id on both dims;
--  role_column, allocation_basis, bridge_key on the bridge)
SELECT table_name,
       count(CASE WHEN comment IS NOT NULL AND comment != '' THEN 1 END) AS commented,
       count(*) AS total_columns
FROM swim_data_whse.information_schema.columns
WHERE table_schema = 'productops_gold'
  AND table_name IN ('gold_v_dim_brand_active',
                     'gold_v_bridge_brand_person_active',
                     'gold_v_dim_person_active')
GROUP BY table_name;

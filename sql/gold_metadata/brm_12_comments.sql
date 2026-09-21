-- =====================================================================
-- Task 1.2: Agent-facing comments on BRM secured views
-- BRM Semantic Layer Implementation | 2026-09-03
-- Run one statement at a time (editor executes statement under cursor).
-- Statements are numbered [n/71]. Verification query at the end.
-- Domains verified live 2026-09-03: role_type (8 values), role_level (2),
-- allocation_type (4), summary view (27 columns). Baseline: 144 current
-- brands, 58 active. No placeholder_flag in Gold (stayed in Silver).
-- =====================================================================

-- ============ gold_v_dim_brand_active (view + 16 columns) ============

-- [1/71]
COMMENT ON VIEW swim_data_whse.productops_gold.gold_v_dim_brand_active IS
'Grain: one row per ACTIVE brand (is_current = true AND is_active = true; 58 rows at 2026-09 baseline). Row-level security is enforced per querying user via fn_brand_access_filter; different users see different row counts by design. Use for questions about active brands only. For questions including dropped or archived brands use gold_v_dim_brand_all. Do not aggregate staffing or customer names from this view; use gold_v_bridge_brand_person_active and gold_v_bridge_brand_customer_active.';

-- [2/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.brand_id IS
'Persistent surrogate key (brand001, brand002, ...). Immutable across renames. Join key to all bridge and xref views.';

-- [3/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.brand_name IS
'Current canonical display name from the brand name registry. Renames change this value but never brand_id.';

-- [4/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.brand_status IS
'Raw operational lifecycle status. Domain: Active, DROPPED. Prefer filtering on is_active (certified boolean) rather than string-matching this column.';

-- [5/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.is_active IS
'Certified activity flag (true when brand_status = Active). The signed definition of an active brand. Always true in this view; exposed for schema consistency with gold_v_dim_brand_all.';

-- [6/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.brand_classification IS
'Classification tier. Example values: SWIM USA Owned / National Brand, Private Label. Governed vocabulary pending in ref_classification (D6).';

-- [7/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.brand_category IS
'Design category mapping. Example values: Design - Private Label, Design - Target. Governed vocabulary pending in ref_category (D6).';

-- [8/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.division IS
'Business division code (BF, MS, SS, PB and others; 11 distinct among active brands). Codes only; business names pending in ref_division (D6).';

-- [9/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.control_flag IS
'Control group membership (true/false). Business meaning: brand is in the control group for measurement. Not a security or data-quality flag.';

-- [10/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.artwork IS
'Artwork assignment group. Example values: LACD, NYCD.';

-- [11/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.lab_fit_fabric IS
'Fabric fit lab assignment. Example value: SWIM USA - PDC Lab.';

-- [12/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.effective_start_date IS
'SCD2 metadata: when this version of the brand record became current. Not a business launch date; do not use to answer when a brand started.';

-- [13/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.effective_end_date IS
'SCD2 metadata: always NULL in this view (current records only).';

-- [14/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.is_current IS
'SCD2 flag: always true in this view. Historical versions are not exposed to consumers.';

-- [15/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.app_override_flag IS
'True when at least one current field value originated from an APPROVED Brand Road Map Edit app request rather than the Airtable source. Lineage marker, not a quality flag.';

-- [16/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.app_override_at IS
'Timestamp the most recent approved edit override was applied by the pipeline. NULL when no override.';

-- [17/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_active.last_modified_source IS
'Lineage marker. Domain: APP2 (current value includes an approved edit) or BRONZE (value came from the Airtable source).';

-- ============ gold_v_dim_brand_all (view + 3 key columns) ============

-- [18/71]
COMMENT ON VIEW swim_data_whse.productops_gold.gold_v_dim_brand_all IS
'Grain: one row per CURRENT brand in any lifecycle state, including DROPPED (144 rows at 2026-09 baseline, of which 58 active). is_current = true only; no SCD2 history. Row-level security enforced per querying user via fn_brand_access_filter. This is the source for the signed All Brands measure; filter is_active = true to match gold_v_dim_brand_active. Column meanings are documented on gold_v_dim_brand_active.';

-- [19/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_all.is_active IS
'Certified activity flag. true = operational brand (58 at baseline), false = DROPPED or archived (86 at baseline). The signed Active Brands definition filters on this.';

-- [20/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_all.brand_status IS
'Raw lifecycle status. Domain: Active, DROPPED. Prefer is_active for filtering.';

-- [21/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_brand_all.brand_id IS
'Persistent surrogate key (brand001...). Unique within this view. Join key to all bridge and xref views.';

-- ============ gold_v_brand_name_active / _all (2 views + 2 columns) ============

-- [22/71]
COMMENT ON VIEW swim_data_whse.productops_gold.gold_v_brand_name_active IS
'Grain: one row per active brand identity (brand_id to canonical brand_name). Lightweight name lookup; RLS enforced via fn_brand_access_filter. For brand attributes use gold_v_dim_brand_active.';

-- [23/71]
COMMENT ON VIEW swim_data_whse.productops_gold.gold_v_brand_name_all IS
'Grain: one row per current brand identity including DROPPED brands. Lightweight name lookup; RLS enforced via fn_brand_access_filter.';

-- [24/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_brand_name_active.brand_id IS
'Persistent surrogate key. Immutable across renames.';

-- [25/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_brand_name_active.brand_name IS
'Current canonical brand display name.';

-- ============ gold_v_dim_person_active (view + 3 columns) ============

-- [26/71]
COMMENT ON VIEW swim_data_whse.productops_gold.gold_v_dim_person_active IS
'Grain: one row per active person (is_current = true AND is_active = true). Global lookup: NOT brand-filtered (person names are not brand-scoped data); brand access is enforced on the bridge views. A person is active when assigned to at least one active brand. Non-person system tokens (KSS, FACTORY DIRECT, PDC and similar) are excluded upstream. Source for the signed Active People measure (company-wide distinct person count).';

-- [27/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_person_active.person_id IS
'Persistent surrogate key (person001...). Join key to gold_v_bridge_brand_person_active. Synthetic AGENT identities (person900 and up) are reserved for automation and excluded from staffing analytics.';

-- [28/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_person_active.person_name IS
'Person display name as extracted from staffing fields.';

-- [29/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_dim_person_active.is_active IS
'True when the person holds at least one current assignment to an active brand.';

-- ============ gold_v_bridge_brand_person_active (view + 5 columns) ============

-- [30/71]
COMMENT ON VIEW swim_data_whse.productops_gold.gold_v_bridge_brand_person_active IS
'Grain: one row per active brand-person-role assignment. A person assigned to 3 brands in 2 roles appears 6 times, so COUNT(*) counts assignments, NOT people; per the signed definitions, people counts must be COUNT(DISTINCT person_id). RLS enforced per querying user via fn_brand_access_filter. Non-person tokens excluded upstream. This is the source for the signed Active Brand-Assigned People measure.';

-- [31/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_bridge_brand_person_active.brand_id IS
'FK to gold_v_dim_brand_active.brand_id.';

-- [32/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_bridge_brand_person_active.person_id IS
'FK to gold_v_dim_person_active.person_id.';

-- [33/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_bridge_brand_person_active.role_type IS
'Functional role of the assignment. Domain (verified 2026-09-03): Asia_Merch, Design, PM, RM_Fabric, RM_Sourcing, RM_Trims, Sales, TD. TD = Technical Design, PM = Product Management, RM = Raw Materials.';

-- [34/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_bridge_brand_person_active.role_level IS
'Seniority of the assignment. Domain: Lead, Contributor. Note: Asia_Merch, RM_Fabric and RM_Trims occur only as Contributor; RM_Sourcing only as Lead.';

-- [35/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_bridge_brand_person_active.is_active IS
'True when the assigned brand is active. Always true in this view.';

-- ============ gold_v_bridge_brand_customer_active (view + 2 columns) ============

-- [36/71]
COMMENT ON VIEW swim_data_whse.productops_gold.gold_v_bridge_brand_customer_active IS
'Grain: one row per active brand-customer (retailer account) link. A brand sold through 3 retailers appears 3 times. RLS enforced per querying user via fn_brand_access_filter. Customer counts must be COUNT(DISTINCT customer_id).';

-- [37/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_bridge_brand_customer_active.brand_id IS
'FK to gold_v_dim_brand_active.brand_id.';

-- [38/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_bridge_brand_customer_active.customer_id IS
'Persistent customer surrogate key (cust001...). Retail customer accounts (Academy, Target, Amazon, Walmart, Kohl''s, National and similar).';

-- ============ gold_v_alloc_by_delivery_active (view + 3 columns) ============

-- [39/71]
COMMENT ON VIEW swim_data_whse.productops_gold.gold_v_alloc_by_delivery_active IS
'Grain: one row per active brand by allocation_type by facility. Maps lab and color development/bulk work to facilities. RLS enforced per querying user via fn_brand_access_filter.';

-- [40/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_alloc_by_delivery_active.brand_id IS
'FK to gold_v_dim_brand_active.brand_id.';

-- [41/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_alloc_by_delivery_active.allocation_type IS
'Type of facility allocation. Domain (verified 2026-09-03): Lab Development Fabric, Lab Bulk Fabric, Color Development Prints/S&O, Color Bulk Prints & Solids. S&O = strike-offs.';

-- [42/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_v_alloc_by_delivery_active.allocation_value IS
'Assigned facility or team for this allocation type (e.g. SWIM USA - PDC LAB, PDC COLORIST).';

-- ============ gold_brand_road_map_summary (view + 27 columns) ============

-- [43/71]
COMMENT ON VIEW swim_data_whse.productops_gold.gold_brand_road_map_summary IS
'Grain: one row per ACTIVE brand; 27 denormalized presentation columns powering the Brand Road Map app grid. RLS enforced per querying user via fn_brand_access_filter. CRITICAL FOR AGENTS: the customers, brand_codes, staffing (us_pm through rm_sourcing_dev_lead) and allocation columns are comma-joined DISPLAY STRINGS built with COLLECT_SET and ARRAY_JOIN. NEVER split, count, or aggregate them; use gold_v_bridge_brand_person_active, gold_v_bridge_brand_customer_active and the xref/allocation views for any counting. Use this view only to display a single brand''s full profile.';

-- [44/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.brand_id IS
'Persistent surrogate key. Join key to all bridge and xref views.';

-- [45/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.brand_name IS
'Current canonical brand display name.';

-- [46/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.brand_status IS
'Lifecycle status; Active for all rows in this view.';

-- [47/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.brand_classification IS
'Classification tier (SWIM USA Owned / National Brand, Private Label).';

-- [48/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.brand_category IS
'Design category mapping (Design - Private Label, Design - Target, ...).';

-- [49/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.division IS
'Division code (BF, MS, SS, PB, ...). See ref_division once published (D6).';

-- [50/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.control_flag IS
'Control group membership flag.';

-- [51/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.artwork IS
'Artwork assignment group (LACD, NYCD, ...).';

-- [52/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.lab_fit_fabric IS
'Fabric fit lab assignment.';

-- [53/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.customers IS
'DISPLAY STRING: comma-joined retail customer names. Never split or count; use gold_v_bridge_brand_customer_active.';

-- [54/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.brand_codes IS
'DISPLAY STRING: comma-joined BlueCherry ERP brand codes. Never split or count; use the xref view for code-level analysis.';

-- [55/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.us_pm_lead IS
'DISPLAY STRING: PM Lead name(s), comma-joined. Never split or count; use the staffing bridge (role_type = PM, role_level = Lead).';

-- [56/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.us_pm IS
'DISPLAY STRING: PM Contributor name(s), comma-joined. Never split or count; use the staffing bridge (role_type = PM, role_level = Contributor).';

-- [57/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.global_td_lead IS
'DISPLAY STRING: Technical Design Lead name(s). Never split or count; use the staffing bridge (role_type = TD, role_level = Lead).';

-- [58/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.td_contributors IS
'DISPLAY STRING: Technical Design Contributor name(s), comma-joined. Never split or count; use the staffing bridge (role_type = TD, role_level = Contributor).';

-- [59/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.us_design_lead IS
'DISPLAY STRING: Design Lead name(s). Never split or count; use the staffing bridge (role_type = Design, role_level = Lead).';

-- [60/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.global_patternmakers IS
'DISPLAY STRING: patternmaking facility or team. May contain non-person tokens (FACTORY DIRECT, PDC). Never split or count.';

-- [61/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.us_sales_lead IS
'DISPLAY STRING: Sales Lead name(s). Never split or count; use the staffing bridge (role_type = Sales, role_level = Lead).';

-- [62/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.us_sales IS
'DISPLAY STRING: Sales Contributor name(s), comma-joined. Never split or count; use the staffing bridge (role_type = Sales, role_level = Contributor).';

-- [63/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.asia_merchandiser IS
'DISPLAY STRING: Asia Merchandising name(s). Never split or count; use the staffing bridge (role_type = Asia_Merch).';

-- [64/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.rm_fabric IS
'DISPLAY STRING: Raw Materials Fabric name(s), comma-joined. Never split or count; use the staffing bridge (role_type = RM_Fabric).';

-- [65/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.rm_trims IS
'DISPLAY STRING: Raw Materials Trims name(s), comma-joined. Never split or count; use the staffing bridge (role_type = RM_Trims).';

-- [66/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.rm_sourcing_dev_lead IS
'DISPLAY STRING: Sourcing and Development Lead name(s). Never split or count; use the staffing bridge (role_type = RM_Sourcing, role_level = Lead).';

-- [67/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.lab_dev_fabric IS
'DISPLAY STRING: Lab Development Fabric facility allocation. Never split or count; use gold_v_alloc_by_delivery_active (allocation_type = Lab Development Fabric).';

-- [68/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.lab_bulk_fabric IS
'DISPLAY STRING: Lab Bulk Fabric facility allocation. Never split or count; use gold_v_alloc_by_delivery_active (allocation_type = Lab Bulk Fabric).';

-- [69/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.color_dev_prints_so IS
'DISPLAY STRING: Color Development Prints and Strike-Off colorist allocation. Never split or count; use gold_v_alloc_by_delivery_active (allocation_type = Color Development Prints/S&O).';

-- [70/71]
COMMENT ON COLUMN swim_data_whse.productops_gold.gold_brand_road_map_summary.color_bulk_prints_solids IS
'DISPLAY STRING: Color Bulk Prints and Solids colorist allocation. Never split or count; use gold_v_alloc_by_delivery_active (allocation_type = Color Bulk Prints & Solids).';

-- ============ RLS function comment (was empty; flagged in task 0.1) ============

-- [71/71] If this errors as unsupported on your runtime, skip it; we fold the
-- comment into the function's next CREATE OR REPLACE during the D2 migration.
COMMENT ON FUNCTION swim_data_whse.productops_gold.fn_brand_access_filter IS
'Row-level security filter for brand access. Returns TRUE if CURRENT_USER() may see the given brand_id: admins (user_person_map.role = admin) see all brands; users see brands assigned via bridge_brand_person; no_access and unmapped identities see nothing (default deny). Embedded in the WHERE clause of every secured gold_v_* view. Registered identities include service principals by application ID.';

-- ===================== VERIFICATION (run last) =====================
-- Expect: each listed view shows commented > 0 and view_comment = YES.
SELECT
  table_name,
  count(CASE WHEN comment IS NOT NULL THEN 1 END) AS commented_columns,
  count(*) AS total_columns
FROM swim_data_whse.information_schema.columns
WHERE table_schema = 'productops_gold'
  AND table_name IN (
    'gold_v_dim_brand_active','gold_v_dim_brand_all',
    'gold_v_brand_name_active','gold_v_brand_name_all',
    'gold_v_dim_person_active','gold_v_bridge_brand_person_active',
    'gold_v_bridge_brand_customer_active','gold_v_alloc_by_delivery_active',
    'gold_brand_road_map_summary')
GROUP BY table_name
ORDER BY table_name;

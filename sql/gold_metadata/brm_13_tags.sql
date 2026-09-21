-- =====================================================================
-- Task 1.3: Certification tags on the BRM Gold surface
-- BRM Semantic Layer Implementation | 2026-09-03
-- 18 numbered statements + verification. Run All is safe (verified in 1.2);
-- if it halts, note the statement number.
-- Standing rule: an object without certified = 'true' never enters a Genie
-- space, an MCP grant, or a Power BI certified dataset.
-- =====================================================================

-- ============ Certified views (9) ============

-- [1/18]
ALTER VIEW swim_data_whse.productops_gold.gold_v_dim_brand_active
  SET TAGS ('certified' = 'true', 'domain' = 'brm', 'security' = 'rls-view', 'consumer' = 'agents,bi');

-- [2/18]
ALTER VIEW swim_data_whse.productops_gold.gold_v_dim_brand_all
  SET TAGS ('certified' = 'true', 'domain' = 'brm', 'security' = 'rls-view', 'consumer' = 'agents,bi');

-- [3/18]
ALTER VIEW swim_data_whse.productops_gold.gold_v_brand_name_active
  SET TAGS ('certified' = 'true', 'domain' = 'brm', 'security' = 'rls-view', 'consumer' = 'agents,bi');

-- [4/18]
ALTER VIEW swim_data_whse.productops_gold.gold_v_brand_name_all
  SET TAGS ('certified' = 'true', 'domain' = 'brm', 'security' = 'rls-view', 'consumer' = 'agents,bi');

-- [5/18]
ALTER VIEW swim_data_whse.productops_gold.gold_v_dim_person_active
  SET TAGS ('certified' = 'true', 'domain' = 'brm', 'security' = 'global-lookup', 'consumer' = 'agents,bi');

-- [6/18]
ALTER VIEW swim_data_whse.productops_gold.gold_v_bridge_brand_person_active
  SET TAGS ('certified' = 'true', 'domain' = 'brm', 'security' = 'rls-view', 'consumer' = 'agents,bi');

-- [7/18]
ALTER VIEW swim_data_whse.productops_gold.gold_v_bridge_brand_customer_active
  SET TAGS ('certified' = 'true', 'domain' = 'brm', 'security' = 'rls-view', 'consumer' = 'agents,bi');

-- [8/18]
ALTER VIEW swim_data_whse.productops_gold.gold_v_alloc_by_delivery_active
  SET TAGS ('certified' = 'true', 'domain' = 'brm', 'security' = 'rls-view', 'consumer' = 'agents,bi');

-- [9/18]
ALTER VIEW swim_data_whse.productops_gold.gold_brand_road_map_summary
  SET TAGS ('certified' = 'true', 'domain' = 'brm', 'security' = 'rls-view', 'consumer' = 'app1,agents,bi');

-- ============ Pipeline-only Gold tables (8) ============

-- [10/18]
ALTER TABLE swim_data_whse.productops_gold.brand_name_registry
  SET TAGS ('certified' = 'false', 'domain' = 'brm', 'access' = 'pipeline-only', 'note' = 'unfiltered; do not grant to consumers');

-- [11/18]
ALTER TABLE swim_data_whse.productops_gold.dim_brand
  SET TAGS ('certified' = 'false', 'domain' = 'brm', 'access' = 'pipeline-only', 'note' = 'unfiltered; do not grant to consumers');

-- [12/18]
ALTER TABLE swim_data_whse.productops_gold.dim_person
  SET TAGS ('certified' = 'false', 'domain' = 'brm', 'access' = 'pipeline-only', 'note' = 'unfiltered; do not grant to consumers');

-- [13/18]
ALTER TABLE swim_data_whse.productops_gold.dim_customer
  SET TAGS ('certified' = 'false', 'domain' = 'brm', 'access' = 'pipeline-only', 'note' = 'unfiltered; do not grant to consumers');

-- [14/18]
ALTER TABLE swim_data_whse.productops_gold.bridge_brand_person
  SET TAGS ('certified' = 'false', 'domain' = 'brm', 'access' = 'pipeline-and-rls', 'note' = 'unfiltered; SELECT required by fn_brand_access_filter evaluation until D2 migration');

-- [15/18]
ALTER TABLE swim_data_whse.productops_gold.bridge_brand_customer
  SET TAGS ('certified' = 'false', 'domain' = 'brm', 'access' = 'pipeline-only', 'note' = 'unfiltered; do not grant to consumers');

-- [16/18]
ALTER TABLE swim_data_whse.productops_gold.xref_brand_erp_code
  SET TAGS ('certified' = 'false', 'domain' = 'brm', 'access' = 'pipeline-only', 'note' = 'unfiltered; do not grant to consumers');

-- [17/18]
ALTER TABLE swim_data_whse.productops_gold.allocation_by_delivery
  SET TAGS ('certified' = 'false', 'domain' = 'brm', 'access' = 'pipeline-only', 'note' = 'unfiltered; do not grant to consumers');

-- ============ Security config table (1) ============

-- [18/18]
ALTER TABLE swim_data_whse.productops_gold.user_person_map
  SET TAGS ('certified' = 'false', 'domain' = 'brm', 'access' = 'security-config', 'note' = 'identity and role registry read by fn_brand_access_filter; changes via the user onboarding runbook only');

-- ===================== VERIFICATION (run last) =====================
-- Expect 18 rows (one per object) with the certified tag value shown.
SELECT table_name, tag_name, tag_value
FROM swim_data_whse.information_schema.table_tags
WHERE schema_name = 'productops_gold'
  AND tag_name = 'certified'
ORDER BY tag_value DESC, table_name;

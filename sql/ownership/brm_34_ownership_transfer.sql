-- =====================================================================
-- Task 3.3: productops_semantic ownership transfer to brm_semantic_stewards
-- BRM Semantic Layer Implementation | 2026-09-21
--
-- PREREQUISITE (account console, not SQL): create the ACCOUNT group
-- `brm_semantic_stewards` and add Dave Christy plus the steward
-- engineer. Unity Catalog owners must be account-level groups.
--
-- WHY THE GRANTS COME FIRST: Unity Catalog views check the VIEW OWNER's
-- privileges on the objects the view references (the invoker only needs
-- SELECT on the view itself; fn_brand_access_filter's CURRENT_USER()
-- filtering is separate from this privilege check). If ownership moves
-- before the group holds SELECT on the source views, every metric view
-- breaks for everyone. Run in order, one statement at a time.
-- =====================================================================

-- ============ Step 1: source-object privileges for the new owner ============

-- [1/14]
GRANT USE CATALOG ON CATALOG swim_data_whse TO `brm_semantic_stewards`;

-- [2/14]
GRANT USE SCHEMA ON SCHEMA swim_data_whse.productops_gold TO `brm_semantic_stewards`;

-- [3/14]
GRANT USE SCHEMA ON SCHEMA swim_data_whse.productops_semantic TO `brm_semantic_stewards`;

-- [4/14] Source views of the four metric views (grant all four sources)
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_dim_brand_all TO `brm_semantic_stewards`;

-- [5/14]
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_bridge_brand_person_active TO `brm_semantic_stewards`;

-- [6/14]
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_dim_person_active TO `brm_semantic_stewards`;

-- [7/14]
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_bridge_brand_customer_active TO `brm_semantic_stewards`;

-- [8/14] RLS machinery, same reasoning as task 2.2 (the gold views the
--        metric views reference themselves reference these)
GRANT SELECT ON TABLE swim_data_whse.productops_gold.user_person_map TO `brm_semantic_stewards`;

-- [9/14]
GRANT SELECT ON TABLE swim_data_whse.productops_gold.bridge_brand_person TO `brm_semantic_stewards`;

-- [9b/14]
GRANT SELECT ON TABLE swim_data_whse.productops_gold.agent_brand_scope TO `brm_semantic_stewards`;

-- [10/14]
GRANT EXECUTE ON FUNCTION swim_data_whse.productops_gold.fn_brand_access_filter TO `brm_semantic_stewards`;

-- ============ Step 2: ownership transfer ============

-- [11/14]
ALTER SCHEMA swim_data_whse.productops_semantic OWNER TO `brm_semantic_stewards`;

-- [12/14] The four metric views (object owners do not change with the schema)
ALTER VIEW swim_data_whse.productops_semantic.mv_brm_brand     OWNER TO `brm_semantic_stewards`;
ALTER VIEW swim_data_whse.productops_semantic.mv_brm_staffing  OWNER TO `brm_semantic_stewards`;
ALTER VIEW swim_data_whse.productops_semantic.mv_brm_people    OWNER TO `brm_semantic_stewards`;
ALTER VIEW swim_data_whse.productops_semantic.mv_brm_customers OWNER TO `brm_semantic_stewards`;

-- ===================== VERIFICATION =====================

-- [13/14] Owners landed (expect brm_semantic_stewards on schema + 4 views)
DESCRIBE SCHEMA EXTENDED swim_data_whse.productops_semantic;

SELECT table_name, table_owner
FROM swim_data_whse.information_schema.tables
WHERE table_schema = 'productops_semantic';

-- [14/14] CRITICAL post-transfer smoke test, run as YOURSELF and have a
--         brand-limited user repeat it: the metric views must still
--         answer, and RLS must still track the ASKING user (owner-based
--         privilege check changed, invoker-based filtering must not).
SELECT MEASURE(all_brands) AS all_brands
FROM swim_data_whse.productops_semantic.mv_brm_brand;

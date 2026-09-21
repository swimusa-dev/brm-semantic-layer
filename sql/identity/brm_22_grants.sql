-- =====================================================================
-- Task 2.2: Grants for agent principals (swimusa_agents)
-- BRM Semantic Layer Implementation | 2026-09-04
-- 15 numbered statements + verification. Run All is fine.
-- Already in place from task 2.1: agent_brand_scope SELECT mirroring.
-- NOTE: the negative test at the bottom is BLOCKED BY TASK 2.4 (the
-- account-users catalog SELECT makes direct table reads succeed for
-- everyone today). Apply these grants anyway: they are what makes the
-- model correct the moment 2.4 remediation lands.
-- =====================================================================

-- ============ Schema access ============

-- [1/15]
GRANT USE CATALOG ON CATALOG swim_data_whse TO `swimusa_agents`;

-- [2/15]
GRANT USE SCHEMA ON SCHEMA swim_data_whse.productops_gold TO `swimusa_agents`;

-- [3/15]
GRANT USE SCHEMA ON SCHEMA swim_data_whse.productops_semantic TO `swimusa_agents`;

-- ============ The 9 certified views, and ONLY these ============

-- [4/15]
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_dim_brand_active TO `swimusa_agents`;

-- [5/15]
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_dim_brand_all TO `swimusa_agents`;

-- [6/15]
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_brand_name_active TO `swimusa_agents`;

-- [7/15]
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_brand_name_all TO `swimusa_agents`;

-- [8/15]
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_dim_person_active TO `swimusa_agents`;

-- [9/15]
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_bridge_brand_person_active TO `swimusa_agents`;

-- [10/15]
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_bridge_brand_customer_active TO `swimusa_agents`;

-- [11/15]
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_v_alloc_by_delivery_active TO `swimusa_agents`;

-- [12/15]
GRANT SELECT ON VIEW swim_data_whse.productops_gold.gold_brand_road_map_summary TO `swimusa_agents`;

-- ============ RLS machinery (required for invoker evaluation) ============

-- [13/15]
GRANT SELECT ON TABLE swim_data_whse.productops_gold.user_person_map TO `swimusa_agents`;

-- [14/15]
GRANT SELECT ON TABLE swim_data_whse.productops_gold.bridge_brand_person TO `swimusa_agents`;
-- Known, inherited, bounded exposure (same as App 1): invoker-evaluated RLS
-- requires table SELECT here. The D2 migration removes this need.

-- [15/15]
GRANT EXECUTE ON FUNCTION swim_data_whse.productops_gold.fn_brand_access_filter TO `swimusa_agents`;

-- Deliberately NOT granted: any Gold table besides the two above, anything
-- in productops_bronze, productops_silver, or productops_audit, and any
-- PRM object (gold_v_dim_partner_*, gold_v_dim_site_*, capacity/workload
-- views): PRM views carry NO RLS per the handover doc. This omission is
-- the policy from task 0.1.

-- ===================== VERIFICATION =====================

-- [V1] Full grant inventory for the group (expect: USE CATALOG, 2x USE SCHEMA,
--      10x SELECT on views/tables incl. agent_brand_scope from task 2.1,
--      SELECT on user_person_map + bridge_brand_person, EXECUTE on function)
SHOW GRANTS TO `swimusa_agents`;

-- [V2] BLOCKED BY 2.4, run anyway to document current state: as a
--      swimusa_agents member who is NOT admin-mapped, this SHOULD fail
--      with permission denied but today succeeds via the account-users
--      catalog SELECT. Record the outcome on task 2.4; re-test after
--      remediation.
-- SELECT count(*) FROM swim_data_whse.productops_gold.dim_brand;

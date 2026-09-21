-- =====================================================================
-- Task 2.1: Agent identity, agent_brand_scope, and RLS function update
-- BRM Semantic Layer Implementation | 2026-09-03
-- Agent SP: agent-cowork-brand-analyst (2b28b841-2020-4631-b71a-945e48bdf1b4)
--
-- ORDER MATTERS. Steps 1-4 are safe anytime. STOP after step 1 and send
-- the output to Claude before running step 3 (grant mirroring must match
-- reality, not assumptions). Step 5 replaces the PRODUCTION security
-- function: run at a quiet time, verify immediately with step 7.
--
-- ROLLBACK for step 5 (original function, captured from live DESCRIBE
-- 2026-09-03): re-run the CREATE OR REPLACE in step 5 with the third
-- EXISTS block (agent_brand_scope) deleted. The first two blocks below
-- are byte-equivalent to production.
-- =====================================================================

-- [1] Discover who has grants on user_person_map today. The same
--     principals need SELECT on agent_brand_scope BEFORE the function
--     changes. SEND THIS OUTPUT TO CLAUDE, then continue.
SHOW GRANTS ON TABLE swim_data_whse.productops_gold.user_person_map;

-- [2] Create the agent scope table (manually governed; pipeline never
--     touches it, so scope survives every scd2_merge/full_replace run).
CREATE TABLE IF NOT EXISTS swim_data_whse.productops_gold.agent_brand_scope (
  principal_id STRING NOT NULL COMMENT 'Identity as CURRENT_USER() resolves it: service principal application ID (or user email for a delegated edge case). Matches user_person_map.user_email convention.',
  brand_id     STRING NOT NULL COMMENT 'FK to dim_brand.brand_id. One row per principal-brand grant.',
  granted_by   STRING NOT NULL COMMENT 'Email of the admin who granted this scope.',
  granted_at   TIMESTAMP NOT NULL COMMENT 'When the scope row was created.',
  is_active    BOOLEAN NOT NULL COMMENT 'Revocation flag. Never delete rows (audit preservation rule); set false to revoke.',
  note         STRING COMMENT 'Why this principal may see this brand.'
)
COMMENT 'Brand visibility scope for AGENT service principals, read by fn_brand_access_filter path 3. Manually governed like user_person_map: never deleted, only deactivated. Exists because bridge_brand_person is pipeline-managed (scd2_merge closes rows absent from source), so synthetic agent assignments cannot durably live there. Changes follow the same runbook as user_person_map.';

-- [2b]
ALTER TABLE swim_data_whse.productops_gold.agent_brand_scope
  SET TAGS ('certified' = 'false', 'domain' = 'brm', 'access' = 'security-config', 'note' = 'agent RLS scope registry; changes via security runbook only');

-- [3] Mirror the grants found in step 1 onto agent_brand_scope.
--     TEMPLATE: adjust principals to EXACTLY match step 1 output.
--     Typical expected set (confirm before running):
-- GRANT SELECT ON TABLE swim_data_whse.productops_gold.agent_brand_scope TO `<each principal with SELECT on user_person_map>`;
-- GRANT SELECT ON TABLE swim_data_whse.productops_gold.agent_brand_scope TO `swimusa_agents`;

-- [4] Register the agent SP in user_person_map (10 columns, doc order).
--     person_id is NULL by design: agent scope lives in agent_brand_scope,
--     not bridge_brand_person, so no synthetic person row is needed.
INSERT INTO swim_data_whse.productops_gold.user_person_map VALUES (
  '2b28b841-2020-4631-b71a-945e48bdf1b4',  -- user_email: SP application ID
  NULL,                                    -- person_id: none; scope via agent_brand_scope
  'user',                                  -- role: NOT admin (D3)
  current_timestamp(),                     -- assigned_at
  true,                                    -- is_active
  'Agent - Scoped Analyst',                -- persona_tier
  'BRM',                                   -- module_scope
  'swimusa_agents',                        -- databricks_group
  false,                                   -- can_edit: agents never submit App 2 edits
  false                                    -- can_approve: agents never approve
);

-- [5] Replace the RLS function. HIGH RISK CHANGE: run at a quiet time.
--     Paths 1 and 2 are byte-equivalent to production (captured 2026-09-03).
--     Path 3 is new and additive. COMMENT closes the gap from task 1.2 [71].
CREATE OR REPLACE FUNCTION swim_data_whse.productops_gold.fn_brand_access_filter(brand_id STRING)
RETURNS BOOLEAN
COMMENT 'Row-level security filter for brand access. Returns TRUE if CURRENT_USER() may see the given brand_id. Path 1: admins (user_person_map.role = admin, is_active) see all brands. Path 2: users see brands assigned via bridge_brand_person (role != no_access). Path 3: agent service principals see brands granted in agent_brand_scope (pipeline-independent registry; added 2026-09-03 per decisions D3/D7). Unmapped, inactive, and no_access identities see nothing (default deny). Embedded in the WHERE clause of every secured gold_v_* view. v1.1.0'
RETURN
  -- Path 1: Admin bypass (admin role sees all brands)
  EXISTS (
    SELECT 1 FROM swim_data_whse.productops_gold.user_person_map
    WHERE user_email = CURRENT_USER()
      AND role = 'admin'
      AND is_active = TRUE
  )
  OR
  -- Path 2: Non-admin brand assignment check via staffing bridge
  EXISTS (
    SELECT 1 FROM swim_data_whse.productops_gold.user_person_map u
    JOIN swim_data_whse.productops_gold.bridge_brand_person bp
      ON u.person_id = bp.person_id
    WHERE u.user_email = CURRENT_USER()
      AND u.is_active = TRUE
      AND u.role != 'no_access'
      AND bp.brand_id = fn_brand_access_filter.brand_id
      AND bp.is_current = TRUE
      AND bp.is_active = TRUE
  )
  OR
  -- Path 3: Agent scope check (manually governed, pipeline-independent)
  EXISTS (
    SELECT 1 FROM swim_data_whse.productops_gold.agent_brand_scope s
    WHERE s.principal_id = CURRENT_USER()
      AND s.is_active = TRUE
      AND s.brand_id = fn_brand_access_filter.brand_id
  );

-- [6] Seed two test scope rows for the agent SP (real active brand_ids;
--     swap if these two are not suitable test brands).
INSERT INTO swim_data_whse.productops_gold.agent_brand_scope VALUES
  ('2b28b841-2020-4631-b71a-945e48bdf1b4', 'brand001', 'dchristy@swimusa.com', current_timestamp(), true, 'Initial test scope for identity validation (task 6.2)'),
  ('2b28b841-2020-4631-b71a-945e48bdf1b4', 'brand003', 'dchristy@swimusa.com', current_timestamp(), true, 'Initial test scope for identity validation (task 6.2)');

-- ===================== VERIFICATION (run all, in order) =====================

-- [V1] Function replaced, comment present, three EXISTS paths visible
DESCRIBE FUNCTION EXTENDED swim_data_whse.productops_gold.fn_brand_access_filter;

-- [V2] Admin behavior unchanged (expect 58 active / 144 all, or current baseline)
SELECT count(*) AS active_visible FROM swim_data_whse.productops_gold.gold_v_dim_brand_active;
SELECT count(*) AS all_visible    FROM swim_data_whse.productops_gold.gold_v_dim_brand_all;

-- [V3] Mapping row landed
SELECT user_email, person_id, role, is_active, persona_tier, can_edit, can_approve
FROM swim_data_whse.productops_gold.user_person_map
WHERE user_email = '2b28b841-2020-4631-b71a-945e48bdf1b4';

-- [V4] Scope rows landed
SELECT * FROM swim_data_whse.productops_gold.agent_brand_scope;

-- [V5] MANUAL: open App 1 as yourself; grid must load with full counts.
--      Have a brand-limited user (dzou or tmooney) open App 1 and confirm
--      their counts are unchanged. The SP's end-to-end test (CURRENT_USER()
--      = application ID seeing exactly brand001/brand003) happens in task
--      5.2 when its OAuth credentials exist.

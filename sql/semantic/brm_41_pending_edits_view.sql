-- =====================================================================
-- Task 4.1 (part 1): Drift check + gold_v_brm_pending_edits (D4 object)
-- BRM Semantic Layer Implementation | 2026-09-29
--
-- [0] runs first because a week has passed: it tells us whether Koantek
-- redeployed again (comment wipe) and whether the SWIM-1050 UAT reverts
-- landed (brand counts move). [1]-[2] are discovery on brm_edit_requests
-- (the MVP may have reshaped it like it did the person/bridge views):
-- PASTE THEIR OUTPUT BEFORE RUNNING [3]. [3]-[5] build, tag, and grant
-- the D4 governance view. One statement at a time.
-- =====================================================================

-- [0] Weekly drift check (expect: 19 commented views if no redeploy;
--     active_brands 57 and divisions 13 if reverts have NOT landed)
SELECT count(DISTINCT table_name) AS views_with_comments
FROM swim_data_whse.information_schema.columns
WHERE table_schema = 'productops_gold'
  AND table_name LIKE 'gold_v_%'
  AND comment IS NOT NULL;

SELECT MEASURE(all_brands) AS all_brands,
       MEASURE(active_brands) AS active_brands,
       MEASURE(active_division_count) AS divisions
FROM swim_data_whse.productops_semantic.mv_brm_brand;

-- ============ Discovery on the edit request table ============

-- [1] Shape (the handover doc says record_id, field_name, risk_level,
--     status, submitted_at, approved_at, old_value, new_value,
--     payload_json, submitted_by; verify before trusting)
DESCRIBE swim_data_whse.productops_audit.brm_edit_requests;

-- [2] Status domain and volumes (doc says Pending Approval / Approved;
--     verify, and see how much UAT noise is in here)
SELECT status, count(*) AS rows,
       min(submitted_at) AS earliest, max(submitted_at) AS latest
FROM swim_data_whse.productops_audit.brm_edit_requests
GROUP BY status;

-- ============ The D4 governance view (run AFTER [1]-[2] confirm) ============

-- [3] Verified against live shape 2026-09-29 (19 columns, far beyond the
--     handover doc). Deliberately excluded: old_value, new_value,
--     payload_json, submitted_by, approved_by, comments, rejection_note.
--     The join through gold_v_dim_brand_all is what applies RLS, and it
--     also naturally restricts rows to brand records. STATUS FILTER: the
--     live domain today is only Approved/Rejected (no pending rows
--     exist), so the pending label is unobservable; excluding Rejected
--     keeps every non-terminal status visible without guessing labels.
--     Tighten to an IN list once a real pending row shows the label.
--     TIGHTENED 2026-09-29: a live pending row confirmed the label is
--     'Pending Approval' exactly; full observed domain is Pending
--     Approval / Approved / Rejected, filter is now the explicit list.
--     NOTE: any CREATE OR REPLACE of this view wipes its column
--     comments and can reset tags; re-run statements 4 and the column
--     comment block after every replace.
CREATE OR REPLACE VIEW swim_data_whse.productops_semantic.gold_v_brm_pending_edits
COMMENT 'Governance awareness view for agents (decision D4, approved 2026-08-28). Grain: one row per pending or approved edit request against a brand the querying user may see (RLS applies through the join to gold_v_dim_brand_all). Discloses THAT a field is changing or changed and its governance status, never the proposed value. Excluded by design: old and new values, payload, submitter and approver identities, comments, rejection notes. Status domain verified 2026-09-29: Pending Approval, Approved, Rejected (rejected excluded here). This is the ONLY object through which agents may learn about edit requests.'
AS
SELECT r.record_id     AS brand_id,
       b.brand_name,
       r.request_type,
       r.field_name,
       r.risk_level,
       r.status,
       r.submitted_at,
       r.approved_at
FROM swim_data_whse.productops_audit.brm_edit_requests r
JOIN swim_data_whse.productops_gold.gold_v_dim_brand_all b
  ON r.record_id = b.brand_id
WHERE r.status IN ('Pending Approval', 'Approved');

-- [4] Tag it certified
ALTER VIEW swim_data_whse.productops_semantic.gold_v_brm_pending_edits
  SET TAGS ('certified' = 'true', 'domain' = 'brm', 'semver' = '1.0.0');

-- [5] Grant to the agent group (their ONLY window into the audit schema,
--     and it is a view in productops_semantic, not an audit grant)
GRANT SELECT ON VIEW swim_data_whse.productops_semantic.gold_v_brm_pending_edits TO `swimusa_agents`;

-- ===================== VERIFICATION =====================

-- [V1] View answers under RLS (as admin: all pending/approved rows on
--      visible brands)
SELECT status, count(*) AS rows
FROM swim_data_whse.productops_semantic.gold_v_brm_pending_edits
GROUP BY status;

-- [V2] Confirm the exclusions: none of these columns may exist
DESCRIBE swim_data_whse.productops_semantic.gold_v_brm_pending_edits;

-- [V3] Tag + grant landed
SELECT table_name, tag_name, tag_value
FROM swim_data_whse.information_schema.table_tags
WHERE schema_name = 'productops_semantic' AND table_name = 'gold_v_brm_pending_edits';

SELECT grantee, privilege_type
FROM swim_data_whse.information_schema.table_privileges
WHERE table_schema = 'productops_semantic'
  AND table_name = 'gold_v_brm_pending_edits'
  AND grantee = 'swimusa_agents';

-- NOTE for the steward: the view owner (whoever runs [3]; transfer to
-- brm_semantic_stewards afterward if that is not you) needs SELECT on
-- productops_audit.brm_edit_requests for the view to serve queries.
-- If [V1] errors with permission denied for a non-admin, grant:
-- GRANT USE SCHEMA ON SCHEMA swim_data_whse.productops_audit TO `brm_semantic_stewards`;
-- GRANT SELECT ON TABLE swim_data_whse.productops_audit.brm_edit_requests TO `brm_semantic_stewards`;
-- then ALTER VIEW ... OWNER TO `brm_semantic_stewards`;

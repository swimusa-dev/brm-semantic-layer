# Policy: AI Agents and the Brand Road Map Edit Workflow

**Status:** Draft for sign-off
**Owner:** Dave Christy, VP of Information Technology and Enterprise AI
**Sign-off required:** App 2 owner, Security owner
**Effective:** Upon sign-off
**Applies to:** All AI agents and service principals querying BRM data (Genie, Claude, scheduled agent jobs), current and future.

## Policy

AI agents are read-only consumers of Brand Road Map data. No agent, service principal, or automated process writes to `swim_data_whse.productops_audit.brm_edit_requests` or any other table in the edit approval workflow.

## Rules

1. **Agents never submit edit requests.** The edit workflow exists to capture human intent with human justification. The `submitted_by` field carries a verified human identity from the App 2 proxy header, and the risk matrix in `brm_approver_group_matrix` assumes a human made the request. A machine-inserted row would attribute machine output to a person and route auto-approvals to changes no human proposed.

2. **Agents may draft edits for humans.** An agent that spots a data issue or is asked to prepare a change may produce the proposed values, the justification text, and the list of affected brands. A person reviews that draft and submits it through App 2 under their own identity. Drafting is assistance; submitting is a human act.

3. **Agent identities are permanently flagged non-editing.** Every agent row in `user_person_map` carries `can_edit = false` and `can_approve = false`. Enforced today for `agent-cowork-brand-analyst` (2b28b841-2020-4631-b71a-945e48bdf1b4); required for every future agent registration.

4. **Agents disclose governance state, never proposed values.** Per decision D4 (approved 2026-08-28), agents may report that an edit is pending and its status, exclusively through the restricted `gold_v_brm_pending_edits` view. Proposed values, submitter identity, and the underlying `brm_edit_requests` table are off limits to agents.

5. **A future agent-initiated edit path is a new governance lane, not a reuse.** If a real case for agent-submitted edits ever emerges, it requires: a new request classification in `brm_approver_group_matrix` covering agent submissions, human approval required at ALL risk levels (no auto-approval lane for machine-originated changes), a distinct `submitted_by` convention identifying the agent, and sign-off from the App 2 owner, the Security owner, and Product Ops leadership before the first row is written. Until that exists, rule 1 is absolute.

## Enforcement

Unity Catalog grants: `swimusa_agents` holds no privileges on `productops_audit` (verified in task 2.2, 2026-09-04). The Phase 8 bypass monitor alerts on any non-pipeline, non-App principal writing to the audit schema.

## Sign-off

| Role | Name | Date |
|---|---|---|
| App 2 owner | | |
| Security owner | | |

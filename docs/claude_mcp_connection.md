# Task 5.1: Connect Claude Cowork to the BRM Genie space (managed MCP)

Runbook for the external agent path. Interactive users connect with OAuth
on-behalf-of (D3): CURRENT_USER() resolves to the person asking, and the
whole fn_brand_access_filter chain applies untouched. The unattended SP
path (M2M secret) is task 5.2, not this document.

## Endpoint decision (2026-09-29)

Use the Genie One MCP service, NOT the per-space Beta endpoint:

- Deprecated: `https://<workspace-host>/api/2.0/mcp/genie/{space_id}` (sunset 2026-10-31)
- Use instead: `https://<workspace-host>/ai-gateway/mcp-services/system.ai.genie_one_mcp`

Genie One is one endpoint for all Genie spaces the AUTHENTICATED USER can
access, via a genie_ask tool. Two consequences: (1) no space_id in the URL,
the BRM space is reached because the user has access to it, so 4.3's
share-list IS the access control for this path; (2) account users hold
EXECUTE on system.ai by default, so no extra grant is normally needed.
Data access remains the asking user's UC identity either way.

## Part A: Databricks account console (account admin, one time)

1. accounts.azuredatabricks.net > Settings > App Connections > Add connection.
2. Name: `claude-cowork-mcp`.
3. Redirect URLs, both: `https://claude.ai/api/mcp/auth_callback` and `https://claude.com/api/mcp/auth_callback`.
4. Client type: PUBLIC. Uncheck "Generate a client secret" (Claude is a public OAuth client; no secret exists to leak).
5. Scopes: prefer granular with the `ai-gateway` scope (required by MCP
   services); `all-apis` also works but grants more than this path needs.
6. Token expiration: defaults are fine to start.
7. Save and record the CLIENT ID.

## Part B: Claude (each user, or org-level if the Claude admin publishes it)

1. Claude: Settings > Connectors > Add custom connector.
2. Name: `Swim USA BRM (Genie)`.
3. URL: `https://<workspace-host>/ai-gateway/mcp-services/system.ai.genie_one_mcp`.
4. OAuth client ID: from Part A. No client secret.
5. Add, then Connect: a Databricks SSO window completes the on-behalf-of flow.

If the workspace uses IP access lists, add Anthropic's published outbound
IPs (docs.anthropic.com/en/api/ip-addresses) to the allowlist first;
otherwise the connector fails opaquely.

## Part C: Verification (this closes 5.1)

Run in a fresh Claude conversation with the connector enabled, as Dave:

1. "Using the Databricks connector, ask the Brand Road Map Genie space: how many active brands do we have?" Expect 48 (current interim baseline) and evidence it used genie_ask.
2. "How many people work on our brands, and how many active people overall?" Expect 161 and 226 with the grain distinction intact.
3. "Are there any pending changes for brand001?" Expect the D4 disclosure, no proposed value.
4. "How many brands did we have last year?" Expect the history-unavailable refusal, no invented number.

Then the identity half, same four questions as dzou (or tmooney) from her
own Claude session with the connector: brand counts limited to her
assignments, no error, no hallucinated fill-in.

Record outcomes on the ClickUp card; mismatches against the same question
asked directly in the Genie space UI are findings, not tuning knobs.

## Security notes for the record

- This path adds NO new data access: the connector holds a user-scoped
  OAuth token, CURRENT_USER() is the person, RLS applies as everywhere else.
- The public OAuth client has no secret; possession of the client ID alone
  grants nothing without completing SSO as a real user.
- Genie One exposes every Genie space the user can access, not only BRM.
  Today BRM is the only space shared beyond admins; revisit when other
  teams build spaces (the eval and drift monitors are BRM-scoped).
- The deprecated per-space endpoint references in the implementation guide
  Phase 5 section are superseded by this document.

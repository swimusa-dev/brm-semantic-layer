# BRM Semantic Layer

Certified semantic layer for the Swim USA Brand Road Map, built over the RLS-secured Gold views in `swim_data_whse.productops_gold`. This repo is the source of truth for every object in `productops_semantic` and for the metadata (comments, tags, constraints) on the certified Gold surface. If it is not in this repo, it is not certified.

## Ownership

| Role | Who | Owns |
|---|---|---|
| Metric owner | Product Ops leadership (S. Nicolello) | Metric definitions (the signed D1 set); approves any measure-logic change |
| Semantic layer steward | Databricks/Power BI engineer | YAML, views, grants, the Genie space, the eval job; sole write path to `productops_semantic` (via the `brm_semantic_stewards` group) |
| Security owner | Owner of `user_person_map` | Agent and human identity registrations, `agent_brand_scope`, `fn_brand_access_filter` |

## Layout

```
sql/
  gold_metadata/   Comments, tags, constraints on the certified Gold surface
                   (brm_11 is a placeholder; export from live state)
  identity/        Agent identity: agent_brand_scope, fn_brand_access_filter
                   v1.1.0, swimusa_agents grants
  semantic/        The four certified metric views (canonical YAML lives in
                   these CREATE VIEW scripts)
  ownership/       productops_semantic ownership transfer to brm_semantic_stewards
docs/              Implementation guide (as-built) and the agent edit policy
golden_queries/    Phase 6 golden query set (placeholder until task 6.1)
databricks.yml     Asset bundle: deploy job running the semantic scripts in order
```

## The five standing rules

1. **Metric views source `gold_v_*` views, never Gold tables.** The RLS lives inside the view SQL; tables are unfiltered for the pipeline.
2. **Never materialize an RLS-dependent metric view.** Materialization freezes one identity's row visibility and serves it to everyone.
3. **No semicolons inside `$$` YAML blocks.** The SQL editor splits statements on every semicolon, dollar-quoted or not.
4. **All `user_person_map` inserts use explicit column lists.** The live table has 11 columns; the handover doc's 10-column order is stale.
5. **Koantek `CREATE OR REPLACE VIEW` deploys wipe view comments and view tags.** After any BRM MVP redeploy, re-run `sql/gold_metadata/brm_12` through `brm_15` and `brm_13_tags`, then verify via `information_schema`.

## Change management

PR review classes per the Phase 8 rubric in `docs/BRM_Semantic_Layer_Implementation_Guide.md`: measure logic, filters, grain, source, RLS, or grants are high risk (metric owner + steward, full eval before merge); new measures or dimensions are medium (steward, owner notified); synonyms, comments, display names are low (steward). Version metric view YAML with the `semver` tag on the deployed view and match it to a Git tag.

## Deploying

`databricks bundle validate` on every PR (CI stub in `.github/workflows`). `databricks bundle deploy -t dev` deploys the runner job; run it to (re)apply the semantic scripts in numbered order against the SQL warehouse. Statements are idempotent by construction (`CREATE OR REPLACE`, `IF NOT EXISTS`, re-runnable COMMENT/TAG/GRANT statements) EXCEPT `sql/identity/brm_21` (function replacement plus inserts; follow its embedded runbook, never run it blind) and `sql/ownership/brm_34` (one-time transfer).

## Baselines (2026-09-21, admin identity)

Brands 144 all / 57 active / 87 dropped. Assignments 1204 (256 Lead, 948 Contributor) across 56 brands, 161 assigned people. People 226 (roster-based rule). Customers: 56 links, 18 distinct retail accounts. Known caveat: brand figures include App 2 UAT pollution pending the SWIM-1050 reverts (real active division count 9, reads 13).

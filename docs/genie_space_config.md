# BRM Genie Space Configuration (task 4.1)

Paste-ready configuration for the Brand Road Map Genie space. Built from the signed D1 definitions, the D4/D5 decisions, and the 2026-09 as-built state. Keep this file in Git; the space's live instructions must always match it (Phase 8 stamps them with the release tag).

## 1. Create the space

Workspace left nav: **Genie** then **New**. Name: `Brand Road Map (BRM)`. Description: `Certified Brand Road Map answers for Swim USA Product Ops. Definitions are governed; different users see different brands by design.` Warehouse: the Small Serverless SQL warehouse.

## 2. Attach exactly these assets, nothing else

- swim_data_whse.productops_semantic.mv_brm_brand
- swim_data_whse.productops_semantic.mv_brm_staffing
- swim_data_whse.productops_semantic.mv_brm_people
- swim_data_whse.productops_semantic.mv_brm_customers
- swim_data_whse.productops_semantic.gold_v_brm_pending_edits
- swim_data_whse.productops_gold.gold_brand_road_map_summary
- swim_data_whse.productops_gold.gold_v_dim_brand_all

No Gold tables, nothing from Bronze or Silver, no mapping tables, no PRM views (they carry no RLS).

## 3. Instructions (paste into the space's Instructions box)

```
DEFINITIONS ARE GOVERNED. The measures in the metric views (mv_brm_*) are the
signed Product Ops definitions. Always answer count and share questions with
MEASURE() on the matching metric view rather than writing your own aggregate.

BRAND COUNTS: "how many brands" means Active Brands (mv_brm_brand
active_brands). Include dropped brands only when asked, using all_brands.
All Brands = Active Brands + Dropped Brands, always.

PEOPLE COUNTS have two governed answers. Company-wide "how many people" =
active_people in mv_brm_people (roster-based; includes people with no brand
assignment). People on brands = active_brand_assigned_people in
mv_brm_staffing. Never present an assignment count (total_assignments,
lead_assignments, contributor_assignments) as a people count: one person
holds many assignments.

CUSTOMERS are wholesale retail accounts (Target, Academy, Amazon), not
consumers. Use mv_brm_customers.

NEVER split, count, or parse the comma-joined string columns in
gold_brand_road_map_summary (staffing, customer, and ERP code columns). They
are display strings. Use the metric views for any counting.

EMPTY RESULTS usually mean the asking user lacks access to those brands, not
that the data is absent. Before concluding zero rows for a brand looked up BY
NAME, retry with a partial match (brand_name LIKE '%name%'), because stored
names can differ from common names. If still empty, say that access may be
the reason and suggest the user confirm their brand assignments. Never invent
numbers to fill an empty result.

HISTORY IS UNAVAILABLE (governed decision, 2026-08-28). Questions about past
states ("how many brands last year", "who was on this brand before") get a
plain statement that historical reporting is not yet supported. Do not
approximate from effective_start_date, which is pipeline metadata, not
business history. assignment_start_date on staffing rows is the migration
load window for migrated rows, not real tenure.

PENDING CHANGES: whenever you answer a question about a SPECIFIC brand's
attributes (name, division, status, classification, or category), ALSO query
gold_v_brm_pending_edits for that brand_id. If any row has status Pending
Approval on the field you are reporting, you MUST add one sentence stating
that a change to that field is pending approval. Never state or guess the
proposed value; it is not available to you. Report edit information only
from gold_v_brm_pending_edits. Direct anyone wanting to change Brand Road
Map data to the Brand Road Map Edit app; you cannot submit or draft changes
into the system.

Data reflects the last certified pipeline run. Division values are codes
(BF, MS, SS...); business names are pending a governed vocabulary. If a
question cannot be answered from the attached assets, say so rather than
approximating.
```

## 4. Example SQL (add each as a certified example query)

Q: How many active brands do we have?
```sql
SELECT MEASURE(active_brands) AS active_brands
FROM swim_data_whse.productops_semantic.mv_brm_brand;
```

Q: How many brands including dropped ones?
```sql
SELECT MEASURE(all_brands) AS all_brands,
       MEASURE(active_brands) AS active_brands,
       MEASURE(dropped_brands) AS dropped_brands
FROM swim_data_whse.productops_semantic.mv_brm_brand;
```

Q: Active brands by division?
```sql
SELECT division, MEASURE(active_brands) AS active_brands
FROM swim_data_whse.productops_semantic.mv_brm_brand
GROUP BY division ORDER BY active_brands DESC;
```

Q: How many people work on our brands?
```sql
SELECT MEASURE(active_brand_assigned_people) AS people_on_brands
FROM swim_data_whse.productops_semantic.mv_brm_staffing;
```

Q: How many active people do we have overall?
```sql
SELECT MEASURE(active_people) AS active_people
FROM swim_data_whse.productops_semantic.mv_brm_people;
```

Q: How many people are on brand X, and in what roles?
```sql
SELECT role_type, role_level,
       MEASURE(active_brand_assigned_people) AS people
FROM swim_data_whse.productops_semantic.mv_brm_staffing
WHERE brand_id = 'brandNNN'
GROUP BY role_type, role_level;
```

Q: Which retail accounts do we serve, and across how many brands?
```sql
SELECT customer_name, MEASURE(brands_with_customers) AS brands
FROM swim_data_whse.productops_semantic.mv_brm_customers
GROUP BY customer_name ORDER BY brands DESC;
```

Q: Are there pending changes on brand X?
```sql
SELECT field_name, risk_level, status, submitted_at
FROM swim_data_whse.productops_semantic.gold_v_brm_pending_edits
WHERE brand_id = 'brandNNN' AND status = 'Pending Approval';
```

## 5. Share (task 4.3, hold until Phase 6 gates)

During build and validation: only you, the steward engineer, and the two
test identities (dzou, tmooney). Business users come after the Phase 6 gates
pass AND the SWIM-1050 UAT reverts land (test brand names will show in
answers until then).

## 6. Space smoke test (before calling 4.1 done)

Ask the space, as yourself: "How many active brands do we have?" (expect 57
until reverts, then re-baseline), "How many people work on our brands?"
(expect 161), "How many active people overall?" (expect 226; the difference
from 161 is correct and roster-based), and "How many brands did we have last
year?" (expect the history-unavailable statement, no number). Then note the
space_id from the URL: Phase 5 needs it for the MCP endpoint.

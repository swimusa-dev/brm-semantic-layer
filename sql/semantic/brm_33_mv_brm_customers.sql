-- =====================================================================
-- Task 3.2 (part 2 of 2): mv_brm_customers metric view
-- BRM Semantic Layer Implementation | 2026-09-21
--
-- Source: gold_v_bridge_brand_customer_active (8 cols verified
-- 2026-09-21; 56 rows, 56 distinct brands, exactly one customer per
-- brand today, schema permits many-to-many later). RLS inherited from
-- the source view. NEVER materialize.
--
-- EDITOR RULE: no semicolons inside the $$ YAML block.
-- 3 numbered statements + verification.
-- =====================================================================

-- [1/3] Customer metric view
CREATE OR REPLACE VIEW swim_data_whse.productops_semantic.mv_brm_customers
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1

source: swim_data_whse.productops_gold.gold_v_bridge_brand_customer_active

comment: >
  Certified BRM brand-to-customer metrics, v1. Grain of the source is
  one row per current link between an ACTIVE brand and a retail
  customer account (56 at 2026-09 baseline, admin view, currently
  exactly one customer per brand though the model permits several).
  Row-level security is inherited from the source view, so different
  users see different totals by design. Customer names are retail
  ACCOUNTS (Academy, Target, Amazon, Walmart and similar), not
  consumers. Ask measures with MEASURE() and do not aggregate
  dimensions directly.

dimensions:
  - name: brand_id
    expr: brand_id
    display_name: Brand ID
    comment: FK to mv_brm_brand.brand_id and gold_v_dim_brand_active.

  - name: customer_id
    expr: customer_id
    display_name: Customer ID
    comment: Persistent customer surrogate key (cust001 and up).

  - name: customer_name
    expr: customer_name
    display_name: Customer Name
    synonyms:
      - retail account
      - retailer
      - account name
    comment: >
      Retail customer account display name (Academy, Target, Amazon,
      Walmart, Kohl's, National and similar). A wholesale account, not
      an end consumer.

measures:
  - name: brand_customer_links
    expr: COUNT(1)
    display_name: Brand-Customer Links
    comment: >
      Current links between active brands and customer accounts (56 at
      2026-09 baseline, admin view). Not a brand count and not a
      customer count, though today each brand carries exactly one link.

  - name: brands_with_customers
    expr: COUNT(DISTINCT brand_id)
    display_name: Brands With Customers
    synonyms:
      - brands linked to accounts
    comment: >
      Distinct active brands linked to at least one customer account
      (56 at 2026-09 baseline against 57 active brands).

  - name: distinct_customers
    expr: COUNT(DISTINCT customer_id)
    display_name: Distinct Customers
    synonyms:
      - customer count
      - number of retail accounts
      - how many customers
    comment: >
      Distinct retail customer accounts linked to at least one active
      brand within the rows the asking user can see. One account
      typically spans several brands, so this is smaller than
      Brand-Customer Links.
$$;

-- [2/3] Tag
ALTER VIEW swim_data_whse.productops_semantic.mv_brm_customers
  SET TAGS ('certified' = 'true', 'domain' = 'brm', 'semver' = '1.0.0');

-- [3/3] Agent grant
GRANT SELECT ON VIEW swim_data_whse.productops_semantic.mv_brm_customers TO `swimusa_agents`;

-- ===================== VERIFICATION =====================

-- [V1] Baseline (expect links=56, brands=56, customers = the real
--      distinct account count, first reading of it)
SELECT
  MEASURE(brand_customer_links)  AS brand_customer_links,
  MEASURE(brands_with_customers) AS brands_with_customers,
  MEASURE(distinct_customers)    AS distinct_customers
FROM swim_data_whse.productops_semantic.mv_brm_customers;

-- [V2] Brands per customer account (top accounts)
SELECT customer_name, MEASURE(brands_with_customers) AS brands
FROM swim_data_whse.productops_semantic.mv_brm_customers
GROUP BY customer_name ORDER BY brands DESC;

-- [V3] The one active brand with NO customer link (expecting brand073)
SELECT d.brand_id, d.brand_name, d.division
FROM swim_data_whse.productops_gold.gold_v_dim_brand_active d
WHERE NOT EXISTS (
  SELECT 1 FROM swim_data_whse.productops_gold.gold_v_bridge_brand_customer_active c
  WHERE c.brand_id = d.brand_id
);

-- [V4] Tags and grant landed
SELECT table_name, tag_name, tag_value
FROM swim_data_whse.information_schema.table_tags
WHERE schema_name = 'productops_semantic' AND table_name = 'mv_brm_customers';

-- [V5]
SELECT grantee, privilege_type
FROM swim_data_whse.information_schema.table_privileges
WHERE table_schema = 'productops_semantic'
  AND table_name = 'mv_brm_customers'
  AND grantee = 'swimusa_agents';

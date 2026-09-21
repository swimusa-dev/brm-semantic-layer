-- =====================================================================
-- brm_11 placeholder: PK/FK constraints (task 1.1, executed 2026-09-02)
--
-- The constraints were applied interactively and the final working
-- script was not kept as a file. The LIVE STATE is authoritative:
-- 3 single-column PRIMARY KEYs + 6 FOREIGN KEYs, all NORELY, plus
-- SET NOT NULL on the key columns (RELY was deliberately rejected:
-- it licenses the optimizer to drop deduplication, the exact SCD2
-- double-count risk this layer guards against).
--
-- TO COMPLETE THIS FILE: run the export below against the warehouse,
-- reconstruct the ALTER TABLE statements from its output, replace this
-- placeholder, and commit. Until then, this file documents the gap.
-- =====================================================================

SELECT tc.constraint_name,
       tc.constraint_type,
       tc.table_name,
       kcu.column_name,
       kcu.ordinal_position
FROM swim_data_whse.information_schema.table_constraints tc
JOIN swim_data_whse.information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.table_schema   = kcu.table_schema
WHERE tc.table_schema = 'productops_gold'
ORDER BY tc.table_name, tc.constraint_type DESC, kcu.ordinal_position;

-- FK parent/child pairs:
SELECT rc.constraint_name,
       kcu_child.table_name  AS child_table,
       kcu_child.column_name AS child_column,
       kcu_parent.table_name AS parent_table,
       kcu_parent.column_name AS parent_column
FROM swim_data_whse.information_schema.referential_constraints rc
JOIN swim_data_whse.information_schema.key_column_usage kcu_child
  ON rc.constraint_name = kcu_child.constraint_name
JOIN swim_data_whse.information_schema.key_column_usage kcu_parent
  ON rc.unique_constraint_name = kcu_parent.constraint_name
WHERE rc.constraint_schema = 'productops_gold';

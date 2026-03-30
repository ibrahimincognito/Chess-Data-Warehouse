{{ config(materialized='view') }}

SELECT * FROM workspace.dbt_analytics.stg_blitz
UNION ALL
SELECT * FROM workspace.dbt_analytics.stg_rapid
UNION ALL
SELECT * FROM workspace.dbt_analytics.stg_bullet
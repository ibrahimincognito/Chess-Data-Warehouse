{{ config(materialized='view') }}

SELECT
  username,
  MIN(snapshot_date) AS first_seen,
  MAX(snapshot_date) AS last_seen,
  COUNT(DISTINCT snapshot_date) AS days_tracked
FROM {{ ref('fact_leaderboard') }}
GROUP BY username
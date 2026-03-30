# Lichess Data Warehouse: Automated ELT with Databricks, dbt, and AWS

![Architecture](architecture/pipeline-diagram.png)

## 📊 Project Overview

A production‑grade, serverless data pipeline that tracks daily rating movements of top Lichess chess players. The pipeline ingests raw JSON data from an AWS S3 data lake, builds a star‑schema warehouse on Databricks using dbt, and automates transformations, testing, and documentation. All resources run within free tiers, making it a zero‑cost, fully functional portfolio project.

**Key Features:**
- **Serverless & Cost‑Effective** – AWS Lambda, Databricks Free Edition, dbt Cloud Developer plan.
- **ELT on a Data Lake** – Raw JSON stored in S3, transformed in Databricks using SQL and dbt.
- **Dynamic Data Access** – Databricks views read directly from S3, so new files are automatically included.
- **Infrastructure as Code** – All database objects (tables, views, tests) defined in dbt models.
- **Data Quality** – Automated tests (`not_null`, `unique`, `accepted_values`) ensure reliability.
- **Documentation** – Auto‑generated lineage graph and model documentation with `dbt docs`.
- **CI/CD** – Scheduled dbt Cloud jobs run daily, keeping the warehouse up‑to‑date.

---

## 🏗️ Architecture

![Architecture Diagram](architecture/pipeline-diagram.png)

1. **AWS Lambda** (Project 1) fetches the top 100 players (blitz, rapid, bullet) daily and stores raw JSON in S3 at `s3://lichess-raw-data-ibrahim/raw/leaderboard/YYYY-MM-DD/{mode}.json`.
2. **Databricks External Location** securely connects to S3, enabling direct file access.
3. **Dynamic Databricks Views** (`workspace.default.raw_blitz`, etc.) use `read_files` to parse the JSON arrays, flatten them into rows, and extract snapshot dates – always reflecting the latest files.
4. **dbt** transforms the views into a star schema:
   - **Staging models** (`stg_blitz`, `stg_rapid`, `stg_bullet`) – lightweight selections from the views.
   - **Fact table** (`fact_leaderboard`) – union of all three modes.
   - **Dimension table** (`dim_player`) – player metadata (first seen, last seen, days tracked).
5. **dbt tests** validate data quality on the final models.
6. **dbt documentation** provides a lineage graph and detailed model descriptions.
7. **Scheduled dbt Cloud job** runs `dbt run` and `dbt test` daily at 00:30 UTC, ensuring the warehouse is always fresh.

---

## 🛠️ Technologies Used

| Tool | Purpose |
|------|---------|
| **AWS S3** | Raw data lake – immutable storage for JSON files |
| **AWS Lambda** | Daily ingestion of Lichess API (Project 1) |
| **Databricks** | Lakehouse platform – dynamic views, SQL execution, catalog |
| **dbt (data build tool)** | Transformation, testing, documentation |
| **dbt Cloud** | CI/CD, job scheduling |
| **Python** | Local dbt Core for documentation generation |
| **Git & GitHub** | Version control, project hosting |

---

## 📦 Dataset

## 📦 Dataset

- **Source:** Raw JSON files are produced by a separate daily ingestion pipeline ([Lichess Rating Tracker](https://github.com/your-username/lichess-rating-tracker)), which fetches top 100 players (blitz, rapid, bullet) from the Lichess API and stores them in S3.
- **Data range:** 2026‑02‑08 to 2026‑02‑20 (13 days).
- **Raw files:** 13 JSON files per mode, each containing 100 player objects.
- **Dynamic views:** Each Databricks view reads all files for its mode, providing 1300 rows (13 × 100).
- **Fact table:** Union of the three views → 3900 rows.
- **Dimension table:** 313 unique players with first/last seen dates and days tracked.

---

## 🔄 Pipeline Steps

### 1. Ingestion (AWS Lambda)
- Daily fetch of top 100 players per mode.
- Raw JSON stored in S3 with partitioning by date and mode.

### 2. Dynamic Databricks Views
- **`workspace.default.raw_blitz`**, **`raw_rapid`**, **`raw_bullet`** created using `read_files` and `explode`.
- These views are **live** – they always reflect the latest files in S3.
- They extract `username`, infer `rank` from array position, and extract `snapshot_date` from the file path.

### 3. dbt Models

**Staging Models** (`models/staging/`):
```sql
-- stg_blitz.sql
{{ config(materialized='table') }}
SELECT * FROM workspace.default.raw_blitz
```

*(Identical for `stg_rapid` and `stg_bullet`.)*

#### Mart Models (`models/marts/`)

**fact_leaderboard.sql – union of all three staging tables:**

```sql
{{ config(materialized='view') }}
SELECT * FROM {{ ref('stg_blitz') }}
UNION ALL
SELECT * FROM {{ ref('stg_rapid') }}
UNION ALL
SELECT * FROM {{ ref('stg_bullet') }}
```

**dim_player.sql – aggregates player metadata:**

```sql
{{ config(materialized='view') }}
SELECT
  username,
  MIN(snapshot_date) AS first_seen,
  MAX(snapshot_date) AS last_seen,
  COUNT(DISTINCT snapshot_date) AS days_tracked
FROM {{ ref('fact_leaderboard') }}
GROUP BY username
```

### 4. Data Quality Tests

**Defined in `models/marts/schema.yml`:**
- `not_null` on all key columns.
- `unique` on `dim_player.username`.
- `accepted_values` on `performance` *(blitz, rapid, bullet)*.

### 5. Documentation
1. Download a ZIP archive of your managed repository to export your dbt project.
2. In the folder which contains the `dbt_project.yml` file — run `pip install dbt-core dbt-databricks`
3. Run `dbt docs generate`
4. Then finally, run `dbt docs serve`

**The generated documentation includes a lineage graph, column descriptions, and test results.**

### 6. Daily Automation
- A scheduled dbt Cloud job runs `dbt run` and `dbt test` every day at 00:30 UTC.
- New files from the daily Lambda are automatically picked up by the Databricks views, so the dbt run refreshes the warehouse with the latest data.

## How to Reproduce

## Prerequisites
- AWS account with S3 bucket containing the Lichess JSON files.
- Databricks workspace (Free Edition).
- dbt Cloud account (Developer tier).

## Steps
1. Set up Databricks External Location pointing to your S3 bucket (see documentation in repo).
2. Create the dynamic views in Databricks using the SQL scripts in the `databricks/` folder (or run the provided queries).
3. Clone this repository and copy `profiles.yml.example` to `profiles.yml` (fill in your Databricks credentials).
4. Install dbt Core (optional) for local documentation generation:

```bash
pip install dbt-core dbt-databricks
Run dbt to build the warehouse:
```
5. Run dbt to build the warehouse:
```bash
dbt deps   # if you have packages
dbt run
dbt test
dbt docs generate
dbt docs serve
```
6. Create a scheduled dbt Cloud job to run dbt run and dbt test daily.

## Analytical Queries Example:

### Top 10 Rating Gainer (Day-over-Day): Identify which players gained the most rating from one day to the next.

```sql
WITH yesterday AS (
  SELECT username, rating
  FROM fact_leaderboard
  WHERE performance = 'blitz' AND snapshot_date = '2026-02-19'
),
today AS (
  SELECT username, rating
  FROM fact_leaderboard
  WHERE performance = 'blitz' AND snapshot_date = '2026-02-20'
)
SELECT t.username, t.rating - y.rating AS gain
FROM today t
JOIN yesterday y ON t.username = y.username
WHERE t.rating - y.rating > 0
ORDER BY gain DESC
LIMIT 10;
```

## Cost Analysis:
## 💰 Cost Analysis

All services used are within free tiers:

| Service        | Usage                      | Free Tier Limit | Estimated Cost |
|----------------|---------------------------|-----------------|----------------|
| AWS S3         | ~10 MB storage            | 5 GB            | $0             |
| AWS Lambda     | 30 invocations/month      | 1M requests     | $0             |
| Databricks     | 1 small SQL warehouse     | Free Edition    | $0             |
| dbt Cloud      | 1 developer, managed repo | Developer tier  | $0             |

**Total monthly cost: $0.**

## Lessons Learned & Future Improvements
- **Dynamic views** over static tables ensure the warehouse always uses the latest S3 data – a common pattern in data lakes.

- **dbt incremental materialization** could be used instead of full refreshes to reduce compute cost for large datasets.

- **CI/CD can be extended:** run tests on every pull request using GitHub Actions.

#### Potential Enhancements:

- Add player profile enrichment (title, country, total games) from the Lichess user API.
- Build a BI dashboard (Power BI, Tableau) on top of the star schema.
- Replace the Databricks views with external tables and partition by date for even better query performance.
- Trigger the dbt Cloud job directly from the S3 upload event (via Databricks API) for near‑real‑time updates.

## Acknowledgements
- Lichess API for provide free, open chess data.
- dbt Labs for an incredible transformation tool.
- Databricks for the free learning edition.



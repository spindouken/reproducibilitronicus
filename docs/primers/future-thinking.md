# Future Thinking — What Comes After This Project

## The patterns this project establishes

This learning project implements a specific architecture:

```
CSV → Parquet → DuckDB/Arrow → targets → Quarto → GitHub Pages
         └── GCS (persistence)
         └── WIF (auth)
         └── Tofu (infrastructure)
```

Each piece was chosen to be the simplest viable option. Here's where each
one leads if you keep going.

## Scaling the pipeline

### From `targets` to Airflow/Prefect

`targets` is excellent for single-machine R pipelines. When you need:
- Multiple languages (R + Python + SQL)
- Distributed execution across machines
- Scheduling (run every night at 2am)
- Alerting (notify Slack when a step fails)

...you graduate to Airflow, Prefect, or Dagster. The mental model is the
same (DAG of dependent steps), but the infrastructure is heavier.

### From DuckDB to a persistent warehouse

DuckDB in this project is ephemeral — it spins up, queries, shuts down.
If you need:
- Persistent tables across sessions
- Multi-user concurrent access
- SQL-based BI tools connecting directly

...you'd move to BigQuery (GCP), Snowflake, or a persistent DuckDB database.
The SQL skills transfer directly.

## Scaling the storage

### From flat parquet to Iceberg/Delta Lake

Currently: parquet files in GCS, no transaction log.

Next level: Apache Iceberg or Delta Lake adds:
- Schema evolution (add columns without breaking readers)
- Time travel (query yesterday's version of the data)
- ACID transactions (safe concurrent writes)
- Partition management (automatic file organization)

### From GCS to a lakehouse

A "lakehouse" is cloud storage (GCS/S3) + a metadata layer (Iceberg/Delta) +
a query engine (DuckDB/Trino/Spark). It combines the flexibility of a data
lake with the reliability of a warehouse.

This project is already halfway there: GCS + parquet + DuckDB queries.
Adding Iceberg metadata would make it a proper lakehouse.

## Scaling the deployment

### From GitHub Pages to Cloud Run

GitHub Pages is static — it serves pre-built HTML. If you need:
- Server-side R code (Shiny, Plumber APIs)
- Dynamic content
- Authentication

...you'd deploy to Cloud Run (GCP), which runs containers on demand.
The Dockerfile from Phase 4 is already Cloud Run-ready.

### From single project to multi-project

The `tofu-modules` `environment-factory` pattern could scaffold multiple
environments (dev/staging/prod) for analytics projects. Each environment
gets its own:
- GCS buckets (data isolation)
- Service account (permission isolation)
- WIF binding (auth isolation)
- Quarto site (separate URLs for draft vs. production)

## The one-command dream

Imagine:

```bash
# Scaffold a new analytics project
ojo_new_project("housing-analysis")

# This runs:
# 1. Creates a new GitHub repo from template
# 2. tofu apply → creates GCS buckets, SA, WIF
# 3. Sets GitHub repository variables
# 4. Seeds the repo with Quarto template, _targets.R, R/ skeleton
# 5. First commit triggers CI → empty site deploys
```

The pieces exist today across the reference projects:
- `tofu-modules/project-factory` creates GCP projects
- `tofu-modules/environment-factory` creates per-env resources
- `actions` repo provides reusable CI workflows
- `okpolicy-website-template` provides the Quarto foundation

The orchestration layer that ties them together — that's the next thing to build.

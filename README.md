# R Analytics Platform — Learning Project

A personal learning project exploring modern R-based data engineering patterns.
Built as an educational field notebook, not a production system.

## What this is

An integrated project combining lessons from several internal reference
projects into a single, documented learning environment:

- **Pipeline orchestration** with `targets`
- **Modern data formats** — Parquet queried with Arrow and DuckDB
- **Reproducible environments** — `renv` + optional Docker
- **Automated publishing** — Quarto website via GitHub Actions → GitHub Pages
- **Cloud storage** — GCS-backed artifact persistence with WIF authentication
- **Infrastructure as Code** — OpenTofu for GCP resource management

## Quick start

```r
# Load project functions
devtools::load_all()

# Check status
check_status()

# Run the pipeline
run_pipeline()

# Preview the website
deploy_local(profile = "drafts")
```

## Project structure

```
├── .github/workflows/     ← CI/CD: pipeline, deploy, Tofu
├── _extensions/            ← Quarto format extension (okpolicy branding)
├── config/                 ← base.yaml + environment overlays
├── data/
│   ├── raw/               ← Source CSV (committed)
│   └── parquet/           ← Pipeline outputs (gitignored)
├── docker/                ← Optional Dockerfile
├── docs/
│   ├── primers/           ← Concept explainers (10 topics)
│   ├── guides/            ← How-to guides (6 guides)
│   └── JOURNEY.md         ← Build log with decisions + learning
├── infra/tofu/            ← GCP infrastructure (buckets, SA, WIF)
├── R/
│   ├── config.R           ← Config loader
│   ├── data.R             ← Data functions (CSV, parquet, Arrow, DuckDB)
│   ├── analysis.R         ← Summary functions for reports
│   └── helpers.R          ← Orchestration helpers
├── reports/
│   ├── eviction-trends/   ← Year-over-year analysis
│   └── geographic-patterns/ ← Spatial density analysis
├── tests/testthat/        ← Unit tests
├── _targets.R             ← Pipeline definition
├── _quarto.yml            ← Website config (+ drafts/public profiles)
├── DESCRIPTION            ← R package manifest
└── index.qmd              ← Site landing page
```

## Pipeline flow

```
data/raw/*.csv
    ↓ load_eviction_data()
R tibble
    ↓ convert_csv_to_parquet()
data/parquet/evictions.parquet
    ├─→ Arrow queries (read_parquet_evictions)
    ├─→ DuckDB SQL (query_evictions_duckdb)
    └─→ dplyr summaries (summarize_annual, summarize_geocoding)
           ↓
    data/parquet/*_summary.parquet
           ↓
    Quarto reports (HTML)
```

## Documentation

### Primers (concept explainers)

| Topic | What it covers |
|---|---|
| [Quarto Profiles](docs/primers/quarto-profiles.md) | Draft/public rendering, extensions |
| [Package Structure](docs/primers/package-structure.md) | Why R packages for analysis |
| [renv](docs/primers/renv.md) | Reproducible R environments |
| [Testing](docs/primers/testing.md) | testthat for analysis projects |
| [targets](docs/primers/targets.md) | Pipeline orchestration, DAGs, caching |
| [Parquet](docs/primers/parquet.md) | Columnar storage format |
| [Arrow & DuckDB](docs/primers/arrow-duckdb.md) | Roles, overlap, interop |
| [Dependency Graphs](docs/primers/dependency-graphs.md) | DAGs and hash-based caching |
| [Docker](docs/primers/docker.md) | Containers for R projects |
| [Caching](docs/primers/caching.md) | Multi-layer caching strategy |
| [WIF](docs/primers/wif.md) | Workload Identity Federation |
| [GCS](docs/primers/gcs.md) | Cloud storage for artifacts |
| [CI/CD](docs/primers/cicd.md) | Automated pipeline + deployment |
| [Metadata](docs/primers/metadata.md) | Metadata, lineage, data catalogs |
| [Future Thinking](docs/primers/future-thinking.md) | Where this architecture leads |

### Guides (how-to)

| Guide | What it covers |
|---|---|
| [Adding Reports](docs/guides/adding-reports.md) | Create a new report page |
| [Pipeline to Website](docs/guides/pipeline-to-website.md) | How reports consume pipeline outputs |
| [Running Locally](docs/guides/running-locally.md) | Local development workflow |
| [GCP Setup](docs/guides/gcp-setup.md) | Infrastructure provisioning |
| [GitHub Config](docs/guides/github-config.md) | Repository settings |
| [Orchestration Vision](docs/guides/orchestration-vision.md) | One-command project rollout |

### Journey Log

[docs/JOURNEY.md](docs/JOURNEY.md) — a living document capturing decisions,
alternatives considered, and learning moments from each build phase.

## Tools used

**R:** targets, tarchetypes, arrow, duckdb, dplyr, renv, testthat, pointblank  
**Group packages:** ojothemes (ggplot2/gt themes), ojoutils (GCS helpers)  
**Publishing:** Quarto, GitHub Pages  
**Infrastructure:** OpenTofu, GCS, WIF, GitHub Actions  
**Optional:** Docker (Rocker 4.4.2)

## Data

Tulsa County granted eviction records (2021–2025), ~27K rows with geocoded
coordinates. Sourced from the `targets` reference project's exported data.

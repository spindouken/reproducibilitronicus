# Orchestration Vision — One-Command Project Rollout

## The dream

A single command provisions infrastructure, configures CI/CD, scaffolds
project files, and deploys an initial site:

```bash
ojo_new_project("housing-analysis", type = "analytics")
```

This document explores what that would look like, what exists today, and
what would need to be built.

## What happens under the hood

### Step 1: Create GitHub repository from template

```bash
gh repo create openjusticeok/housing-analysis \
  --template openjusticeok/r-analytics-template \
  --public
```

The template repo contains:
- Quarto website skeleton (from `okpolicy-website-template`)
- `_targets.R` boilerplate
- R package structure (`DESCRIPTION`, `R/`, `tests/`)
- GitHub Actions workflows (pre-configured)
- Tofu infrastructure directory

### Step 2: Provision GCP infrastructure

```bash
cd infra/tofu/
tofu init -backend-config="bucket=housing-analysis-tofu-state"
tofu apply -auto-approve \
  -var="project_name=housing-analysis" \
  -var="github_repository=openjusticeok/housing-analysis"
```

This creates:
- GCS data bucket
- GCS targets bucket
- GCS state bucket (pre-created)
- Service account with appropriate roles
- WIF IAM binding to the existing pool

### Step 3: Configure GitHub repository

```bash
gh variable set GCP_PROJECT_ID --body "my-gcp-project"
gh variable set GCP_WIF_PROVIDER --body "projects/123/locations/global/..."
gh variable set GCP_SERVICE_ACCOUNT --body "housing-analysis-pipeline@...iam..."
gh variable set GCS_DATA_BUCKET --body "housing-analysis-data"
gh variable set GCS_TARGETS_BUCKET --body "housing-analysis-targets"
gh variable set GCP_STATE_BUCKET --body "housing-analysis-tofu-state"
```

### Step 4: Initial deployment

```bash
git push origin main
# GitHub Actions takes over:
# → pipeline runs (empty, no data yet)
# → site renders (skeleton pages)
# → deploys to GitHub Pages
```

## What exists today

| Component | Status | Where |
|---|---|---|
| Quarto template | ✅ Ready | `okpolicy-website-template` |
| Tofu modules | ✅ Ready | `tofu-modules/project-factory`, `environment-factory` |
| Reusable workflows | ✅ Ready | `actions` repo |
| WIF pool | ✅ Ready | `openjusticeok/infrastructure` |
| Orchestration layer | ❌ Not built | Needs an R package or CLI tool |

## What would need to be built

### An R package: `ojoscaffold` (or similar)

```r
# R functions that wrap the CLI steps above:
ojoscaffold::new_project(
  name = "housing-analysis",
  type = "analytics",           # vs "report-only", "dashboard"
  org = "openjusticeok",
  gcp_project = "my-project"
)
```

### A `justfile` or `Makefile` for common operations

```makefile
# justfile for the project
pipeline:
    Rscript -e "targets::tar_make()"

preview:
    quarto preview --profile drafts

deploy:
    quarto render --profile public

status:
    Rscript -e "targets::tar_outdated()"

infra-plan:
    cd infra/tofu && tofu plan

infra-apply:
    cd infra/tofu && tofu apply
```

### Helper functions in the project itself

These already exist in `R/helpers.R`:

| Function | What it does |
|---|---|
| `run_pipeline()` | `targets::tar_make()` with status reporting |
| `deploy_local()` | `quarto preview/render` with profile selection |
| `check_status()` | Reports pipeline state, data existence, config |
| `save_dependency_graph()` | Exports the targets DAG as HTML |

### Future helpers to consider

| Function | What it would do |
|---|---|
| `setup_gcs()` | Authenticate to GCS and verify bucket access |
| `push_artifacts()` | Upload parquet files to GCS data bucket |
| `pull_artifacts()` | Download latest artifacts from GCS |
| `validate_data()` | Run pointblank checks on pipeline outputs |
| `scaffold_report()` | Create a new report directory with template QMD |

## Why this matters

The gap between "I have all the pieces" and "I can spin up a new project
in 5 minutes" is the orchestration layer. The reference projects have
every component needed. The missing piece is the glue that connects them
into a single, repeatable workflow.

Building that glue is the natural next project after this learning one.

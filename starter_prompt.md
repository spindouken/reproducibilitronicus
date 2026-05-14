# R Analytics Platform — Learning Project

## What This Is

This is a personal, educational R project. The primary goal is learning: understanding
modern R-based data engineering patterns, metadata-driven workflows, reproducibility
concepts, and the tools and infrastructure that underpin them. It is not a production
system. It is not an enterprise template. It should be lean, readable, and annotated
like a field notebook.

The project deliberately combines several existing internal projects and references into
a single, integrated, well-documented learning environment. Everything should have a
clear explanation of *why* it exists, not just *what* it does.

---

## Design Philosophy

- **Bare bones over engineered.** If it doesn't need to exist yet, it doesn't exist.
- **Education first.** Every major component should have a companion guide or inline
  explanation.
- **Local-first.** All compute runs locally or in GitHub Actions. No cloud compute.
- **Start from what exists.** The project begins with an already-initialized Quarto
  website template in projects\templates\okpolicy-website-template and grows outward.
- **Phased.** Each phase has clear scope and produces something usable before the next
  begins.
- **Living documentation.** The journey log and guides are written *during* the build,
  not after. Each phase explicitly updates them. They are never a final deliverable —
  they are a continuously evolving record of the project being understood.
- **Readable.** Code, configs, and docs should be navigable by a person returning to
  the project after a month away.

---

## Project Sources (Reference Only)

These existing projects are treated as references and learning materials, not as code to copy verbatim. But we should aim to use practices similar to those found in tofu-modules (tag system for development, staging, production, etc). These are all examples of past projects that have been completed in the group.

| Project | What to take from it |
|---|---|
| `targets` project | Orchestration patterns, pipeline reference, targets examples, source data |
| `templates` project | Already-initialized Quarto website (starting point), wrapper functions, Quarto profiles |
| `tcj` project | Terraform/OpenTofu + GCP connection patterns, targets + GCS integration |
| `BIG` project | GitHub Actions patterns, Docker (Rocker), earlier reporting approach |
| `tofu-modules` project | Tofu module structure, multi-environment tagging, Hub & Spoke WIF |
| `gcs-pull-example.R` | GCS data connection patterns in R, parquet conversion examples |
| `actions` project | Reusable GitHub Actions workflows (tofu-ci, tofu-gcp-plan-apply) |
| `themes` project | `ojothemes` R package — ggplot2 themes (`theme_okpi`) and gt tables (`gt_okpi`) |

---

## Scope Boundaries (What This Is NOT)

Do not build:
- Staging or production infrastructure separation
- Multi-cloud support
- Postgres or any relational database
- Workload Identity Federation (WIF is already set up — don't touch it)
- Spark, Kubernetes, Airflow, or distributed compute
- Advanced infrastructure modularity
- Enterprise metadata catalogs (DuckLake, Iceberg, Delta Lake — these are *discussed*
  in docs, not implemented)

---

## Pre-Build Decisions

These decisions were made after analyzing all reference projects against this prompt:

1. **Data source:** The `targets` project's ingestion layer calls `ojodb::ojo_eviction_cases()`
   — a database connection unavailable outside the group's infrastructure. The exported
   CSV files in `targets/data/output/` (~27K rows of Tulsa eviction data: `filing_year`,
   `lat`, `lon`, `geo_accuracy`) are treated as raw input. The pipeline starts from
   CSV → Parquet → DuckDB/Arrow → report.

2. **Quarto extension:** The `okpolicy-website-template` uses a custom Quarto format
   extension (`okpolicy-website-template-html`) with custom SCSS, a title-block partial,
   and the yeti base theme. This extension is carried forward into the new project as if
   running `quarto use template`. The extension system itself is documented as a
   learning point.

3. **Project location:** This project gets its own Git repository. It is developed
   inside this workspace but structured as a standalone repo from the start.

4. **Use `ojoutils` and `ojothemes`:** Where these group packages provide relevant
   helpers (GCS auth, ggplot2/gt theming), use them rather than reimplementing.
   Document what they provide and what you'd build yourself if they didn't exist.

---

## Runtime Environments

Two environments only:

**`local`** — development, rendering, pipeline execution, Docker
**`ci`** — GitHub Actions, automated rendering, deployment

---

## Build Phases

> **For every phase:** Before moving on, the agent must update `docs/JOURNEY.md` with
> what was built, what decisions were made, what alternatives were considered, and what
> was learned. Guides and primers should also be updated or created to reflect what was
> introduced in that phase. Documentation is not a final step — it is part of completing
> each phase.

---

### Phase 1 — Orient to the Quarto Foundation

**Goal:** Understand and verify the existing project. The Quarto website template is
already initialized — profiles, wrapper functions, and the basic site structure are
already in place. This phase is about orientation, not setup.

- Read through the existing template structure and understand what is already wired
- Verify that `draft` and `public` profiles render correctly
- Verify that the `public` profile deploys correctly to GitHub Pages
- Add a placeholder index page and at least one stub report page so the site has
  real content to deploy
- Review `_quarto.yml` and understand every key in it
- Set up `config/base.yaml` with minimal centralized config (paths, project name)
- Write or update the following docs:
  - A primer explaining Quarto profiles: what they are, how `draft` vs `public` differ,
    why this pattern matters for publishing workflows
  - A guide for adding new pages and reports to the site
  - First entry in `docs/JOURNEY.md`: why this template was chosen, what it provides
    out of the box, what you still need to build

**What you learn:** Quarto project structure, profile-based rendering, the template
system, GitHub Pages deployment.

---

### Phase 2 — R Package Structure + Reproducible Environment

**Goal:** Give the project a proper R package skeleton and lock down dependencies.

- Add `DESCRIPTION` file to make the project a proper R package
- Organize helper functions under `R/`
- Initialize `renv` and commit `renv.lock`
- Set up `testthat` with a few basic tests for helper functions
- Add `lintr` config
- Write or update the following docs:
  - Primer: why package structure matters even for analysis projects (not just for
    packages you publish)
  - Primer: what `renv` does, what `renv.lock` is, how reproducibility works in
    practice across machines
  - Primer: testing basics with `testthat` — what to test and what not to bother with
  - Update `docs/JOURNEY.md`: why these structural decisions were made, what renv
    replaces, what you'd do differently at larger scale

**What you learn:** R package conventions, dependency locking, renv workflow, testing
basics.

---

### Phase 3 — targets Pipeline + DuckDB/Arrow/Parquet

**Goal:** Build a minimal but real data pipeline, using the same source data from the
existing `targets` project so the reference implementation is directly comparable.

- Write a `_targets.R` pipeline with a real data flow using the `targets` project data:
  - Raw data ingestion → parquet output → DuckDB/Arrow query → summarized result →
    report input
- Store parquet files locally under `data/parquet/`
- Use Arrow for dataset abstraction and DuckDB for analytical queries — document the
  reasoning for each choice inline (see Arrow vs DuckDB section above)
- Use `dplyr` interface where natural; use raw SQL via DuckDB where it's clearer
- Generate and store the targets dependency graph under `docs/graphs/`
- Create at least two example **reports** as Quarto pages on the website. Reports are
  journalism about the data: they tell a story, surface a finding, or explain a pattern
  produced by the pipeline. They are not raw output dumps. Each report should:
  - Have a clear narrative angle (e.g. "What changed this month", "Where the
    outliers are")
  - Consume pipeline outputs directly (parquet files or summarized targets objects)
  - Use tables (`gt`) and charts (`ggplot2`) to support the narrative
  - Be written as if a reader who didn't build the pipeline will read it
- Write or update the following docs:
  - Primer: what `targets` is and why it exists — caching, reproducibility,
    orchestration. What problem it solves that plain scripts don't.
  - Primer: what parquet is and why it matters — typed, compressed, queryable,
    portable. What it replaces and why CSV isn't good enough.
  - Primer: Arrow and DuckDB — their roles, their overlap, when to use which (see
    Arrow vs DuckDB section above)
  - Primer: dependency graphs — what the targets DAG shows, how to read it, why
    knowing your dependency graph matters
  - Primer: metadata and hashing — what metadata targets stores, what a hash is in
    this context, why hash-based caching is powerful
  - Guide: how the Quarto website consumes pipeline outputs — how a report page reads
    from a parquet file or targets object, and why this connection matters
  - Update `docs/JOURNEY.md`: pipeline design decisions, why this data was reused,
    what the dependency graph revealed, anything surprising

**What you learn:** Pipeline orchestration, parquet/Arrow/DuckDB stack, dependency
graphs, caching by hash, how to connect a pipeline to a publishing layer.

---

### Phase 4 — GCS Cloud Storage + GitHub Actions CI

**Goal:** Push artifacts to the cloud and automate the pipeline in CI.

**On Docker:** Docker is included here not because it is strictly required, but because
it is the most reliable way to guarantee that the environment running locally and the
environment running in GitHub Actions are identical. Without Docker, renv gets you most
of the way there for R packages, but system dependencies (DuckDB native libs, Quarto
itself, Arrow C++ bindings) can still diverge silently between machines. For a learning
project, Docker is optional — renv alone may be sufficient — and the agent should flag
this trade-off explicitly in the docs and let the decision be revisited. If Docker is
implemented, it should be minimal: a Rocker base image with the project's renv
restored on top.

- Move parquet outputs and targets metadata/cache to GCS
- Configure centralized `config/` YAML:
  ```
  config/
    base.yaml
    local.yaml
    ci.yaml
  ```
- Set up a minimal Rocker-based Docker image (if proceeding with Docker) supporting:
  - `renv` restoration
  - Quarto rendering
  - targets execution
  - DuckDB/Arrow
- Push the Docker image to GitHub Container Registry (GHCR)
- Write GitHub Actions workflows for:
  - Building and caching the Docker image (if using Docker)
  - Restoring renv cache
  - Running the targets pipeline
  - Persisting artifacts to GCS
  - Rendering and deploying the public Quarto site
- Reference the existing WIF and GCP setup (already configured) — do not re-implement
- Write or update the following docs:
  - Guide: the full CI/CD flow step by step — what each workflow does and in what order
  - Primer: Docker for R projects — why it exists, what it adds beyond renv, the
    trade-off between complexity and reproducibility guarantees, when it's worth it
  - Primer: caching strategy — what is cached where and why, the layered approach
    across GHCR / GitHub Actions cache / GCS / repository freeze
  - Primer: Workload Identity Federation — conceptual explanation only, what it is,
    why it's better than long-lived service account keys, no implementation required
  - Guide: manual GCP setup steps (for new environments)
  - Guide: GitHub configuration and secrets
  - Update `docs/JOURNEY.md`: the Docker decision and reasoning, what broke in CI
    before it was fixed, what the caching layers actually saved

**Caching reference:**

| Artifact | Storage |
|---|---|
| Docker images | GHCR |
| renv cache | GitHub Actions cache |
| targets metadata | GCS |
| parquet outputs | GCS |
| Quarto freeze | repository |
| rendered site | GitHub Pages |

**What you learn:** Cloud-backed artifact storage, CI/CD for R projects, Docker for
reproducibility, GCS integration, the layered caching model.

---

### Phase 5 — Metadata, Lineage Documentation + Learning Materials

**Goal:** Make the project a genuine learning resource and tie together everything
built in the previous phases with clear, well-written documentation.

- Document artifact lineage: where each file comes from, what created it, what depends
  on it — trace a single data point from raw input to rendered report
- Write a concise **metadata primer** (readable in one sitting) covering:
  - What metadata is and why it matters
  - How targets hashes enable caching and reproducibility
  - How parquet schemas carry metadata (column types, statistics, row groups)
  - How modern lakehouse systems (DuckLake, Iceberg, Delta Lake) depend on metadata —
    conceptual overview only, no implementation
  - How this project is foundational preparation for exploring those systems later
- Add a **future thinking** section to the docs covering:
  - What would change if this project scaled (more data, more pipelines, a team)
  - What tools you would reach for next and why
  - Alternatives considered during the build and why they weren't chosen
  - What partitioning is and when it becomes worth implementing (it is an optimization,
    not a feature — document it as a future consideration)
- Finalize `docs/graphs/` with rendered dependency visualizations
- Write a final retrospective section in `docs/JOURNEY.md` covering:
  - What the full build taught
  - What you would do differently
  - What remains intentionally deferred and why
  - What to read or build next

**What you learn:** Metadata concepts, artifact lineage, lakehouse foundations, how to
document a project for future you.

---

## Repository Structure

```
project/
├── .github/
│   └── workflows/
├── config/
│   ├── base.yaml
│   ├── local.yaml
│   └── ci.yaml
├── data/
│   ├── raw/
│   ├── parquet/
│   └── derived/
├── docker/
│   └── Dockerfile
├── docs/
│   ├── graphs/
│   ├── guides/
│   ├── primers/
│   └── JOURNEY.md
├── infra/
│   └── tofu/
├── R/
├── reports/
├── scripts/
├── tests/
│   └── testthat/
├── website/
├── _targets.R
├── _quarto.yml
├── DESCRIPTION
├── renv.lock
└── README.md
```

---

## Reports

Reports are Quarto pages published to the website. They are the human-facing output of
the pipeline — journalism about the data, not raw output dumps. Each report should:

- Tell a story or surface a finding from pipeline outputs
- Be readable by someone who did not build the pipeline
- Consume data from parquet files or targets objects (not hardcoded values)
- Use `gt` for tables and `ggplot2` for charts where they support the narrative
- Live under `website/reports/` and be listed in the site navigation

The agent should create at least two example reports in Phase 3 using the `targets`
project data. These serve as templates for the pattern: pipeline produces data, report
consumes it, website publishes it.

---

## Documentation Requirements

Documentation is a first-class output of every phase, not a final step. The agent
updates the journey log and relevant primers/guides as part of completing each phase.

**Primers** (concise, plain-language, readable in one sitting) — lives under
`docs/primers/`:
- Quarto profiles and publishing
- renv and reproducible R environments
- targets orchestration
- Parquet and columnar storage
- Arrow and DuckDB (including their overlap — see Arrow vs DuckDB section)
- Metadata concepts and why they matter
- CI/CD for R projects
- Docker for R (including the trade-off discussion)
- GCS and cloud-backed artifacts
- Workload Identity Federation (conceptual only)

**Guides** (more technical, step-by-step) — lives under `docs/guides/`:
- How to run the pipeline locally
- How to run CI validation locally
- How to deploy manually
- How to add a new pipeline target
- How to add a new report page
- Manual GCP setup steps
- GitHub configuration and secrets

**Journey log** (`docs/JOURNEY.md`):
A living document written *during* the build, updated at the end of every phase. It
captures:
- Decisions made and why
- Alternatives considered and rejected
- Things that were harder than expected
- Things that are intentionally deferred
- Learning moments and realizations
- References and resources that helped
- What changed from the original plan and why

---

## Libraries

**Core:**
`targets`, `tarchetypes`, `arrow`, `duckdb`, `dplyr`, `renv`, `quarto`

**Infrastructure/utilities:**
`cli`, `fs`, `rlang`, `yaml`, `withr`, `processx`

**Group packages (use where relevant):**
`ojothemes` — `theme_okpi()` for ggplot2, `gt_okpi()` for gt tables, OKPI color palettes
`ojoutils` — `gcs_auth_bucket()`, `gcs_list_objects()`, `gcs_read_csv()`, `tar_gcs_csv()`

**Testing/quality:**
`testthat`, `lintr`, `pointblank`

**Reporting:**
`gt`, `ggplot2`

**Infra tooling:**
OpenTofu/Terraform, Docker (Rocker-based), GitHub Actions, GCS, GHCR

---

## Key Constraints From Meeting Notes

- **WIF is already set up. Don't touch it.** Reference it in docs as a concept only.
- **No Postgres internals.** Not relevant to current focus.
- **Metadata and targets interaction is the priority learning goal.**
- **Get a working demo running using the existing template first** — watch auto-deploy
  happen before worrying about deeper infrastructure.
- **Partitioning is an optimization, not a feature.** Don't implement it. Document it
  as a future consideration.
- **AI agent usage: be careful.** Don't let generated code drive logic without
  understanding it. Annotate everything. If something was generated, explain what it
  does and why.
- **Onboarding-aware design.** Write docs as if handing this project to someone who
  knows R but hasn't seen these tools. Break architecture into layers. New concepts
  should be introduced alongside a note about what they replace or simplify — keep
  total mental load stable.
- **Arrow and DuckDB overlap is real** — document it honestly rather than implying
  clean separation of roles.
- **Docker is optional at MVP scale** — document the trade-off and let the decision
  be made explicitly rather than assumed.
- **The journey log is a living document** — it is updated surgically at the end of
  every phase, not written in one sitting at the end.

---

## Orchestration Vision

Beyond the core build, the documentation should explore how a project like this could
be rolled out with minimal manual steps — ideally a single command.

**The dream:** `tofu apply` provisions all GCP infrastructure (buckets, service accounts,
WIF bindings), GitHub Actions workflows handle CI/CD, and a set of helper R functions
(`helpers::setup_project()`, `helpers::run_pipeline()`, `helpers::deploy_site()`) wrap
the most common operations into one-liners.

**What to document:**
- Helper functions that would simplify daily operations (running the pipeline, deploying,
  checking status). These should be sketched in `R/helpers/` and documented in a guide.
- How the OpenTofu + Actions pattern from `tofu-modules` and `actions` projects could
  be extended to auto-provision an entire analytics project: one `tofu apply` creates
  GCS buckets, GHCR access, WIF bindings, and the GitHub Pages deployment target.
- How the `environment-factory` pattern could scaffold dev/staging/prod for analytics
  projects at scale — even though this project doesn't implement it.
- What a `Makefile` or `justfile` alternative looks like for R projects.

This is aspirational documentation, not implementation. It belongs in
`docs/guides/orchestration-vision.md` and is written during Phase 4–5.

---

## Deliverables

1. A working, deployable Quarto website with at least two example reports (Phase 1–3)
2. A package-structured R project with locked dependencies (Phase 2)
3. A running targets pipeline producing parquet outputs and a dependency graph,
   using the `targets` project data (Phase 3)
4. A fully automated CI/CD pipeline deploying to GitHub Pages and persisting
   artifacts to GCS (Phase 4)
5. A complete set of primers, guides, example reports, and a journey log (all phases)
6. A README explaining the full project at a glance
7. Inline documentation throughout the codebase explaining metadata, orchestration,
   and reproducibility concepts
8. An orchestration vision document exploring one-command project rollout
9. Helper function stubs in `R/helpers/` for common operations
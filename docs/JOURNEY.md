# Journey Log

A living document updated at the end of every build phase. This is not a
changelog — it captures *decisions*, *reasoning*, *surprises*, and *learning
moments* encountered during the build.

---

## Phase 1 — Orient to the Quarto Foundation

**Date:** Phase 1 build  
**Goal:** Understand and verify the existing Quarto website template.

### What was done

- Carried forward the `okpolicy-website-template` Quarto extension (SCSS, title-block
  partial, yeti base theme) as if running `quarto use template`
- Set up the three-profile system: default, drafts (watermark + banner), public
  (hides draft content blocks)
- Created `index.qmd` with real project description and draft workflow notes
- Created two report stubs: Eviction Trends and Geographic Patterns
- Set up `config/base.yaml` for centralized project configuration
- Wrote a Quarto profiles primer and a guide for adding new report pages

### Decisions made

1. **Carried the Quarto extension forward** rather than stripping to plain HTML.
   The extension system is itself worth understanding — it demonstrates how Quarto
   format customization works (SCSS theming, Pandoc template partials).

2. **Reports live in `reports/{name}/` at the project root**, not under a separate
   `website/` directory. This keeps the Quarto project root at the same level as
   `_targets.R` and `DESCRIPTION`, which is simpler than nesting.

3. **Used `config/base.yaml`** for centralized config instead of hardcoding paths.
   This prepares for environment-specific overrides in Phase 4 (`local.yaml`, `ci.yaml`).

### Alternatives considered

- **Separate `website/` directory:** The starter prompt suggested a `website/`
  subdirectory for the Quarto site. After looking at how the template and BIG project
  work (Quarto at the root), keeping the Quarto project at root was cleaner. Moving
  it would require a separate `_quarto.yml` and more complex path management.

- **Dropping the extension:** Would have simplified the project but lost a valuable
  learning point about Quarto's extension system.

### What was learned

- Quarto profiles are essentially YAML merge operations — the profile file overrides
  specific keys in the base config. Understanding this makes the system predictable.
- The `::: {.content-hidden when-profile="public"}` syntax is a Quarto div filter,
  not a Pandoc feature. It only works in Quarto's processing pipeline.
- The custom extension format name (`okpolicy-website-template-html`) is derived
  from the extension directory name + the base format it extends (`html`).

### What comes next

Phase 2 adds the R package skeleton, `renv`, and testing. The Quarto site
doesn't need to change much — the R infrastructure wraps around it.

---

---

## Phase 2 — R Package Structure + Reproducible Environment

**Date:** Phase 2 build  
**Goal:** Give the project a proper R package skeleton and lock down dependencies.

### What was done

- Added `DESCRIPTION` file modeled after the BIG project's structure, with
  `ojothemes` and `ojoutils` as GitHub Remotes
- Created `R/` directory with four modules:
  - `config.R` — centralized config loader with environment overlay support
  - `data.R` — pipeline data functions (CSV load, parquet convert, Arrow read, DuckDB query)
  - `analysis.R` — summary functions consumed by reports
  - `helpers.R` — orchestration helpers (`run_pipeline()`, `deploy_local()`, `check_status()`)
- Added `.lintr` configuration with reasonable defaults
- Set up `testthat` with tests covering data functions and parquet round-trip
- Wrote primers: package structure, renv, testing basics

### Decisions made

1. **Organized R/ by concern (config, data, analysis, helpers)** rather than by
   pipeline stage (01-ingest, 03-process like the targets reference project).
   The numbered-directory pattern works for large pipelines with many contributors;
   for a learning project with ~10 functions, file-by-concern is clearer.

2. **Created helper functions early.** `run_pipeline()`, `deploy_local()`, and
   `check_status()` are stubs that will be fleshed out in later phases, but
   having them from the start establishes the "one command" orchestration pattern.

3. **Listed ojothemes and ojoutils as Remotes** rather than copying their code.
   This keeps the learning project connected to the group's ecosystem while
   maintaining a clear boundary between project code and shared utilities.

### What was learned

- An R package `DESCRIPTION` is essentially a manifest file — similar in spirit
  to `package.json` (Node) or `pyproject.toml` (Python). The `Remotes:` field
  is the R equivalent of GitHub-hosted dependencies.
- `devtools::load_all()` is the R development equivalent of hot-reloading — it
  loads all functions from `R/` without restarting the session.
- `withr::local_tempdir()` in tests is brilliant — automatic cleanup of test
  artifacts with zero boilerplate.

---

## Phase 3 — targets Pipeline + DuckDB/Arrow/Parquet

**Date:** Phase 3 build  
**Goal:** Build a real data pipeline using the targets project data.

### What was done

- Created `_targets.R` with a 5-stage pipeline:
  raw CSV → parquet → Arrow/DuckDB queries → summaries → report-ready parquet
- Demonstrated both dplyr (R) and SQL (DuckDB) approaches to the same data
- Upgraded report pages to consume parquet pipeline outputs with CSV fallback
- Wrote primers: targets orchestration, parquet format, Arrow vs DuckDB,
  dependency graphs and hashing
- Wrote guide: how the Quarto website consumes pipeline outputs

### Decisions made

1. **Used the exported CSV as raw input** rather than reimplementing the database
   ingestion from the targets reference project. This is a deliberate simplification
   that keeps the learning project self-contained.

2. **Demonstrated both Arrow and DuckDB** on the same data rather than choosing one.
   The annual summary uses dplyr (clearest for simple aggregation), while the
   year-over-year change uses DuckDB SQL (clearest for window functions).

3. **Parquet files are the contract** between the pipeline and reports. Reports read
   from `data/parquet/`, not from the targets cache. This makes reports portable —
   they work without the `_targets/` directory.

### What was learned

- DuckDB can read parquet files directly in SQL (`read_parquet('file.parquet')`)
  without needing to load them into R first — this is remarkably powerful.
- The `format = "file"` option in `tar_target()` changes what targets tracks:
  it monitors the file on disk instead of the R object in memory.
- Arrow and DuckDB really do overlap for simple operations. The primer was
  honest about this rather than pretending clean role separation.

---

## Phase 4 — GCS Cloud Storage + GitHub Actions CI

**Date:** Phase 4 build  
**Goal:** Automate everything — pipeline runs, artifact persistence, site deployment.

### What was done

- Created four GitHub Actions workflows:
  - `docker-build.yml` — builds and pushes the environment image to GHCR
  - `pipeline-deploy.yml` — full pipeline + site deployment (runs inside Docker)
  - `tofu-ci.yml` — validates Tofu formatting on PRs
  - `tofu-apply.yml` — applies infrastructure on push to main
- Added Tofu infrastructure: GCS buckets, service account, WIF IAM binding
- Optimized Dockerfile for CI: added Node.js and global RENV library paths
- Added environment config overlays: `local.yaml` and `ci.yaml`
- Wrote primers: Docker, caching strategy, WIF, GCS, CI/CD
- Wrote guides: GitHub config, GCP setup, running locally

### Decisions made

1. **Three separate workflows** rather than one mega-workflow. Pipeline and
   infrastructure have different triggers (all pushes vs. infra-only changes)
   and different permission requirements.

2. **Local targets + GCS upload** rather than GCS-backed targets
   (`repository = "gcp"`). The tcj project uses GCS-backed targets natively,
   but for a learning project, storing locally and uploading as a separate step
   is easier to understand and debug.

3. **Pivot to Mandatory Docker for CI.** We moved from "Docker-optional" to
   "Docker-required." By refactoring `pipeline-deploy.yml` to run entirely
   inside a GHCR-hosted container, we solved two major problems:
   - **Environment Drift:** It guarantees that the local developer environment
     and the GitHub runner are 100% identical. This eliminates bugs where
     system-level libraries (like Arrow or DuckDB) might diverge between machines.
   - **Performance:** It removes the need for slow setup steps (installing R, 
     renv, system deps, and Quarto) from every run, as these are now pre-baked
     into the image.

4. **Automated Environment Synchronization.** We added `docker-build.yml` to
   ensure that any change to `renv.lock` or the `Dockerfile` triggers a new
   image build. This keeps the reproducible environment in lock-step with
   the codebase.

5. **Reused the actions repo's reusable workflows** for Tofu CI and Apply.
   This is the exact pattern the group uses — no reinvention.

### What was learned

- WIF is conceptually simple but architecturally distributed — the pool lives
  in one project, bindings live in each project's Tofu, and the exchange
  happens transparently in the workflow.
- GitHub Actions' `vars` (repository variables) vs `secrets` distinction
  matters: with WIF, there ARE no secrets — everything is a variable.
- **Container Runtime Hurdles:** Running GitHub Actions *inside* a container
  requires Node.js to be installed in the image (for the runner's internal
  scripts). Additionally, we had to set `RENV_PATHS_LIBRARY` to a global path
  outside the project root to prevent the GitHub workspace mount from
  accidentally hiding the pre-installed R package library.
- **Private Repo Access in Docker:** Installing internal packages (like `ojothemes`)
  during a `docker build` requires passing GitHub credentials into the build.
  The best-practice version uses a BuildKit secret, not a Docker build argument,
  because the build environment is isolated from the runner's git credentials.
- The multi-layer caching strategy (Docker/GHCR, renv/Actions, targets/GCS,
  Quarto/freeze) is complex but each layer serves a distinct purpose.

---

## Phase 5 — Metadata, Lineage, Documentation, and Orchestration Vision

**Date:** Phase 5 build  
**Goal:** Capstone documentation — connecting project patterns to production concepts.

### What was done

- Wrote metadata primer covering lineage, data catalogs, and lakehouse systems
  (Iceberg, Delta Lake, DuckLake)
- Wrote future thinking primer mapping each project choice to its scaled-up
  equivalent (targets → Airflow, DuckDB → BigQuery, GCS → lakehouse, etc.)
- Wrote orchestration vision document exploring one-command project rollout:
  `ojoscaffold::new_project()`, justfile patterns, and helper function roadmap
- Created comprehensive README with full project structure, pipeline flow,
  documentation index, and quick start
- Finalized JOURNEY.md with all five phase entries

### Decisions made

1. **Kept metadata/lineage as documentation, not implementation.** At ~27K rows,
   implementing Iceberg or Delta Lake would be over-engineering. The primers
   explain the concepts and point to when you'd actually need them.

2. **Orchestration vision is aspirational.** The `ojoscaffold` package and
   `justfile` patterns are described but not built. They're the natural next
   project after mastering the patterns in this one.

3. **Partitioning was documented but not implemented** (as the starter prompt
   instructed). The metadata primer explains when partitioning matters and why
   it doesn't matter at this scale.

### What was learned

- The gap between "I have all the pieces" and "I can spin up a project with
  one command" is the orchestration layer. The reference projects (templates,
  tofu-modules, actions) have every component. The missing piece is the glue.
- Writing documentation alongside code (not after it) changes how you think
  about architecture. Explaining a decision forces you to justify it.
- The 15 primers and 6 guides written across this project form a genuine
  curriculum. They're not just documentation — they're a teaching sequence
  that builds from Quarto profiles to lakehouse metadata.

### Final reflection

This project started as a learning exercise and became something more
structured: a documented architecture that could be replicated. The
reference projects provided patterns; this project synthesized them into
a coherent, explained whole.

The next step is clear: build the orchestration layer that turns this
into a repeatable template. `ojoscaffold::new_project()` would be the
capstone of the capstone.

---

## Docker CI Repair - `.Rprofile` and Build Secrets

**Date:** 2026-05-14

**Goal:** Fix the GitHub Actions Docker image build and make the Docker setup follow the project instead of forcing the project to satisfy Docker.

### What failed

The GitHub Actions Docker build reached the `COPY .Rprofile .Rprofile`
layer and failed because the repository does not have a root `.Rprofile`:

```text
#14 [ 8/10] COPY .Rprofile .Rprofile
#14 ERROR: failed to calculate checksum ... "/.Rprofile": not found
ERROR: failed to build: failed to solve: failed to compute cache key
```

The same log also showed a missing GHCR build cache tag:

```text
failed to configure registry cache importer:
ghcr.io/spindouken/reproducibilitronicus:buildcache: not found
```

That cache message was incidental. It can happen before the first successful
cache export. The build-stopping problem was the missing `.Rprofile` source
file.

### Decisions made

1. **Do not create `.Rprofile` just to satisfy Docker.** A project startup file
   should serve the local R workflow, not patch over a Dockerfile assumption.
   The image now calls `renv::restore()` explicitly from `Rscript`.

2. **Make the container runtime library explicit.** Packages are restored into
   `/opt/renv/library`, and `R_LIBS_USER` points R at that library. This keeps
   packages outside the checked-out workspace, so GitHub Actions' workspace
   mount does not hide the baked library.

3. **Use BuildKit secrets for GitHub credentials.** The previous build used a
   Docker build argument and `ENV GITHUB_PAT`, which risks preserving secrets in
   image metadata. The workflow now passes `github_token` as a BuildKit secret,
   preferring `RENV_GITHUB_PAT` when private dependency repositories require it
   and falling back to the workflow token otherwise.

4. **Add a Docker context guardrail.** `.dockerignore` now excludes generated
   artifacts and local credential files such as `key.json`, so `COPY . .` does
   not accidentally bake local secrets or large transient outputs into the image.

### What was learned

- `renv.lock` is sufficient for a non-interactive restore when the Dockerfile
  calls `renv::restore()` directly. A missing `.Rprofile` should not be fatal
  for CI image creation.
- A Docker image that will run under GitHub Actions needs its package library
  somewhere outside the mounted repository workspace.
- Cache import errors can look alarming in BuildKit logs, but the real failure
  is usually the final `ERROR: failed to build` block tied to a specific layer.

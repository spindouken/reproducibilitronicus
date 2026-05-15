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
   In Phase 1 this looked small: the site needed to know where reports, docs,
   raw data, parquet outputs, and Quarto profiles lived. We could have written
   those paths directly into report files and helper functions, but that would
   have made every future change a search-and-replace problem.

   `config/base.yaml` became the project's shared default contract. It says,
   "these are the normal names and locations for this project." Later files can
   override only the pieces that differ by context. For example, local work can
   use filesystem paths and draft rendering, while CI can use GCS buckets and
   the public Quarto profile. That is why Phase 4 could add `local.yaml` and
   `ci.yaml` without rewriting the reports or pipeline functions.

   Looking ahead to Phase 5, this is also the first tiny version of the
   orchestration idea. A future `ojoscaffold::new_project()` or `just` command
   would need one place to read project names, data locations, storage choices,
   and render profiles. Centralized config turns those choices into explicit
   project metadata instead of hidden assumptions spread across the codebase.

   How it actually works in this repo:

   - `R/config.R` defines `load_config()`.
   - `load_config()` always reads `config/base.yaml`.
   - It checks `R_CONFIG_ACTIVE`; if nothing is set, it assumes `local`.
   - It then looks for `config/{environment}.yaml`, such as `config/local.yaml`
     or `config/ci.yaml`.
   - If that overlay exists, its values replace matching values from
     `base.yaml`.
   - Other R functions call `load_config()` and then read values from the
     returned list, such as `config$pipeline$source_file`.

   The flow is:

   ```text
   GitHub Actions or local shell
     sets R_CONFIG_ACTIVE
       -> load_config()
         -> config/base.yaml
         -> config/local.yaml or config/ci.yaml overlay
         -> R functions use the merged config list
   ```

   Today, the config is used directly by `load_eviction_data()` to choose the
   raw source CSV. It is also reflected in helper/status output through the
   active environment name. Some paths are still hardcoded in `_targets.R`, the
   report `.qmd` files, and helper functions. That means `base.yaml` is partly
   implemented and partly aspirational: it establishes the pattern, but the
   codebase has not yet fully moved every path and profile lookup behind
   `load_config()`.

   The intended mature version is clearer:

   - `_targets.R` would use `config$paths$data_parquet` instead of hardcoding
     `data/parquet`.
   - Reports would read `config$paths$data_raw` and
     `config$paths$data_parquet` instead of writing those paths directly.
   - `deploy_local()` would default to `config$quarto$default_profile`.
   - CI would set `R_CONFIG_ACTIVE=ci`, causing the same R code to use CI
     storage/rendering choices without branching throughout the code.

   This is the connection to `ojoscaffold::new_project()`: a scaffold function
   needs inputs before it can generate a project. It needs to know things like
   the project name, display title, raw data folder, derived data folder,
   report folder, Quarto profiles, storage backend, and optional cloud bucket
   names. If those values live as hardcoded strings scattered across `_targets.R`,
   reports, workflows, and helper functions, a scaffold function has no single
   source of truth to write or update. It would have to template every file
   separately and hope it replaced every string correctly.

   A central config file gives the scaffold function a stable contract. The
   function can ask a few questions once, write `config/base.yaml`, then generate
   project files that refer back to that config. `_targets.R` can ask the config
   where parquet files go. Reports can ask the config where pipeline outputs
   live. Workflows can set `R_CONFIG_ACTIVE=ci` and let the same R code load CI
   settings. That is what makes scaffolding safer than copying an old project:
   the generated files depend on named config values instead of duplicated
   literal paths.

   Put differently, hard paths make scaffolding fragile because every generated
   file has to be customized. Config-driven paths make scaffolding repeatable
   because the scaffold can generate mostly standard files, then change behavior
   by changing a small, explicit config layer.

   `just` refers to the `just` command runner, which is like a friendlier,
   project-focused Makefile. A repo can include a `justfile` with commands like
   `just run`, `just render`, `just docker-build`, or `just deploy`. Those
   commands can read or respect the same config assumptions, giving humans one
   memorable command while the project handles the details underneath.

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
- Centralized config is not just convenience. It is a boundary between stable
  project meaning and changing execution environments. Phase 1 only needed the
  project to render locally, but the same config shape made room for Phase 4 CI
  and Phase 5 orchestration without changing the basic project layout.
- The current implementation is intentionally incomplete. It proves the pattern
  through `load_config()` and the source-data filename, but the next cleanup
  would be to replace remaining hardcoded paths in `_targets.R`, reports, and
  helpers with config lookups.

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

5. **Point workflows at the actual default branch.** The repo is on `master`,
   but the workflows were listening for `main`. That meant pushing the fix did
   not automatically produce a fresh image build, and rerunning the old failed
   job on GitHub kept rebuilding the old commit.

### What was learned

- `renv.lock` is sufficient for a non-interactive restore when the Dockerfile
  calls `renv::restore()` directly. A missing `.Rprofile` should not be fatal
  for CI image creation.
- A Docker image that will run under GitHub Actions needs its package library
  somewhere outside the mounted repository workspace.
- Cache import errors can look alarming in BuildKit logs, but the real failure
  is usually the final `ERROR: failed to build` block tied to a specific layer.
- Rerunning a failed GitHub Actions job reruns the same commit. When the fix
  lands in a later commit, start a new workflow run from that branch instead.
- `renv` locks R package versions, but source package installation still needs
  native system tools. The next CI run exposed this cleanly: `duckdb` failed
  because `xz-utils` was missing, and `renv` also flagged `cmake`,
  `libglpk-dev`, `libnode-dev`, and `pandoc`. Those now live in the Docker
  system dependency layer.
- This error was nuanced because it sat at the boundary between R and Linux.
  `renv.lock` told Docker which R packages to install, but not every Ubuntu
  tool those source installs need. The way to know what to fix was in the log:
  first, `renv` printed the missing system packages; second, `duckdb` failed on
  `xz: Cannot exec`, which points directly to `xz-utils`.
- A fully prepared Dockerfile usually comes from an existing production project
  with a similar `renv.lock`, from a generated dependency scan, or from iterating
  through CI failures until the clean image has every native tool it needs. The
  original Dockerfile was a reasonable starter, not a complete inventory.
- Docker is helpful but not mandatory here. The easier route is a plain GitHub
  Actions R workflow that installs system packages, restores `renv`, runs
  `targets`, and renders Quarto. Docker becomes worth it when stable OS-level
  reproducibility matters enough to justify the extra maintenance.
- The successful Docker build exposed the next boundary: the deploy job runs
  inside the custom image too. The image had what R needed, but not `gsutil`,
  because `gsutil` belongs to the Google Cloud SDK. Rather than add the whole
  Cloud SDK to the R image, the workflow now uses
  `google-github-actions/upload-cloud-storage` for GCS uploads after auth. This
  keeps the Docker image responsible for the R environment and lets GitHub
  Actions handle cloud upload plumbing.

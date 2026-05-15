# CLI Error Log & Resolutions

This document tracks the CLI errors encountered during the infrastructure setup, explaining why they happened and how they were resolved.

### 1. Missing Application Default Credentials
**Error:** `storage.NewClient() failed: dialing: credentials: could not find default credentials`
**Why it happened:** The user ran `gcloud auth login` (which logs the human user in for standard commands) but did not generate "Application Default Credentials" (ADC). Tools like OpenTofu and Terraform require ADC to authenticate API calls to Google Cloud.
**How we fixed it:** Ran `gcloud auth application-default login`.

### 2. Tofu Init 404 Bucket Not Found
**Error:** `Error 404: The specified bucket does not exist` during `tofu init`.
**Why it happened:** The `backend.tf` file had a hardcoded placeholder (`r-analytics-platform-tofu-state`), but the user had created a bucket with a different name in Step 1. Tofu tried to connect to the placeholder bucket and couldn't find it.
**How we fixed it:** Updated `backend.tf` to exactly match the bucket name the user actually created.

### 3. Tofu Apply Prompting for WIF
**Error:** `tofu apply` stopped and prompted: `var.wif_pool_name Enter a value:`
**Why it happened:** We pivoted the architecture from using Workload Identity Federation (WIF) to using a simple Service Account JSON Key. However, because the user had copied the project into a new folder outside the AI's active workspace, the AI's automated edits to remove the WIF code from `main.tf` failed to apply to the new folder.
**How we fixed it:** Manually deleted the WIF resources and variables from the bottom of `main.tf`.

### 4. Unknown Project ID (r-analytics-platform)
**Error:** `googleapi: Error 400: Unknown project id: r-analytics-platform, invalid` during `tofu apply`.
**Why it happened:** OpenTofu inherits the default project from your local `gcloud` configuration. Earlier, the user copy-pasted `gcloud config set project YOUR_GCP_PROJECT_ID` but likely had the placeholder `r-analytics-platform` set in their terminal instead of their *actual* GCP Project ID. So Tofu tried to build resources inside a fake project called `r-analytics-platform`.
**How we fixed it:** The user needed to run `gcloud config set project THEIR_REAL_PROJECT_ID` so the default environment was correct.

### 5. Duplicate Provider Configuration
**Error:** `A default (non-aliased) provider configuration for "google" was already given`
**Why it happened:** The AI attempted to fix Error 4 by adding a `provider "google"` block to `main.tf`. However, there was already a `provider.tf` file that contained the provider block (and was the actual source of the hardcoded `r-analytics-platform` string). Terraform does not allow two default providers for the same plugin.
**How we fixed it:** Deleted the duplicate provider from `main.tf` and updated `provider.tf` to use `local.project` dynamically.

### 6. Bucket 409 Conflict (Already Exists)
**Error:** `Error 409: Your previous request to create the named bucket succeeded and you already own it., conflict`
**Why it happened:** In Step 1, the user manually created the Tofu State Bucket via the `gcloud` CLI. However, `main.tf` also contained a resource block instructing Tofu to create that exact same bucket. Because this was Tofu's first run, its memory (state) was empty, so it tried to create it again and hit a conflict.
**How we fixed it:** We simply deleted the `google_storage_bucket.state_bucket` block from `main.tf`. The state bucket is considered "bootstrap" infrastructure and doesn't need to be managed by Tofu itself.

### 7. Missing renv.lock File
**Error:** `Error: This project does not contain a lockfile. Have you called snapshot() yet?` in GitHub Actions.
**Why it happened:** The GitHub Actions workflow relies on `renv` to install the exact R packages the project needs. However, the user had not generated the `renv.lock` file (the "recipe book" of package versions) locally before pushing their code to GitHub.
**How we fixed it:** The user opened an R console locally, ran `renv::snapshot()` to generate the `renv.lock` file, and then committed and pushed that file to GitHub.

### 8. Docker Build: Missing `/renv` Directory
**Error:** `"/renv": not found` during `buildx`.
**Why it happened:** The `Dockerfile` attempted to `COPY renv/ renv/`, but the `renv/` directory (containing initialization scripts) was missing from the local workspace and thus the git repository.
**How we fixed it:** Removed the `COPY renv/ renv/` line from the `Dockerfile`. `renv::restore()` only strictly requires `renv.lock` to recreate the environment.

### 9. Docker Build: Git Exit Code 128 (Private Repos)
**Error:** `The process '/usr/bin/git' failed with exit code 128` during `renv::restore()`.
**Why it happened:** The project depends on internal packages (`ojothemes`, `ojoutils`). When `renv::restore()` runs during a `docker build` in CI, it lacks the credentials to clone these private repositories.
**How we fixed it at the time:** Passed `GITHUB_TOKEN` as a build argument (`GITHUB_PAT`) to the Docker build and updated the `Dockerfile` to use it for authentication. This was later replaced with a BuildKit secret in Error 11 to avoid baking credentials into image metadata.

### 10. GitHub Actions: Node.js 20 Deprecation
**Error:** `Node.js 20 actions are deprecated...` warnings.
**Why it happened:** The workflow utilized older action versions that default to the now-deprecated Node.js 20 runtime.
**How we fixed it:** Updated `docker/build-push-action` to `v6` and set `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true` to opt into Node.js 24.

### 11. Docker Build: Missing `.Rprofile`
**Error:** `COPY .Rprofile .Rprofile` failed during `docker/build-push-action@v6` with `"/.Rprofile": not found`.
**Why it happened:** The repository does not contain a root `.Rprofile`, but the Dockerfile still required one before running `renv::restore()`. BuildKit calculates checksums for each `COPY` source before the layer runs, so the build stopped before package restoration could proceed.
**Important non-cause:** The log also showed `failed to configure registry cache importer: ghcr.io/spindouken/reproducibilitronicus:buildcache: not found`. That means the registry cache tag did not exist yet, which can happen on the first cache-producing build. It was noisy, but not the fatal error. The fatal error was the missing `.Rprofile`.
**How we fixed it:** Removed the `.Rprofile` copy from the Dockerfile and made Docker independent of project startup files. The image now restores `renv.lock` into `/opt/renv/library`, exposes that path through `R_LIBS_USER`, disables the `renv` autoloader for container runs, and uses `Rscript` directly. We also changed the GitHub token handoff from a Docker build argument to a BuildKit secret so credentials are not baked into image metadata. The workflow prefers a `RENV_GITHUB_PAT` secret for private dependency repositories and falls back to the automatic workflow token otherwise.
**Follow-up gotcha:** GitHub re-runs use the same commit as the failed run. The old failure log built revision `7406cbc`, which still had `COPY .Rprofile .Rprofile`. The fixed Dockerfile is in a later commit. The workflows were also listening for `main` while this repo uses `master`, so they needed to be pointed at `master` for push-triggered runs.

Key log lines:

```text
#14 [ 8/10] COPY .Rprofile .Rprofile
#14 ERROR: failed to calculate checksum ... "/.Rprofile": not found
ERROR: failed to build: failed to solve: failed to compute cache key
```

### 12. Docker Build: Missing System Dependency for `duckdb`
**Error:** `Error: failed to install "duckdb"` during `renv::restore()`, with `tar (child): xz: Cannot exec: No such file or directory`.
**Why it happened:** The Docker image had the R package lockfile but was missing some native Ubuntu packages needed while restoring source packages. `duckdb` specifically needed `xz-utils` so `tar` could unpack `duckdb.tar.xz`. The `renv` preflight also flagged `cmake`, `libglpk-dev`, `libnode-dev`, and `pandoc` for other packages.
**How we fixed it:** Added the missing system dependencies to the Dockerfile's `apt-get install` layer: `cmake`, `xz-utils`, `pandoc`, `libglpk-dev`, and `libnode-dev`.
**How to recognize it next time:** Look near the first actual package failure, not the huge download/install noise. Here the important line was `xz: Cannot exec`, which means the operating system tool `xz` was missing. `renv` also printed a helpful list at the top: `The following required system packages are not installed`. Those package names are the things to add to `apt-get install`.
**Why it was not there originally:** The first Dockerfile had a hand-written starter list of common R system libraries. That gets you partway, but it was not generated from the exact packages in `renv.lock`. The missing tools only became obvious once CI tried to restore every locked package from source in a clean Linux image.
**Is Docker necessary?** Not strictly. For this learning project, the easier path is to run the pipeline directly in GitHub Actions with R setup plus `renv::restore()`. Docker is useful when you want the same OS-level environment every time, but it costs more setup work because R package versions and Ubuntu system packages both have to be maintained.

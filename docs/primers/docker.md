# Primer: Docker for R Projects

## Why Docker?

In an R project, `renv` is excellent at locking down your **R package versions**. It ensures that everyone is using `dplyr 1.1.4` and `targets 1.6.0`. 

However, `renv` does **not** manage your **system dependencies**. Subtle differences in the underlying operating system can break a pipeline:
- **Arrow:** The `arrow` R package depends on complex C++ libraries. If the system's `libcurl` or `libssl` versions differ, the installation can fail or produce different results.
- **DuckDB:** Uses a native analytical engine that relies on specific system libraries.
- **Quarto:** A standalone CLI tool. If your local machine has Quarto 1.5 and the CI runner has Quarto 1.4, your website might render differently.

**Docker solves this** by packaging the entire operating system, R, system libraries, and Quarto into a single, immutable image.

## How it works in this project

We use a "Layered Caching" strategy to keep the pipeline fast:

1.  **Base Image (`rocker/r-ver:4.4.2`):** We start with a stable, reproducible R environment provided by the Rocker Project.
2.  **System Deps:** We install the native C++ libraries needed by Arrow, DuckDB, and GitHub Actions.
3.  **renv Restoration:** We copy the `renv.lock` file and run `renv::restore()`. This bakes all 50+ R packages into the image.
4.  **GitHub Container Registry (GHCR):** We push this image to GHCR (`ghcr.io`). 

### Caching Strategy

The `docker-build.yml` workflow uses **GHCR as a cache**. 
- If you change your R code, the Docker build is skipped because `renv.lock` hasn't changed.
- If you add a new R package and update `renv.lock`, Docker will re-run the `renv::restore()` step to update the image.

## The GitHub Actions Connection

Our `pipeline-deploy.yml` uses the `container:` directive:

```yaml
container:
  image: ghcr.io/${{ github.repository }}:latest
```

When the workflow starts, GitHub pulls the image from GHCR and mounts your repository inside it. Because the image already contains R, Quarto, and all packages, we can skip the 10-minute setup process and jump straight to `targets::tar_make()`.

## Local Usage

You can also use this image locally to ensure your code runs exactly like it will in CI:

```bash
# Build the image locally
docker build -t repro-env -f docker/Dockerfile .

# Run the pipeline inside the container
docker run --rm -v $(pwd):/project repro-env Rscript -e "targets::tar_make()"
```

## Trade-offs

- **Complexity:** You now have to manage a `Dockerfile` and a GHCR publishing workflow.
- **Storage:** Docker images can be large (1GB+).
- **Speed:** The *first* build is slow, but subsequent runs are significantly faster than bare-metal setup because of the pre-baked environment.

# syntax=docker/dockerfile:1.7
# Dockerfile - Rocker-based image for reproducible R environment
#
# This is a minimal Docker image that provides:
# 1. A fixed R version (via Rocker)
# 2. System dependencies (Arrow C++ bindings, DuckDB libs, etc.)
# 3. renv-restored R packages (exact versions from renv.lock)
# 4. Quarto for rendering
#
# Why Docker for a learning project?
# renv locks R package versions but NOT system dependencies. Arrow's C++
# bindings, DuckDB's native engine, and Quarto itself are system-level
# tools that can silently diverge between machines. Docker pins everything.
#
# Trade-off: Docker adds complexity (image builds, registry management,
# layer caching). For a solo learning project, renv alone may be sufficient.
# This Dockerfile exists to demonstrate the pattern and document the
# trade-off - it's optional, not mandatory.
#
# Reference: BIG project's Dockerfile uses the same Rocker base pattern.

FROM docker.io/rocker/r-ver:4.4.2

# --- System dependencies ---
# These are the native libraries that R packages need at the C/C++ level.
# Without them, install.packages("arrow") would fail.
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  git \
  nodejs \
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  libfontconfig1-dev \
  libfreetype-dev \
  libharfbuzz-dev \
  libfribidi-dev \
  libpng-dev \
  libtiff5-dev \
  libjpeg-dev \
  libcairo2-dev \
  zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

# --- Install Quarto ---
ARG QUARTO_VERSION=1.5.57
RUN curl -LO https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb \
  && dpkg -i quarto-${QUARTO_VERSION}-linux-amd64.deb \
  && rm quarto-${QUARTO_VERSION}-linux-amd64.deb

# --- Configure image-level R library ---
# Keep installed packages outside the project workspace so GitHub Actions'
# checkout mount cannot hide them. R_LIBS_USER makes the baked package library
# visible to normal Rscript invocations without requiring a project .Rprofile.
ENV RENV_PATHS_LIBRARY=/opt/renv/library \
  R_LIBS_USER=/opt/renv/library \
  RENV_CONFIG_AUTOLOADER_ENABLED=FALSE
RUN mkdir -p "${RENV_PATHS_LIBRARY}"

# --- Install renv ---
RUN R -e "install.packages('renv', repos = 'https://cloud.r-project.org')"

# --- Project files ---
# We copy just the lockfile and config first for caching purposes.
WORKDIR /project
COPY renv.lock renv.lock

# --- Restore R packages from lockfile ---
# This is the key step: renv::restore() installs the exact package versions
# recorded in renv.lock into the image-level library.
#
# If private GitHub remotes are present, pass a token as a BuildKit secret:
#   docker build --secret id=github_token,env=GITHUB_PAT -f docker/Dockerfile .
RUN --mount=type=secret,id=github_token \
  set -eu; \
  tmp_home="$(mktemp -d)"; \
  export HOME="${tmp_home}"; \
  if [ -s /run/secrets/github_token ]; then \
    token="$(cat /run/secrets/github_token)"; \
    export GITHUB_PAT="${token}"; \
    git config --global url."https://x-access-token:${token}@github.com/".insteadOf "https://github.com/"; \
  fi; \
  Rscript -e "renv::restore(lockfile = 'renv.lock', library = Sys.getenv('RENV_PATHS_LIBRARY'), prompt = FALSE)"; \
  rm -rf "${tmp_home}"

# --- Copy remaining project files ---
# In a CI environment, the workspace will be mounted over this, but having
# it here makes the image usable standalone as well.
COPY . .

# Default command: run the pipeline then render the site.
CMD ["Rscript", "-e", "targets::tar_make(); quarto::quarto_render(profile = 'public')"]

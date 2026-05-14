# Dockerfile — Rocker-based image for reproducible R environment
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
# trade-off — it's optional, not mandatory.
#
# Reference: BIG project's Dockerfile uses the same Rocker base pattern.

FROM docker.io/rocker/r-ver:4.4.2

# --- System dependencies ---
# These are the native libraries that R packages need at the C/C++ level.
# Without them, install.packages("arrow") would fail.
RUN apt-get update && apt-get install -y \
  git \
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

# --- Install renv ---
RUN R -e "install.packages('renv', repos = 'https://cloud.r-project.org')"

# --- Project files ---
WORKDIR /project
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile
COPY renv/ renv/

# --- Restore R packages from lockfile ---
# This is the key step: renv::restore() installs the exact package versions
# recorded in renv.lock, ensuring reproducibility.
RUN R -e "renv::restore(prompt = FALSE)"

# --- Copy remaining project files ---
COPY . .

# Default command: run the pipeline then render the site
CMD ["R", "-e", "targets::tar_make(); quarto::quarto_render(profile = 'public')"]

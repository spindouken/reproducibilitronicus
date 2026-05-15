# infra/tofu/main.tf — GCP infrastructure for the analytics platform
#
# This provisions the cloud resources needed by the project:
# - GCS buckets for pipeline artifacts and targets metadata
# - Service account with appropriate IAM roles
# - WIF binding for GitHub Actions (references existing pool)
#
# Reference: tcj project's infra/tofu/main.tf
# Reference: tofu-modules project-factory pattern
#
# WIF is NOT created here — it's managed centrally in
# openjusticeok/infrastructure (Hub & Spoke model).
# This module only creates IAM bindings to the existing pool.


locals {
  project = "reproducibilitron"  # Replace with actual GCP project ID
  region  = "us-central1"
}

# --- GCS Bucket: Pipeline Data ---
# Stores parquet outputs and derived data.
# Equivalent to the tcj project's "city-county-j-data" bucket.
resource "google_storage_bucket" "data_bucket" {
  name     = "${local.project}-data"
  location = "US"

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }
}

# --- GCS Bucket: Targets Cache ---
# Stores targets metadata and cached objects.
# Equivalent to the tcj project's "city-county-j-targets" bucket.
resource "google_storage_bucket" "targets_bucket" {
  name     = "${local.project}-targets"
  location = "US"

  uniform_bucket_level_access = true
}



# --- Service Account ---
# Used by GitHub Actions (via WIF) and optionally by the Docker container.
resource "google_service_account" "pipeline_sa" {
  account_id   = "${local.project}-pipeline"
  display_name = "R Analytics Platform Pipeline SA"
}

# Grant the SA access to the data bucket
resource "google_storage_bucket_iam_member" "sa_data_access" {
  bucket = google_storage_bucket.data_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.pipeline_sa.email}"
}

# Grant the SA access to the targets bucket
resource "google_storage_bucket_iam_member" "sa_targets_access" {
  bucket = google_storage_bucket.targets_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.pipeline_sa.email}"
}

# --- IAM Role for GitHub Actions (Service Account Key) ---
# For the MVP, GitHub Actions will authenticate using a JSON key
# generated for this Service Account. WIF is deferred to a later phase.
#
# Once you run `tofu apply`, you will manually generate a JSON key for:
# ${local.project}-pipeline@${local.project}.iam.gserviceaccount.com
# and save it as a GitHub Secret named GCP_CREDENTIALS.


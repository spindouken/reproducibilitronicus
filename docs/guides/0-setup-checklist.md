# GCP & GitHub CI/CD Setup Checklist (Beginner's Guide)

This document provides the exact, step-by-step instructions to provision the cloud infrastructure and wire up GitHub Actions for Phase 5. It assumes you are starting from scratch.

## Security Context: Why do we do it this way?
**"Wait, doesn't Step 1 save credentials locally?"**
Yes, but this is the Google Cloud standard best practice for **local development and bootstrapping**. 
* When you run `gcloud auth login`, it opens a browser and grants your laptop a short-lived OAuth token tied to your personal Google account. 
* OpenTofu uses this temporary token to create the initial infrastructure. 

**For CI/CD (GitHub Actions):** We will use a standard Service Account JSON Key for this MVP. (Note: In a more advanced organizational setup, you would eventually upgrade to Workload Identity Federation (WIF) to avoid storing JSON keys, but a JSON key is perfect and standard for a standalone MVP).

---

## Step 0: Installations & Finding Your IDs

Before running any commands, you need the right tools installed and you need to know your specific Google Cloud IDs.

### 0A. Install the Required Tools
If you are using Windows PowerShell, use the `winget` commands. If you are using **WSL (Ubuntu)**, use the `snap` and `apt` commands. You must install the tools in the exact environment where you plan to run them!

**1. Google Cloud CLI (`gcloud`) — REQUIRED**
You need this to log into GCP and create the initial state bucket.
* **Windows (PowerShell):** `winget install Google.CloudSDK` *(Close and reopen terminal after)*
* **WSL (Ubuntu):** `sudo snap install google-cloud-cli --classic`

**2. OpenTofu (`tofu`) — REQUIRED**
You need this to provision the infrastructure.
* **Windows (PowerShell):** `winget install OpenTofu.OpenTofu`
* **WSL (Ubuntu):** `sudo snap install opentofu --classic`

**3. GitHub CLI (`gh`) — OPTIONAL**
This makes creating the GitHub repo slightly faster. You can skip this and create the repo manually on GitHub.com.
* **Windows (PowerShell):** `winget install GitHub.cli`
* **WSL (Ubuntu):** 
  ```bash
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && sudo apt update \
  && sudo apt install gh -y
  ```

### 0B. Find your GCP Project ID
1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Click the project dropdown at the very top left (next to the Google Cloud logo).
3. Look at the **ID** column. It usually looks something like `my-project-123456`.
*Note: The ID is often different from the Project Name.*

---

## Step 1: Prepare GCP & the Tofu State Bucket

OpenTofu needs a place to store its state file *before* it can create anything else. You must create this bucket manually.

Open your terminal (PowerShell, Command Prompt, or WSL Terminal) and run:

```bash
# 1. Login to GCP for standard gcloud commands
gcloud auth login

# 1B. VERY IMPORTANT: Generate Application Default Credentials for OpenTofu
# OpenTofu specifically requires these credentials to connect to the state bucket.
gcloud auth application-default login

# 2. Tell gcloud which project to use
# REPLACE "YOUR_GCP_PROJECT_ID" with the ID you found in Step 0B.
gcloud config set project YOUR_GCP_PROJECT_ID

# 3. Create the OpenTofu state bucket manually.
# REPLACE "YOUR_GCP_PROJECT_ID" with your actual project ID.
gcloud storage buckets create gs://YOUR_GCP_PROJECT_ID-tofu-state \
  --location=US \
  --uniform-bucket-level-access
```

---

## Step 2: Provision Infrastructure via OpenTofu

Now that the state bucket exists, you use OpenTofu to read the `main.tf` file we wrote. This will automatically create the data buckets, targets cache bucket, and the pipeline Service Account.

**CRITICAL: Update the files with your Project ID**
Before running OpenTofu, you MUST tell it what your actual Project ID is (otherwise it looks for my placeholder bucket and fails with a 404 Error).
1. Open `phase-5/infra/tofu/backend.tf` in a text editor. Change `"r-analytics-platform-tofu-state"` to the exact bucket name you just created in Step 1.
2. Open `phase-5/infra/tofu/main.tf` in a text editor. On line 16, change `project = "r-analytics-platform"` to your actual GCP Project ID.

```bash
# 1. Navigate to the infrastructure folder in your project
cd phase-5/infra/tofu

# 2. Initialize OpenTofu (connects to the state bucket you just made)
tofu init

# 3. Apply the infrastructure.
tofu apply -auto-approve
```

---

## Step 3: Generate the Service Account Key

Tofu just created a Service Account for your pipeline. Now, you need to generate a JSON key for it so GitHub Actions can log in.

```bash
# Generate the JSON key and save it locally as key.json
# REPLACE "YOUR_GCP_PROJECT_ID" with your actual project ID.
gcloud iam service-accounts keys create key.json \
  --iam-account=YOUR_GCP_PROJECT_ID-pipeline@YOUR_GCP_PROJECT_ID.iam.gserviceaccount.com
```
*(Keep this `key.json` file safe and NEVER commit it to git! We will copy its contents to GitHub in Step 5, and then you can delete the file from your computer).*

---

## Step 4: GitHub Repository Setup

You need to push your code to a new GitHub repository so GitHub Actions can take over.

```bash
# Navigate back to the root of phase-5
cd ../../

# IMPORTANT: Generate the R package lockfile
# Open an R console and run: renv::snapshot()
# This creates renv.lock so GitHub Actions knows what packages to install.
Rscript -e "renv::snapshot()"

# Initialize git and push to a new repo
git init
git add .
git commit -m "Initial Phase 5 commit"

# Create the repo on GitHub (requires GitHub CLI)
# REPLACE "YOUR_REPO_NAME" with what you want to call the repo.
gh repo create YOUR_REPO_NAME --public --source=. --remote=origin --push
```

---

## Step 5: Configure GitHub Variables & Secrets

GitHub Actions needs to know the names of the resources OpenTofu just created, and it needs the JSON key you generated in Step 3.

1. Go to your repository on GitHub.com.
2. Click **Settings** (the gear icon).
3. On the left sidebar, expand **Secrets and variables** -> click **Actions**.

**A. Create the Secret (The Key)**
1. Click the **Secrets** tab.
2. Click **New repository secret**.
3. Name: `GCP_CREDENTIALS`
4. Value: Open the `key.json` file you generated in Step 3 in a text editor, copy all of the text, and paste it here.

**B. Create the Variables (The Config)**
1. Click the **Variables** tab (next to Secrets).
2. Click **New repository variable** and add these 3 variables:

* `GCS_DATA_BUCKET` = `YOUR_GCP_PROJECT_ID-data`
* `GCS_TARGETS_BUCKET` = `YOUR_GCP_PROJECT_ID-targets`
* `GCP_STATE_BUCKET` = `YOUR_GCP_PROJECT_ID-tofu-state`

---

## Step 6: Enable GitHub Pages

Tell GitHub to allow deployments via GitHub Actions instead of trying to read HTML files directly from a branch.

1. In your GitHub repo, go to **Settings** -> **Pages**.
2. Under "Build and deployment", change the Source dropdown to **GitHub Actions**.

---

## Step 7: Trigger the Pipeline!

Everything is now wired up securely.

1.  **Wait for the Docker Environment to Build**: Since we use a Dockerized workflow, GitHub needs to build and push your environment image to the GitHub Container Registry (GHCR) first.
    *   Go to the **Actions** tab.
    *   Find the **Build and Push Docker Environment** workflow.
    *   If it is running, wait for it to finish (this happens automatically on your first push).
2.  **Run the Pipeline**: Once the Docker image is ready, the main pipeline can run.
    *   Select the **Pipeline + Deploy** workflow on the left.
    *   Click the **Run workflow** dropdown on the right, and click the green button.

**What happens next?**
*   GitHub Actions pulls your custom R/Quarto image from **GHCR**.
*   The pipeline runs inside that container, processes data via DuckDB/Arrow, and caches `targets`.
*   Results upload to your GCP buckets.
*   The website renders and deploys to your public GitHub Pages URL!


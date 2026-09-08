# GCP Patching, Runbook (Code-First)

The `gcp/` configuration is complete and CI-validated, but **not applied**, the project has no GCP account yet. This runbook turns it
live in one sitting once the account exists.

## Why code-first?

`terraform validate` (with `-backend=false`) runs in CI on every PR with **no
credentials**, proving the configuration is deploy-ready at all times. When
the account arrives there is no code work left, only apply + evidence
capture. The README states this instead of hiding it.

## When the GCP account exists

### 1. One-time setup

```bash
gcloud auth application-default login
gcloud config set project <PROJECT_ID>

# Enable the services Terraform needs (or let a bootstrap step do it):
gcloud services enable \
  compute.googleapis.com \
  osconfig.googleapis.com

# Create the state bucket (globally unique):
gsutil mb -l asia-southeast1 gs://your-state-bucket-gcp
gsutil versioning set on gs://your-state-bucket-gcp
```

### 2. Apply

```bash
cd gcp
cp backend.tf.example backend.tf              # remote state; skip for local state
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars  # set gcp_project_id
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

### 3. Demo session

```bash
# enable_demo_vms = true in terraform.tfvars
terraform apply
```

- Debian 13 `e2-micro` + Windows Core 2025 `e2-small` are created with labels
  `patch-group = demo` + `os` + `os_version`, attached to the business-hours
  instance schedule.
- Patch deployments run monthly (first Sunday 03:00 Jakarta), for the demo,
  run one on demand. Patch jobs only reach **running** VMs: the business-hours
  schedule stops the fleet at 18:00, so run this during business hours (or
  temporarily disable the schedule).

- Before the first patch job, confirm the OS Config agent is reporting — the
  first inventory can take ~10 minutes after boot, and a job started earlier
  reports `NO_AGENT_DETECTED`:

```bash
gcloud compute os-config inventories list \
  --location=asia-southeast1-a
```

  Both VMs must appear. Then dry-run:

```bash
gcloud compute os-config patch-jobs execute \
  --instance-filter-group-labels=patch-group=demo \
  --duration=1h --dry-run
```

- Evidence: **Compute Engine to VM Manager to Patch jobs** (job history + per-VM
  status), **OS Inventory** (installed packages), instance schedule stopping
  the fleet after hours.

### 4. Tear down

```bash
terraform apply -var='enable_demo_vms=false'    # keep the deployments (free)
```

## CI activation

Set these **repository variables** in GitHub (no secrets, WIF handles auth):

| Variable | Example |
|----------|---------|
| `GCP_PROJECT_ID` | `my-gcp-project` |
| `GCP_WIF_PROVIDER` | `projects/<id>/locations/global/workloadIdentityPools/gha/providers/gha` |
| `GCP_WIF_SA` | `patch-ci@<project>.iam.gserviceaccount.com` |
| `GCP_STATE_BUCKET` | `your-state-bucket-gcp` |

The `gcp` job in `terraform-ci.yml` currently self-skips (gated on
`vars.GCP_PROJECT_ID != ''`); setting these variables lights it up. The WIF
pool, provider, and service account are provisioned by your GCP foundation
platform (e.g. a shared platform repo), not by this module.

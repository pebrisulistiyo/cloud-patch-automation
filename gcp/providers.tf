# ---------------------------------------------------------------------------
# Google provider: one project, one region. Auth comes from the environment —
# gcloud application-default login locally, Workload Identity Federation in
# CI — no credentials live in this repo.
# ---------------------------------------------------------------------------

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

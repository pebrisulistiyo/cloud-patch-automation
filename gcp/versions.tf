terraform {
  required_version = ">= 1.15"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }

  # CODE-FIRST: this configuration is fully written but not applied yet.
  # There is no GCP account on the project today. When the account exists:
  #   1. Create the GCS state bucket (backend.hcl.example).
  #   2. terraform init -backend-config=backend.hcl
  #   3. terraform apply  (see docs/gcp-patching.md runbook)
  # Until then, CI proves deploy-readiness with `terraform init -backend=false
  # && terraform validate`, no credentials required.
  backend "gcs" {}
}

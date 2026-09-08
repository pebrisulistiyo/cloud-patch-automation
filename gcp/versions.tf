terraform {
  required_version = ">= 1.15"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }

  # CODE-FIRST: written and CI-validated before the GCP account existed, so
  # CI proves deploy-readiness with `terraform init -backend=false &&
  # terraform validate`, no credentials required. Without backend.tf, state
  # stays local (gcp/terraform.tfstate); apply steps live in
  # docs/gcp-patching.md.
}

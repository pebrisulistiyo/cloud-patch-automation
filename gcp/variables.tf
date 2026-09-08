# ---------------------------------------------------------------------------
# Inputs. Env-specific values (project id) and policy knobs (patch group,
# time zone) are variables, so deploying to another project or a real prod
# fleet is a tfvars edit, not a code change.
# ---------------------------------------------------------------------------

variable "gcp_project_id" {
  description = "GCP project these resources live in."
  type        = string

  validation {
    condition     = length(trimspace(var.gcp_project_id)) > 0
    error_message = "gcp_project_id must not be empty."
  }
}

variable "gcp_region" {
  description = "GCP region for all resources. Mirrors the AWS region (Singapore)."
  type        = string
  default     = "asia-southeast1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+\\d$", var.gcp_region))
    error_message = "gcp_region must look like a region name, e.g. asia-southeast1."
  }
}

variable "enable_demo_vms" {
  description = "Create the Linux + Windows demo instances. Default false: VMs cost money, the instance schedule stops them outside business hours, and destroy after demo sessions."
  type        = bool
  default     = false
}

variable "patch_group" {
  description = "Patch group label; GCE instances with label patch-group = this value are covered by the patch deployments."
  type        = string
  default     = "demo"
}

variable "patch_time_zone" {
  description = "IANA time zone the patch deployments and instance schedule run in."
  type        = string
  default     = "Asia/Jakarta"
}

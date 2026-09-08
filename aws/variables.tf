variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ap-southeast-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d$", var.aws_region))
    error_message = "aws_region must look like a region code, e.g. ap-southeast-1."
  }
}

variable "enable_demo_vms" {
  description = "Create the Linux + Windows demo instances. Default false: VMs cost money 24/7, flip this on only for demo sessions, destroy afterwards."
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Email that receives patch-compliance change alerts (SNS subscription)."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be a valid email address."
  }
}

variable "patch_group" {
  description = "Patch group value; instances tagged 'Patch Group' = this value are patched by the maintenance windows."
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z0-9-]{1,50}$", var.patch_group))
    error_message = "patch_group must be lowercase alphanumeric with dashes (max 50 chars)."
  }
}

variable "scan_cron" {
  description = "Cron for the weekly patch-scan maintenance window (AWS cron syntax, local time)."
  type        = string
  default     = "cron(0 3 ? * SAT *)"
}

variable "install_cron" {
  description = "Cron for the monthly patch-install maintenance window (AWS cron syntax, local time)."
  type        = string
  default     = "cron(0 4 1 * ? *)"
}

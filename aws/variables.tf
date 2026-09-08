variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d$", var.aws_region))
    error_message = "aws_region must look like a region code, e.g. us-east-1."
  }
}

variable "enable_demo_vms" {
  description = "Create the Linux + Windows demo instances. Off by default; enable only for demo sessions and destroy afterwards."
  type        = bool
  default     = false
}

variable "enable_spot" {
  description = "Run the demo VMs on Spot (~60-70% cheaper, price capped at on-demand). Set false for on-demand instances."
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address that receives patch-compliance change alerts (SNS subscription)."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be a valid email address."
  }
}

variable "patch_group" {
  description = "Prefix for patch groups; each OS version gets its own group (<prefix>-<os>-<version>)."
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z0-9-]{1,50}$", var.patch_group))
    error_message = "patch_group must be lowercase alphanumeric with dashes (max 50 chars)."
  }
}

variable "linux_ami" {
  description = "Amazon Linux AMI for the demo VM: a name pattern plus the version tag (e.g. version = \"2023\")."
  type = object({
    name_pattern = string
    version      = string
  })
  default = {
    name_pattern = "al2023-ami-2023.*-x86_64"
    version      = "2023"
  }

  validation {
    condition     = can(regex("^\\d{4}$", var.linux_ami.version))
    error_message = "linux_ami.version must be a 4-digit year, e.g. \"2023\"."
  }
}

variable "windows_ami" {
  description = "Windows Server AMI for the demo VM: a name pattern plus the version tag (e.g. version = \"2025\")."
  type = object({
    name_pattern = string
    version      = string
  })
  default = {
    name_pattern = "Windows_Server-2025-English-Full-Base-*"
    version      = "2025"
  }

  validation {
    condition     = can(regex("^\\d{4}$", var.windows_ami.version))
    error_message = "windows_ami.version must be a 4-digit year, e.g. \"2016\"."
  }
}

variable "scan_cron" {
  description = "Cron for the weekly patch-scan maintenance window (AWS cron syntax, UTC)."
  type        = string
  default     = "cron(0 3 ? * SAT *)"
}

variable "install_cron" {
  description = "Cron for the monthly patch-install maintenance window (AWS cron syntax, UTC)."
  type        = string
  default     = "cron(0 4 1 * ? *)"
}

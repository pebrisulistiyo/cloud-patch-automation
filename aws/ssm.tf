# ---------------------------------------------------------------------------
# Patch baselines: what gets approved, and how quickly.
# ---------------------------------------------------------------------------

# Linux: approve Critical/Important security patches after a 3-day soak period.
# The delay is deliberate, if AWS pulls a bad patch, the fleet never sees it.
resource "aws_ssm_patch_baseline" "linux" {
  name             = "linux-security-critical"
  description      = "Amazon Linux 2023: Critical/Important security patches, 3-day approval delay."
  operating_system = "AMAZON_LINUX_2023"

  approval_rule {
    approve_after_days  = 3
    enable_non_security = false

    patch_filter {
      key    = "CLASSIFICATION"
      values = ["CriticalUpdates", "SecurityUpdates"]
    }
    patch_filter {
      key    = "SEVERITY"
      values = ["Critical", "Important"]
    }
  }

  approved_patches_compliance_level = "CRITICAL"
}

# Windows: same 3-day soak, plus UpdateRollups (Windows delivers many fixes as
# monthly rollups rather than individual patches).
resource "aws_ssm_patch_baseline" "windows" {
  name             = "windows-security-updates"
  description      = "Windows Server 2022: Critical/Important security updates + rollups, 3-day approval delay."
  operating_system = "WINDOWS"

  approval_rule {
    approve_after_days = 3

    patch_filter {
      key    = "CLASSIFICATION"
      values = ["CriticalUpdates", "SecurityUpdates", "UpdateRollups"]
    }
    patch_filter {
      key    = "SEVERITY"
      values = ["Critical", "Important"]
    }
  }

  approved_patches_compliance_level = "CRITICAL"
}

# Both baselines serve the same patch group. Patch Manager picks the baseline
# that matches each instance's OS, so one group covers the mixed fleet.
resource "aws_ssm_patch_group" "linux" {
  baseline_id = aws_ssm_patch_baseline.linux.id
  patch_group = var.patch_group
}

resource "aws_ssm_patch_group" "windows" {
  baseline_id = aws_ssm_patch_baseline.windows.id
  patch_group = var.patch_group
}

# ---------------------------------------------------------------------------
# Maintenance windows: when patching actually runs.
# ---------------------------------------------------------------------------

resource "aws_ssm_maintenance_window" "scan" {
  name                       = "weekly-patch-scan"
  schedule                   = var.scan_cron
  duration                   = 2
  cutoff                     = 1
  allow_unassociated_targets = false
}

resource "aws_ssm_maintenance_window" "install" {
  name                       = "monthly-patch-install"
  schedule                   = var.install_cron
  duration                   = 3
  cutoff                     = 1
  allow_unassociated_targets = false
}

# Both windows target instances carrying the patch-group tag.
resource "aws_ssm_maintenance_window_target" "scan" {
  window_id     = aws_ssm_maintenance_window.scan.id
  name          = "patch-group-${var.patch_group}"
  resource_type = "INSTANCE"

  targets {
    key    = "tag:${local.patch_group_tag_key}"
    values = [var.patch_group]
  }
}

resource "aws_ssm_maintenance_window_target" "install" {
  window_id     = aws_ssm_maintenance_window.install.id
  name          = "patch-group-${var.patch_group}"
  resource_type = "INSTANCE"

  targets {
    key    = "tag:${local.patch_group_tag_key}"
    values = [var.patch_group]
  }
}

# ---------------------------------------------------------------------------
# Maintenance window tasks: the AWS-RunPatchBaseline document, twice.
# ---------------------------------------------------------------------------

resource "aws_ssm_maintenance_window_task" "scan" {
  window_id       = aws_ssm_maintenance_window.scan.id
  name            = "run-patch-baseline-scan"
  task_type       = "RUN_COMMAND"
  task_arn        = "AWS-RunPatchBaseline"
  priority        = 1
  max_concurrency = "100%"
  max_errors      = "100%"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.scan.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      parameter {
        name   = "Operation"
        values = ["Scan"]
      }
      parameter {
        name   = "RebootOption"
        values = ["NoReboot"]
      }
    }
  }
}

resource "aws_ssm_maintenance_window_task" "install" {
  window_id       = aws_ssm_maintenance_window.install.id
  name            = "run-patch-baseline-install"
  task_type       = "RUN_COMMAND"
  task_arn        = "AWS-RunPatchBaseline"
  priority        = 1
  max_concurrency = "50%" # one instance at a time is overkill for a demo; prod would stagger by service
  max_errors      = "0%"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.install.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      parameter {
        name   = "Operation"
        values = ["Install"]
      }
      parameter {
        name   = "RebootOption"
        values = ["RebootIfNeeded"]
      }
    }
  }
}

# Weekly software inventory, feeds Patch Manager's compliance dashboards and
# the resource data sync export (reporting.tf).
resource "aws_ssm_association" "inventory" {
  name                = "AWS-GatherSoftwareInventory"
  association_name    = "weekly-software-inventory"
  schedule_expression = "cron(0 0 ? * SUN *)"

  targets {
    key    = "tag:${local.patch_group_tag_key}"
    values = [var.patch_group]
  }
}

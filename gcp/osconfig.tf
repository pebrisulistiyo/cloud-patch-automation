# ---------------------------------------------------------------------------
# VM Manager patch deployments: the GCP counterpart of SSM Patch Manager.
# Monthly recurring deployments, scoped to the demo patch-group label.
# ---------------------------------------------------------------------------

# Debian: dist-level upgrade of packages, first Sunday of the month at 03:00.
resource "google_os_config_patch_deployment" "linux" {
  patch_deployment_id = "linux-monthly"
  description         = "Monthly patches for Debian demo VMs (apt)."

  instance_filter {
    group_labels {
      labels = { "patch-group" = var.patch_group }
    }
  }

  patch_config {
    reboot_config = "DEFAULT"

    apt {
      type = "DIST"
    }
  }

  recurring_schedule {
    time_zone {
      id = var.patch_time_zone
    }
    time_of_day {
      hours   = 3
      minutes = 0
    }
    # frequency is inferred from the monthly block below
    monthly {
      week_day_of_month {
        week_ordinal = 1
        day_of_week  = "SUNDAY"
        day_offset   = 0
      }
    }
  }

  duration = "3600s"
}

# Windows: critical + security + update rollups, same window.
resource "google_os_config_patch_deployment" "windows" {
  patch_deployment_id = "windows-monthly"
  description         = "Monthly critical/security/rollup updates for Windows demo VMs."

  instance_filter {
    group_labels {
      labels = { "patch-group" = var.patch_group }
    }
  }

  patch_config {
    reboot_config = "DEFAULT"

    windows_update {
      classifications = ["CRITICAL", "SECURITY", "UPDATE_ROLLUP"]
    }
  }

  recurring_schedule {
    time_zone {
      id = var.patch_time_zone
    }
    time_of_day {
      hours   = 3
      minutes = 30
    }
    # frequency is inferred from the monthly block below
    monthly {
      week_day_of_month {
        week_ordinal = 1
        day_of_week  = "SUNDAY"
        day_offset   = 0
      }
    }
  }

  duration = "7200s"
}

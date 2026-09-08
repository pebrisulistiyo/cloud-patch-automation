# ---------------------------------------------------------------------------
# VM Manager patch deployments: the GCP counterpart of SSM Patch Manager.
# Monthly recurring deployments, scoped to the demo patch-group label.
#
# Production decisions encoded here (Google's "Best practices for OS updates
# at scale"):
#   - ZONE_BY_ZONE rollout with a disruption budget of 1: one VM at a time,
#     and a failing VM consumes the budget until the patch job halts itself.
#   - reboot DEFAULT: the OS Config agent detects reboot-required signals
#     (/var/run/reboot-required, Windows registry) so kernel-level updates
#     take effect without forcing a monthly reboot. NEVER would leave patches
#     pending.
#   - Linux apt UPGRADE (apt-get upgrade): upgrade-only, never removes
#     packages. DIST (dist-upgrade) is for distro upgrades, not patching.
#   - Pre/post-patch scripts are the recommended safety net for app fleets
#     (quiesce before, health-check after; a failure marks the VM failed and
#     halts the rollout). Not wired here: the demo fleet runs no app.
# ---------------------------------------------------------------------------

# Debian: upgrade-only patching, first Sunday of the month at 03:00.
resource "google_os_config_patch_deployment" "linux" {
  patch_deployment_id = "linux-monthly"
  description         = "Monthly patches for Debian demo VMs (apt)."

  # All labels in a group must match, so this deployment only ever reaches
  # the Linux fleet, never the Windows one.
  instance_filter {
    group_labels {
      labels = {
        "patch-group" = var.patch_group
        "os"          = "linux"
      }
    }
  }

  patch_config {
    # The agent decides (see header). DEFAULT is what every Google doc
    # example uses; NEVER is the anti-pattern.
    reboot_config = "DEFAULT"

    apt {
      type = "UPGRADE"
    }
  }

  # One VM at a time. A VM counts as disrupted until patching (incl.
  # reboot) completes; failures consume the budget, so with a budget of 1
  # a single failed VM stops the patch job for the zone instead of the
  # fleet continuing onto a broken patch.
  rollout {
    mode = "ZONE_BY_ZONE"

    disruption_budget {
      fixed = 1
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
    monthly {
      week_day_of_month {
        week_ordinal = 1
        day_of_week  = "SUNDAY"
        day_offset   = 0
      }
    }
  }

  # 03:00 Sunday is outside the business-hours instance schedule, so VMs
  # stopped by that schedule are skipped (stopped VMs do not count toward
  # the disruption budget). That is by design for the cost-guardrail demo
  # fleet: prod fleets run during their maintenance window, and the demo
  # fleet patches on demand during business hours (see docs/gcp-patching.md).
  duration = "3600s"
}

# Windows: critical + security + update rollups, same window.
resource "google_os_config_patch_deployment" "windows" {
  patch_deployment_id = "windows-monthly"
  description         = "Monthly critical/security/rollup updates for Windows demo VMs."

  instance_filter {
    group_labels {
      labels = {
        "patch-group" = var.patch_group
        "os"          = "windows"
      }
    }
  }

  patch_config {
    reboot_config = "DEFAULT"

    windows_update {
      classifications = ["CRITICAL", "SECURITY", "UPDATE_ROLLUP"]
    }
  }

  rollout {
    mode = "ZONE_BY_ZONE"

    disruption_budget {
      fixed = 1
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

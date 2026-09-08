# Demo fleet, opt-in only (var.enable_demo_vms). One Debian + one Windows
# Core instance, both labeled for the patch deployments above.
#
# Windows GCE VMs are the biggest cost risk in this project (~$45-50/mo
# running 24/7), so an instance schedule stops the fleet outside business
# hours and on weekends. This is the GCP-native cost guardrail.

data "google_compute_image" "debian" {
  family  = "debian-13"
  project = "debian-cloud"
}

data "google_compute_image" "windows_core" {
  family  = "windows-2025-core"
  project = "windows-cloud"
}

# Start Mon-Fri 07:30, stop 18:00, Jakarta time. Outside that window the VMs
# are stopped and cost nothing (persistent disks still bill, pennies).
resource "google_compute_resource_policy" "business_hours" {
  name   = "business-hours"
  region = var.gcp_region

  instance_schedule_policy {
    vm_start_schedule {
      schedule = "30 7 * * 1-5"
    }
    vm_stop_schedule {
      schedule = "0 18 * * 1-5"
    }
    time_zone = var.patch_time_zone
  }
}

resource "google_compute_instance" "demo_linux" {
  count = var.enable_demo_vms ? 1 : 0

  name         = "patch-demo-linux"
  machine_type = "e2-micro"
  zone         = "${var.gcp_region}-a"

  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
      size  = 20
    }
  }

  # No external IP: OS Config agent reaches patch jobs outbound. Access is
  # via the GCP console / gcloud, not SSH keys.
  network_interface {
    network = "default"
  }

  labels = { "patch-group" = var.patch_group }

  resource_policies = [google_compute_resource_policy.business_hours.self_link]
}

resource "google_compute_instance" "demo_windows" {
  count = var.enable_demo_vms ? 1 : 0

  name         = "patch-demo-windows"
  machine_type = "e2-small" # smallest Windows-capable shared-core type
  zone         = "${var.gcp_region}-a"

  boot_disk {
    initialize_params {
      image = data.google_compute_image.windows_core.self_link
      size  = 50
    }
  }

  network_interface {
    network = "default"
  }

  labels = { "patch-group" = var.patch_group }

  resource_policies = [google_compute_resource_policy.business_hours.self_link]
}

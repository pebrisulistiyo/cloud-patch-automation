locals {
  common_tags = {
    Project   = "cloud-patch-automation"
    ManagedBy = "terraform"
  }

  # Patch Manager matches this tag key exactly ("Patch Group").
  patch_group_tag_key = "Patch Group"

  # Version-tracking tags applied to every instance.
  os_tag_key         = "os"
  os_version_tag_key = "os_version"

  # One patch group per OS version, e.g. demo-linux-2023, demo-windows-2025.
  patch_groups = {
    linux   = "${var.patch_group}-linux-${var.linux_ami.version}"
    windows = "${var.patch_group}-windows-${var.windows_ami.version}"
  }
}

locals {
  common_tags = {
    Project   = "cloud-patch-automation"
    ManagedBy = "terraform"
    Repo      = "cloud-patch-automation"
  }

  # Patch Manager groups instances by this tag (space is significant, it is
  # the tag key AWS's patch-group feature looks for).
  patch_group_tag_key = "Patch Group"
}

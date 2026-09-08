# ---------------------------------------------------------------------------
# Outputs: what to point at in the console and the runbook when proving the
# deployments exist and the demo fleet is covered.
# ---------------------------------------------------------------------------

output "patch_deployments" {
  description = "VM Manager patch deployment IDs, one per OS family."
  value = {
    linux   = google_os_config_patch_deployment.linux.patch_deployment_id
    windows = google_os_config_patch_deployment.windows.patch_deployment_id
  }
}

output "instance_schedule" {
  description = "Resource policy that stops demo VMs outside business hours."
  value       = google_compute_resource_policy.business_hours.name
}

output "demo_instances" {
  description = "Demo instance self-links (empty unless enable_demo_vms = true)."
  value = {
    linux   = one(google_compute_instance.demo_linux[*].self_link)
    windows = one(google_compute_instance.demo_windows[*].self_link)
  }
}

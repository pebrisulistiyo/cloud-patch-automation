output "patch_baselines" {
  description = "Patch baseline IDs, one per OS family."
  value = {
    linux   = aws_ssm_patch_baseline.linux.id
    windows = aws_ssm_patch_baseline.windows.id
  }
}

output "patch_groups" {
  description = "Patch group values per OS family (one per OS version; instances are tagged 'Patch Group' with one of these)."
  value       = local.patch_groups
}

output "maintenance_windows" {
  description = "Maintenance window IDs for scan and install."
  value = {
    scan    = aws_ssm_maintenance_window.scan.id
    install = aws_ssm_maintenance_window.install.id
  }
}

output "compliance_bucket" {
  description = "S3 bucket receiving the Patch Manager resource data sync."
  value       = aws_s3_bucket.compliance.bucket
}

output "compliance_alert_topic" {
  description = "SNS topic that emits patch compliance change alerts."
  value       = aws_sns_topic.compliance.arn
}

output "demo_instance_ids" {
  description = "Demo instance IDs (empty unless enable_demo_vms = true)."
  value = {
    linux   = one(aws_instance.demo_linux[*].id)
    windows = one(aws_instance.demo_windows[*].id)
  }
}

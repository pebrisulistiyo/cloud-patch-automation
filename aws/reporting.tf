# ---------------------------------------------------------------------------
# Compliance reporting: export Patch Manager data to S3 + alert on changes.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "compliance" {
  bucket = "patch-compliance-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "compliance" {
  bucket = aws_s3_bucket.compliance.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "compliance" {
  bucket = aws_s3_bucket.compliance.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "compliance" {
  bucket = aws_s3_bucket.compliance.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Resource data sync: streams inventory + patch compliance records to S3 as
# JSON so they can be queried (Athena) or archived without the SSM console.
resource "aws_ssm_resource_data_sync" "compliance" {
  name = "patch-compliance-sync"

  s3_destination {
    bucket_name = aws_s3_bucket.compliance.bucket
    prefix      = "patch-compliance"
    region      = var.aws_region
    sync_format = "JsonSerDe"
  }
}

# ---------------------------------------------------------------------------
# Alerting: notify when an instance's patch compliance state changes.
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "compliance" {
  name = "patch-compliance-alerts"
}

resource "aws_sns_topic_policy" "compliance" {
  arn = aws_sns_topic.compliance.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action   = "sns:Publish"
      Resource = aws_sns_topic.compliance.arn
    }]
  })
}

resource "aws_sns_topic_subscription" "compliance_email" {
  topic_arn = aws_sns_topic.compliance.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_event_rule" "compliance_change" {
  name        = "patch-compliance-change"
  description = "Fires when an instance's patch compliance state changes."

  event_pattern = jsonencode({
    source      = ["aws.ssm"]
    detail-type = ["EC2 Patch Compliance State Change"]
  })
}

resource "aws_cloudwatch_event_target" "compliance_change" {
  rule = aws_cloudwatch_event_rule.compliance_change.name
  arn  = aws_sns_topic.compliance.arn
}

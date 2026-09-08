# Demo fleet, opt-in only (var.enable_demo_vms): one Linux + one Windows
# instance to prove the patch baselines across OS families.
#
# No SSH/RDP keys - instances are SSM-managed only (iam.tf). AMI lookups are
# gated on enable_demo_vms so infra-only applies need no ec2:DescribeImages.

data "aws_ami" "amazon_linux" {
  count = var.enable_demo_vms ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [var.linux_ami.name_pattern]
  }
}

data "aws_ami" "windows_server" {
  count = var.enable_demo_vms ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [var.windows_ami.name_pattern]
  }
}

resource "aws_instance" "demo_linux" {
  count = var.enable_demo_vms ? 1 : 0

  ami                  = data.aws_ami.amazon_linux[0].id
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.ssm.name

  dynamic "instance_market_options" {
    for_each = var.enable_spot ? [1] : []
    content {
      market_type = "spot"
    }
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name                        = "patch-demo-linux"
    (local.patch_group_tag_key) = local.patch_groups.linux
    (local.os_tag_key)          = "linux"
    (local.os_version_tag_key)  = var.linux_ami.version
  }
}

resource "aws_instance" "demo_windows" {
  count = var.enable_demo_vms ? 1 : 0

  ami                  = data.aws_ami.windows_server[0].id
  instance_type        = "t3.small"
  iam_instance_profile = aws_iam_instance_profile.ssm.name

  dynamic "instance_market_options" {
    for_each = var.enable_spot ? [1] : []
    content {
      market_type = "spot"
    }
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name                        = "patch-demo-windows"
    (local.patch_group_tag_key) = local.patch_groups.windows
    (local.os_tag_key)          = "windows"
    (local.os_version_tag_key)  = var.windows_ami.version
  }
}

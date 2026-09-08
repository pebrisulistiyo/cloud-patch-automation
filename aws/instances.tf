# Demo fleet, opt-in only (var.enable_demo_vms). One Linux + one Windows
# instance to prove the patch baselines work across OS families.
#
# Both are SSM-managed: no SSH/RDP key pairs, no public exposure. Patch tasks
# reach the agent outbound, and humans can use SSM Session Manager.

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

data "aws_ami" "windows_server_2025" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2025-English-Full-Base-*"]
  }
}

resource "aws_instance" "demo_linux" {
  count = var.enable_demo_vms ? 1 : 0

  ami                  = data.aws_ami.amazon_linux_2023.id
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.ssm.name

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name                        = "patch-demo-linux"
    (local.patch_group_tag_key) = var.patch_group
  }
}

resource "aws_instance" "demo_windows" {
  count = var.enable_demo_vms ? 1 : 0

  ami                  = data.aws_ami.windows_server_2025.id
  instance_type        = "t3.small"
  iam_instance_profile = aws_iam_instance_profile.ssm.name

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name                        = "patch-demo-windows"
    (local.patch_group_tag_key) = var.patch_group
  }
}

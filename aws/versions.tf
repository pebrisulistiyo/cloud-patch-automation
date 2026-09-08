terraform {
  required_version = ">= 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State lives in the shared portfolio bucket (created once by hand, see
  # terraform-bootstrap). bucket + region come from -backend-config=backend.hcl.
  backend "s3" {
    key          = "cloud-patch-automation/aws/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

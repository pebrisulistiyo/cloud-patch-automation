terraform {
  required_version = ">= 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Local state by default (aws/terraform.tfstate), so the stack runs with
  # no S3 bucket. For remote state (CI): cp backend.tf.example backend.tf,
  # then terraform init -backend-config=backend.hcl.
}

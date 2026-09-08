.PHONY: fmt lint validate plan-aws plan-gcp

fmt:
	terraform fmt -recursive

lint:
	tflint --chdir=aws
	tflint --chdir=gcp

validate:
	cd aws && terraform init -backend=false -input=false && terraform validate
	cd gcp && terraform init -backend=false -input=false && terraform validate

plan-aws:
	cd aws && cp backend.tf.example backend.tf && terraform init -backend-config=backend.hcl && terraform plan

plan-gcp:
	cd gcp && cp backend.tf.example backend.tf && terraform init -backend-config=backend.hcl && terraform plan

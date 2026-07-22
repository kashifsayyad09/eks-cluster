# Usage: terraform init -backend-config=env/prod/backend.hcl
bucket       = "qwertsgitlabinfra"
key          = "eks/prod/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true

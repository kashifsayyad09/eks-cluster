# Usage: terraform init -backend-config=env/qa/backend.hcl
bucket       = "qwertsgitlabinfra"
key          = "eks/qa/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true

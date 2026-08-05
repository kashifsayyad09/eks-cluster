# Usage: terraform init -backend-config=env/dev/backend.hcl
bucket       = "qwertsgitlabinfraa"
key          = "eks/dev/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true

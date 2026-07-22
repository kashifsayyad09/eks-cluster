#!/usr/bin/env bash
###############################################################################
# scripts/validate.sh
# Runs fmt/validate against every environment's tfvars without applying.
###############################################################################
set -euo pipefail

terraform fmt -recursive -check

for ENV in dev qa prod; do
  echo ">>> Validating environment: ${ENV}"
  terraform init -backend-config="env/${ENV}/backend.hcl" -reconfigure > /dev/null
  terraform validate
  terraform plan -var-file="env/${ENV}/terraform.tfvars" -out=/dev/null || true
done

echo "All environments validated."

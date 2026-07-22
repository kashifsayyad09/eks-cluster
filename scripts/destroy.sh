#!/usr/bin/env bash
###############################################################################
# scripts/destroy.sh
# Usage: ./scripts/destroy.sh dev
###############################################################################
set -euo pipefail

ENV="${1:-dev}"

terraform init -backend-config="env/${ENV}/backend.hcl" -reconfigure
terraform destroy -var-file="env/${ENV}/terraform.tfvars"

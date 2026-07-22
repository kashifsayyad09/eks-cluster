#!/usr/bin/env bash
###############################################################################
# scripts/deploy.sh
#
# Full deployment pipeline for one environment.
# Usage: ./scripts/deploy.sh dev
###############################################################################
set -euo pipefail

ENV="${1:-dev}"

if [[ ! -f "env/${ENV}/backend.hcl" ]]; then
  echo "Unknown environment '${ENV}'. Expected env/${ENV}/backend.hcl to exist." >&2
  exit 1
fi

echo ">>> Verifying caller identity"
aws sts get-caller-identity

echo ">>> Formatting"
terraform fmt -recursive

echo ">>> Initializing backend for ${ENV}"
terraform init -backend-config="env/${ENV}/backend.hcl" -reconfigure

echo ">>> Validating"
terraform validate

echo ">>> Planning"
terraform plan -var-file="env/${ENV}/terraform.tfvars" -out="${ENV}.tfplan"

echo ">>> Applying"
terraform apply "${ENV}.tfplan"

CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

echo ">>> Updating kubeconfig"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}"

echo ">>> Cluster nodes"
kubectl get nodes -o wide

echo ">>> Done. Cluster '${CLUSTER_NAME}' is ready."

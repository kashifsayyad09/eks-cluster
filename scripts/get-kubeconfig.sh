#!/usr/bin/env bash
###############################################################################
# scripts/get-kubeconfig.sh
# Fetches kubeconfig and runs a basic cluster health check.
###############################################################################
set -euo pipefail

CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}"

echo ">>> cluster-info"
kubectl cluster-info

echo ">>> nodes"
kubectl get nodes

echo ">>> pods (all namespaces)"
kubectl get pods -A

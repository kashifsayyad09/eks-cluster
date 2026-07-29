#!/usr/bin/env bash
###############################################################################
# scripts/force-unlock.sh
#
# FIXES ERROR #6 from the CI troubleshooting log:
#   "Error acquiring the state lock ... S3: PutObject ... 412
#    PreconditionFailed"
#
# Cause: an S3 lock file was left behind by an earlier interrupted or
# overlapping Terraform run. This does NOT mean locking is broken - it
# means it's working as designed and caught a real conflict. The fix is
# to force-unlock the SPECIFIC lock ID (never routine, never automated in
# CI), not to disable use_lockfile.
#
# Usage: ./scripts/force-unlock.sh <env> <lock-id>
#   ./scripts/force-unlock.sh dev 563f6a95-0fd2-2d22-bbd1-ae12623edafc
#
# The lock ID is printed in the original "Error acquiring the state lock"
# message - copy it from there.
###############################################################################
set -euo pipefail

ENV="${1:?Usage: force-unlock.sh <env> <lock-id>}"
LOCK_ID="${2:?Usage: force-unlock.sh <env> <lock-id>}"

echo "About to force-unlock env/${ENV} state, lock ID: ${LOCK_ID}"
echo "Only do this if you have confirmed no other terraform plan/apply is currently running."
read -r -p "Continue? [y/N] " CONFIRM
if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]]; then
  echo "Aborted."
  exit 1
fi

terraform init -input=false -backend-config="env/${ENV}/backend.hcl" -reconfigure
terraform force-unlock -force "${LOCK_ID}"

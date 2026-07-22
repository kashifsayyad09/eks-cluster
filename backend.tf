###############################################################################
# backend.tf
#
# Remote state backend: Amazon S3.
#
# WHY S3-ONLY STATE LOCKING (NO DYNAMODB):
# ------------------------------------------------------------------------
# Classic Terraform AWS reference architectures pair an S3 backend with a
# DynamoDB table for state locking (one item per state file, acquired as a
# lock during apply/plan). The AWS Pluralsight Skills Sandbox intentionally
# restricts IAM: it does not grant `dynamodb:CreateTable` or broad
# `dynamodb:*` permissions on arbitrary resources, so provisioning a lock
# table is not possible inside the sandbox account.
#
# Terraform >= 1.10 solved this natively: the S3 backend supports
# `use_lockfile = true`, which places a `.tflock` companion object next to
# the state file in the SAME S3 bucket using S3's own conditional-write
# (If-None-Match) semantics for mutual exclusion. This gives you real
# locking - a concurrent `terraform apply` will fail fast instead of
# corrupting state - with zero DynamoDB dependency. Since this project
# pins Terraform >= 1.12, we use `use_lockfile` instead of a lock table.
#
# This file intentionally contains NO hardcoded values for bucket/key/region.
# Those are supplied per-environment via `-backend-config=env/<env>/backend.hcl`
# so the same root module can be initialized against dev, qa, and prod state
# files without editing code. See env/dev/backend.hcl for an example.
###############################################################################

terraform {
  backend "s3" {
    # bucket, key, region, encrypt, use_lockfile are all supplied via
    # -backend-config at `terraform init` time. Example:
    #
    #   terraform init -backend-config=env/dev/backend.hcl
  }
}

###############################################################################
# modules/github-oidc/main.tf
#
# FIXES ERROR #1 FROM THE CI TROUBLESHOOTING LOG:
#   "Could not assume role with OIDC: Not authorized to perform
#    sts:AssumeRoleWithWebIdentity"
#
# ROOT CAUSE: the IAM role's trust policy did not correctly match the
# GitHub-issued OIDC token's claims (audience + subject). This module
# builds that trust policy from first principles so every required
# condition is present and correct:
#
#   1. The IAM OIDC provider for token.actions.githubusercontent.com must
#      exist in the account, with the CORRECT thumbprint.
#   2. The role's trust policy must restrict `aud` (audience) to
#      "sts.amazonaws.com" - GitHub always sends this as the audience for
#      the official aws-actions/configure-aws-credentials action.
#   3. The role's trust policy must restrict `sub` (subject) to this
#      specific repo and an explicit set of allowed refs/branches/PR
#      contexts - never a bare wildcard "*" for the whole subject, which
#      would let ANY GitHub repo assume the role.
#
# GitHub's OIDC thumbprint is well-known and stable
# (sha1 fingerprint of DigiCert Global Root CA, per GitHub's published
# OIDC documentation) - Terraform still fetches it live via the tls
# provider so this module self-heals if GitHub ever rotates it.
###############################################################################

data "tls_certificate" "github" {
  count = var.create_oidc_provider ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github[0].certificates[0].sha1_fingerprint]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-github-oidc"
  })
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.existing_oidc_provider_arn

  # Builds the exact "repo:org/repo:ref:refs/heads/main" / "repo:org/repo:pull_request"
  # style subject strings GitHub's OIDC tokens present, for each allowed ref.
  allowed_subjects = [for ref in var.allowed_refs : "repo:${var.github_org}/${var.github_repo}:${ref}"]
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.allowed_subjects
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.name_prefix}-github-actions-terraform"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
  max_session_duration = 3600

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-github-actions-terraform"
  })
}

# -----------------------------------------------------------------------
# Permissions the CI role needs to run this exact Terraform project:
# VPC + IAM + security groups + EKS + node group + S3 + the S3 state
# backend itself. Scoped to the services this repo touches rather than
# AdministratorAccess - still broad within those services because
# Terraform needs to both create AND read-back nearly every resource
# type it manages, but no access to unrelated services (RDS, Lambda,
# billing, other accounts' resources, etc).
# -----------------------------------------------------------------------

data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid    = "TerraformStateBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::qwertsgitlabinfra",
      "arn:aws:s3:::qwertsgitlabinfra/*",
    ]
  }

  statement {
    sid    = "InfrastructureProvisioning"
    effect = "Allow"
    actions = [
      "ec2:*",
      "eks:*",
      "iam:*",
      "logs:*",
      "s3:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${var.name_prefix}-github-actions-terraform-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}

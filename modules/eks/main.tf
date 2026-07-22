###############################################################################
# modules/eks/main.tf
#
# WHY CloudWatch LOG GROUP IS CREATED EXPLICITLY BEFORE THE CLUSTER:
# ------------------------------------------------------------------------
# EKS auto-creates a log group named /aws/eks/<cluster>/cluster the first
# time control plane logging is enabled, BUT that auto-created group has no
# retention policy (logs never expire) and no tags. Declaring it explicitly
# lets Terraform own its lifecycle, set a retention period, and tag it -
# and guarantees `terraform destroy` actually cleans it up.
#
# WHY OIDC + IRSA:
# ------------------------------------------------------------------------
# Every EKS cluster gets an OIDC issuer URL. Registering that issuer as an
# IAM OIDC Identity Provider is what allows Kubernetes ServiceAccounts to
# assume IAM roles directly (IRSA - IAM Roles for Service Accounts)
# instead of nodes sharing one broad instance-profile role for every pod.
# This is the mechanism that lets, e.g., the AWS Load Balancer Controller
# or Cluster Autoscaler run with only the exact IAM permissions they need.
###############################################################################

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-cluster-logs"
  })
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [var.cluster_security_group_id]
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  enabled_cluster_log_types = var.cluster_log_types

  tags = merge(var.tags, {
    Name = var.cluster_name
  })

  depends_on = [aws_cloudwatch_log_group.cluster]
}

# -----------------------------------------------------------------------
# OIDC provider (enables IRSA)
# -----------------------------------------------------------------------

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-oidc"
  })
}

# -----------------------------------------------------------------------
# Example IRSA role: AWS Load Balancer Controller
#
# Demonstrates the IRSA pattern end-to-end. The trust policy restricts
# `sts:AssumeRoleWithWebIdentity` to a single, specific Kubernetes
# ServiceAccount (namespace + name) via the OIDC provider's `sub` claim -
# not to "any pod in the cluster."
# -----------------------------------------------------------------------

data "aws_iam_policy_document" "lb_controller_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lb_controller_irsa" {
  name               = "${var.name_prefix}-lb-controller-irsa"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-lb-controller-irsa"
  })
}

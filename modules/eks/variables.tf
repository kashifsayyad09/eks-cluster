variable "name_prefix" { type = string }
variable "cluster_name" { type = string }
variable "kubernetes_version" {
  type    = string
  default = null
}
variable "cluster_role_arn" { type = string }
variable "subnet_ids" {
  description = "Subnets the EKS control plane ENIs are placed in (private app subnets)."
  type        = list(string)
}
variable "cluster_security_group_id" { type = string }
variable "endpoint_private_access" { type = bool }
variable "endpoint_public_access" { type = bool }
variable "public_access_cidrs" { type = list(string) }
variable "cluster_log_types" { type = list(string) }
variable "cluster_log_retention_days" { type = number }

variable "authentication_mode" {
  description = <<-EOT
    EKS cluster authentication mode. API_AND_CONFIG_MAP keeps the legacy
    aws-auth ConfigMap working (for backward compatibility) while ALSO
    enabling native EKS access entries managed as Terraform resources
    (aws_eks_access_entry / aws_eks_access_policy_association below).

    Setting this explicitly - instead of leaving it unset - is what
    prevents the cluster from silently defaulting to CONFIG_MAP-only mode,
    which was the root cause of the "nodes is forbidden" / manual
    `aws eks update-cluster-config` troubleshooting step.
  EOT
  type    = string
  default = "API_AND_CONFIG_MAP"

  validation {
    condition     = contains(["API", "API_AND_CONFIG_MAP", "CONFIG_MAP"], var.authentication_mode)
    error_message = "authentication_mode must be one of: API, API_AND_CONFIG_MAP, CONFIG_MAP."
  }
}

variable "bootstrap_cluster_creator_admin_permissions" {
  description = "Automatically grant the IAM principal that RUNS `terraform apply` (e.g. the GitHub Actions OIDC role) cluster-admin access via an EKS access entry, with no manual step afterward."
  type        = bool
  default     = true
}

variable "admin_principal_arns" {
  description = <<-EOT
    Additional IAM principal ARNs (users or roles) to grant
    AmazonEKSClusterAdminPolicy at cluster scope via EKS access entries.
    This replaces the manual `aws eks associate-access-policy` step that
    was previously required for e.g. arn:...:user/cloud_user to run
    `kubectl get nodes` after the cluster came up.
  EOT
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

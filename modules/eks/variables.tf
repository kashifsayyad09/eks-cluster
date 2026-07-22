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
variable "tags" {
  type    = map(string)
  default = {}
}

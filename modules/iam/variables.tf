variable "name_prefix" { type = string }

variable "existing_cluster_role_name" {
  description = "If non-empty, reuse this existing IAM role instead of creating a new EKS cluster role."
  type        = string
  default     = ""
}

variable "existing_node_role_name" {
  description = "If non-empty, reuse this existing IAM role instead of creating a new EKS node group role."
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "name_prefix" { type = string }
variable "cluster_name" { type = string }
variable "node_role_arn" { type = string }
variable "subnet_ids" {
  description = "Private application subnets worker nodes launch into."
  type        = list(string)
}
variable "node_security_group_id" { type = string }
variable "instance_types" { type = list(string) }
variable "capacity_type" { type = string }
variable "disk_size_gb" { type = number }
variable "desired_size" { type = number }
variable "min_size" { type = number }
variable "max_size" { type = number }
variable "ssh_key_name" {
  type    = string
  default = ""
}
variable "cluster_dependency" {
  description = "Pass the eks module's cluster_name output here to force the node group to wait until the control plane is ACTIVE."
  type        = any
}
variable "tags" {
  type    = map(string)
  default = {}
}

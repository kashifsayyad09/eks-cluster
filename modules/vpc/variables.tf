variable "name_prefix" { type = string }
variable "vpc_cidr" { type = string }
variable "availability_zone_count" { type = number }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_app_subnet_cidrs" { type = list(string) }
variable "private_db_subnet_cidrs" { type = list(string) }
variable "single_nat_gateway" { type = bool }
variable "cluster_name" {
  description = "Used to build the shared kubernetes.io/cluster/<name> tag EKS needs to discover subnets."
  type        = string
}
variable "tags" {
  type    = map(string)
  default = {}
}

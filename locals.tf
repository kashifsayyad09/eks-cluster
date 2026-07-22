###############################################################################
# locals.tf
#
# Centralizes naming and tagging so every module derives the same
# `name_prefix` and the same base tag map instead of re-deriving it.
###############################################################################

locals {
  # e.g. "veera-dev"
  name_prefix = "${var.project_name}-${var.environment}"

  # Merged into (not replacing) each resource's specific tags.
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }

  # Split the /16 VPC CIDR into /20 subnets: enough address space per subnet
  # (4,091 usable hosts) for pod ENIs under the AWS VPC CNI, while leaving
  # headroom in the /16 for future subnet tiers.
  #   Public   subnets: first N /20s
  #   App      subnets: next N /20s
  #   Database subnets: next N /20s
  az_count = var.availability_zone_count

  public_subnet_cidrs = [
    for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 4, i)
  ]

  private_app_subnet_cidrs = [
    for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 4, i + local.az_count)
  ]

  private_db_subnet_cidrs = [
    for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 4, i + (local.az_count * 2))
  ]
}

###############################################################################
# main.tf (root)
#
# Composes every module in dependency order:
#
#   vpc  -->  security-groups  -->  iam
#                                     |
#                                     v
#                                    eks (cluster + OIDC)
#                                     |
#                                     v
#                                node-group
#
# plus an independent s3 module for application data.
###############################################################################

locals {
  cluster_name = "${local.name_prefix}-eks"
}

# -----------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------

module "vpc" {
  source = "./modules/vpc"

  name_prefix              = local.name_prefix
  vpc_cidr                 = var.vpc_cidr
  availability_zone_count  = var.availability_zone_count
  public_subnet_cidrs      = local.public_subnet_cidrs
  private_app_subnet_cidrs = local.private_app_subnet_cidrs
  private_db_subnet_cidrs  = local.private_db_subnet_cidrs
  single_nat_gateway       = var.single_nat_gateway
  cluster_name             = local.cluster_name
  tags                     = local.common_tags
}

# -----------------------------------------------------------------------
# Security groups
# -----------------------------------------------------------------------

module "security_groups" {
  source = "./modules/security-groups"

  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = module.vpc.vpc_cidr
  tags        = local.common_tags
}

# -----------------------------------------------------------------------
# IAM (cluster role + node role, reuse-if-exists pattern)
# -----------------------------------------------------------------------

module "iam" {
  source = "./modules/iam"

  name_prefix                 = local.name_prefix
  existing_cluster_role_name  = var.existing_cluster_role_name
  existing_node_role_name     = var.existing_node_role_name
  tags                        = local.common_tags
}

# -----------------------------------------------------------------------
# EKS control plane + OIDC + IRSA
# -----------------------------------------------------------------------

module "eks" {
  source = "./modules/eks"

  name_prefix                 = local.name_prefix
  cluster_name                = local.cluster_name
  kubernetes_version          = var.kubernetes_version
  cluster_role_arn            = module.iam.cluster_role_arn
  subnet_ids                  = module.vpc.private_app_subnet_ids
  cluster_security_group_id   = module.security_groups.cluster_security_group_id
  endpoint_private_access     = var.endpoint_private_access
  endpoint_public_access      = var.endpoint_public_access
  public_access_cidrs         = var.public_access_cidrs
  cluster_log_types           = var.cluster_log_types
  cluster_log_retention_days  = var.cluster_log_retention_days
  tags                        = local.common_tags
}

# -----------------------------------------------------------------------
# Managed node group
# -----------------------------------------------------------------------

module "node_group" {
  source = "./modules/node-group"

  name_prefix             = local.name_prefix
  cluster_name            = module.eks.cluster_name
  cluster_dependency      = module.eks.cluster_name
  node_role_arn           = module.iam.node_role_arn
  subnet_ids              = module.vpc.private_app_subnet_ids
  node_security_group_id  = module.security_groups.node_security_group_id
  instance_types          = var.node_instance_types
  capacity_type           = var.node_capacity_type
  disk_size_gb            = var.node_disk_size_gb
  desired_size            = var.node_desired_size
  min_size                = var.node_min_size
  max_size                = var.node_max_size
  ssh_key_name            = var.ssh_key_name
  tags                    = local.common_tags
}

# -----------------------------------------------------------------------
# Application S3 bucket
# -----------------------------------------------------------------------

module "s3" {
  source = "./modules/s3"
  count  = var.create_app_bucket ? 1 : 0

  name_prefix = local.name_prefix
  bucket_name = var.app_bucket_name
  account_id  = data.aws_caller_identity.current.account_id
  tags        = local.common_tags
}

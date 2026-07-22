###############################################################################
# outputs.tf (root)
###############################################################################

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Running Kubernetes version"
  value       = module.eks.cluster_version
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN (for IRSA role trust policies)"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL"
  value       = module.eks.oidc_provider_url
}

output "node_group_arn" {
  description = "Managed node group ARN"
  value       = module.node_group.node_group_arn
}

output "node_group_status" {
  description = "Managed node group status"
  value       = module.node_group.node_group_status
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "Private application (worker node) subnet IDs"
  value       = module.vpc.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "Private database subnet IDs"
  value       = module.vpc.private_db_subnet_ids
}

output "cluster_security_group_id" {
  description = "EKS control plane security group ID"
  value       = module.security_groups.cluster_security_group_id
}

output "node_security_group_id" {
  description = "EKS worker node security group ID"
  value       = module.security_groups.node_security_group_id
}

output "app_bucket_name" {
  description = "Application S3 bucket name (null if create_app_bucket = false)"
  value       = var.create_app_bucket ? module.s3[0].bucket_id : null
}

output "aws_region" {
  description = "Region this stack was deployed into"
  value       = var.aws_region
}

output "update_kubeconfig_command" {
  description = "Run this after apply to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

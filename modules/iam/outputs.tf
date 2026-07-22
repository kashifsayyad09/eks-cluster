locals {
  cluster_role_arn  = var.existing_cluster_role_name == "" ? aws_iam_role.cluster[0].arn : data.aws_iam_role.existing_cluster_role[0].arn
  cluster_role_name = var.existing_cluster_role_name == "" ? aws_iam_role.cluster[0].name : data.aws_iam_role.existing_cluster_role[0].name

  node_role_arn  = var.existing_node_role_name == "" ? aws_iam_role.node[0].arn : data.aws_iam_role.existing_node_role[0].arn
  node_role_name = var.existing_node_role_name == "" ? aws_iam_role.node[0].name : data.aws_iam_role.existing_node_role[0].name
}

output "cluster_role_arn" {
  value = local.cluster_role_arn
}

output "cluster_role_name" {
  value = local.cluster_role_name
}

output "node_role_arn" {
  value = local.node_role_arn
}

output "node_role_name" {
  value = local.node_role_name
}

output "node_instance_profile_name" {
  value = var.existing_node_role_name == "" ? aws_iam_instance_profile.node[0].name : null
}

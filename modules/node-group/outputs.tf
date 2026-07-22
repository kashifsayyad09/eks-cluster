output "node_group_arn" {
  value = aws_eks_node_group.this.arn
}

output "node_group_name" {
  value = aws_eks_node_group.this.node_group_name
}

output "node_group_status" {
  value = aws_eks_node_group.this.status
}

output "launch_template_id" {
  value = aws_launch_template.node.id
}

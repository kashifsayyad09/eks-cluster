###############################################################################
# modules/node-group/main.tf
#
# WHY A CUSTOM LAUNCH TEMPLATE:
# ------------------------------------------------------------------------
# `aws_eks_node_group` alone lets you set instance type and disk size
# directly, BUT it will NOT attach your own security group to the nodes -
# without a launch template, AWS creates a minimal default SG for the
# node group ENIs and you lose the least-privilege node SG built in
# modules/security-groups. Supplying a launch_template block is what lets
# this node group actually use `var.node_security_group_id`, and it also
# gives us a single place to set the 30 GiB root volume, enforce IMDSv2,
# and enable detailed tagging propagation to the underlying EC2 instances
# and their EBS volumes (useful for cost allocation reports).
###############################################################################

resource "aws_launch_template" "node" {
  name_prefix = "${var.name_prefix}-eks-node-"

  vpc_security_group_ids = [var.node_security_group_id]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.disk_size_gb
      volume_type            = "gp3"
      encrypted              = true
      delete_on_termination  = true
    }
  }

  # Enforce IMDSv2 (session-token-required) to close off the classic
  # SSRF-to-instance-credential-theft path.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  key_name = var.ssh_key_name != "" ? var.ssh_key_name : null

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-eks-node"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-eks-node-volume"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-node-lt"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = var.cluster_dependency
  node_group_name = "${var.name_prefix}-managed-ng"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids
  capacity_type   = var.capacity_type

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  instance_types = var.instance_types

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-managed-ng"
  })

  # Ignore desired_size drift caused by the Kubernetes Cluster Autoscaler
  # (or manual `kubectl scale`) so Terraform doesn't fight the autoscaler
  # on every plan.
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

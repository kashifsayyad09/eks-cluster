###############################################################################
# modules/iam/main.tf
#
# WHY "CHECK IF IT EXISTS, ELSE CREATE" IS IMPLEMENTED THIS WAY:
# ------------------------------------------------------------------------
# Terraform is declarative and evaluates its dependency graph at plan time;
# it cannot imperatively "try a data source, catch a not-found error, and
# fall back to a resource" the way a Python script could. The correct,
# idiomatic Terraform pattern for "reuse if it exists, otherwise create" is
# to let the CALLER tell you which mode to use via a variable:
#
#   - existing_cluster_role_name == ""   -> create a new role (count = 1
#     on the resource, count = 0 on the data source)
#   - existing_cluster_role_name != ""   -> look the role up with a data
#     source (count = 1 on the data source, count = 0 on the resource)
#
# A local then picks whichever ARN/name is actually populated. This is
# fully deterministic, shows up correctly in `terraform plan`, and avoids
# the anti-pattern of swallowing "not found" errors, which Terraform
# providers do not support cleanly.
###############################################################################

locals {
  create_cluster_role = var.existing_cluster_role_name == ""
  create_node_role     = var.existing_node_role_name == ""
}

# -----------------------------------------------------------------------
# EKS Cluster Role
# -----------------------------------------------------------------------

data "aws_iam_role" "existing_cluster_role" {
  count = local.create_cluster_role ? 0 : 1
  name  = var.existing_cluster_role_name
}

data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  count = local.create_cluster_role ? 1 : 0

  name               = "${var.name_prefix}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-cluster-role"
  })
}

# AmazonEKSClusterPolicy grants the control plane permission to manage
# ENIs, security groups, and load balancer resources on your behalf.
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  count      = local.create_cluster_role ? 1 : 0
  role       = aws_iam_role.cluster[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Required so the control plane can create/manage the ENIs used for the
# VPC CNI when running in a VPC with restrictive ENI trunking settings.
resource "aws_iam_role_policy_attachment" "cluster_vpc_resource_controller" {
  count      = local.create_cluster_role ? 1 : 0
  role       = aws_iam_role.cluster[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

# -----------------------------------------------------------------------
# EKS Managed Node Group Role
# -----------------------------------------------------------------------

data "aws_iam_role" "existing_node_role" {
  count = local.create_node_role ? 0 : 1
  name  = var.existing_node_role_name
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  count = local.create_node_role ? 1 : 0

  name               = "${var.name_prefix}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-node-role"
  })
}

# Lets kubelet register the node, manage its own ENIs, and report status.
resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  count      = local.create_node_role ? 1 : 0
  role       = aws_iam_role.node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# Lets the AWS VPC CNI plugin attach/detach ENIs and assign secondary IPs
# to pods running on the node.
resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  count      = local.create_node_role ? 1 : 0
  role       = aws_iam_role.node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Lets nodes pull container images from Amazon ECR.
resource "aws_iam_role_policy_attachment" "node_ecr_policy" {
  count      = local.create_node_role ? 1 : 0
  role       = aws_iam_role.node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Lets you shell into nodes via SSM Session Manager instead of opening SSH
# / bastion ingress rules - this is how the bastion-less troubleshooting
# workflow (aws ssm start-session) is possible.
resource "aws_iam_role_policy_attachment" "node_ssm_policy" {
  count      = local.create_node_role ? 1 : 0
  role       = aws_iam_role.node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "node" {
  count = local.create_node_role ? 1 : 0

  name = "${var.name_prefix}-eks-node-instance-profile"
  role = aws_iam_role.node[0].name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-node-instance-profile"
  })
}

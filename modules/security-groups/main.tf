###############################################################################
# modules/security-groups/main.tf
#
# WHY TWO SEPARATE SECURITY GROUPS, LEAST PRIVILEGE:
# ------------------------------------------------------------------------
# EKS needs bidirectional trust between the control plane ENIs and the
# worker nodes, but that trust should be scoped to exactly the ports each
# side needs - not "allow all" between them.
#
#   cluster SG (attached to the EKS-managed control plane ENIs):
#     ingress 443 from node SG   - kubelet/API aggregation layer and
#                                  webhooks call back to the API server.
#     egress  all                - control plane must reach nodes on
#                                  arbitrary ports (webhook services, etc).
#
#   node SG (attached to every worker node):
#     ingress 443  from cluster SG - nodes reach the API server.
#     ingress 10250 from cluster SG - kubelet API (metrics-server, exec,
#                                     logs, port-forward).
#     ingress all   from itself (self-referencing) - required for the VPC
#                                     CNI, CoreDNS, and any pod-to-pod
#                                     traffic across nodes.
#     egress  all                  - nodes need outbound to the NAT
#                                     Gateway for image pulls, and to the
#                                     API server / ECR / S3 endpoints.
#
# No rule here ever opens a port to 0.0.0.0/0 ingress - the only internet
# facing surface in this design is the ALB/NLB security groups that the
# AWS Load Balancer Controller creates separately per-Ingress/Service, and
# the public EKS API endpoint itself (controlled by
# var.public_access_cidrs in the eks module, not a security group).
###############################################################################

resource "aws_security_group" "cluster" {
  name        = "${var.name_prefix}-eks-cluster-sg"
  description = "EKS control plane security group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-cluster-sg"
  })
}

resource "aws_security_group" "node" {
  name        = "${var.name_prefix}-eks-node-sg"
  description = "EKS managed node group security group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name                                          = "${var.name_prefix}-eks-node-sg"
    "kubernetes.io/cluster/${var.name_prefix}-eks" = "owned"
  })
}

# --- Cluster SG rules -----------------------------------------------------

resource "aws_security_group_rule" "cluster_ingress_from_node" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  description               = "Allow worker nodes to reach the Kubernetes API server"
}

resource "aws_security_group_rule" "cluster_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.cluster.id
  cidr_blocks       = ["0.0.0.0/0"]
  description        = "Control plane egress to nodes and AWS APIs"
}

# --- Node SG rules ---------------------------------------------------------

resource "aws_security_group_rule" "node_ingress_api_from_cluster" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
  description               = "Allow control plane to reach node-hosted API extensions"
}

resource "aws_security_group_rule" "node_ingress_kubelet_from_cluster" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
  description               = "Allow control plane to reach kubelet (exec/logs/metrics)"
}

resource "aws_security_group_rule" "node_ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.node.id
  self              = true
  description        = "Allow node-to-node and pod-to-pod traffic (VPC CNI, CoreDNS, NodePort services)"
}

resource "aws_security_group_rule" "node_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.node.id
  cidr_blocks       = ["0.0.0.0/0"]
  description        = "Node egress to NAT Gateway / AWS APIs / API server"
}

###############################################################################
# modules/vpc/main.tf
#
# WHY THIS SUBNET DESIGN (3-tier x 3-AZ):
# ------------------------------------------------------------------------
# Production EKS clusters split subnets into three tiers per Availability
# Zone rather than one flat subnet, because each tier has a different
# network exposure requirement:
#
#   PUBLIC subnets      - hold the NAT Gateway(s) and (if used) a
#                          Load-Balancer-facing ENI. Only resource that must
#                          own a public IP. Tagged kubernetes.io/role/elb so
#                          the AWS Load Balancer Controller auto-discovers
#                          them for internet-facing Services/Ingresses.
#
#   PRIVATE APP subnets - where EKS worker nodes and pod ENIs actually live.
#                          No public IP, no route to the Internet Gateway;
#                          outbound internet (image pulls, package updates)
#                          goes through the NAT Gateway only. Tagged
#                          kubernetes.io/role/internal-elb for internal
#                          load balancers.
#
#   PRIVATE DB subnets  - reserved for stateful data services (RDS,
#                          ElastiCache, self-hosted databases running on
#                          EKS via StatefulSets/EBS). They share the
#                          private route table for simplicity but carry no
#                          EKS subnet tags, so the Kubernetes
#                          cloud-controller and Load Balancer Controller
#                          never place load balancer ENIs in them.
#
# Spreading each tier across 3 AZs is what makes the cluster survive a
# single AZ failure: EKS, the ASG behind the managed node group, and any
# multi-AZ RDS instance can all reschedule into a surviving AZ.
###############################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

# -----------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

# -----------------------------------------------------------------------
# Internet Gateway (egress for public subnets)
# -----------------------------------------------------------------------

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

# -----------------------------------------------------------------------
# Public subnets
# -----------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = var.availability_zone_count

  vpc_id                   = aws_vpc.this.id
  cidr_block               = var.public_subnet_cidrs[count.index]
  availability_zone        = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch  = true

  tags = merge(var.tags, {
    Name                                        = "${var.name_prefix}-public-${data.aws_availability_zones.available.names[count.index]}"
    Tier                                        = "public"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# -----------------------------------------------------------------------
# Private application subnets (worker nodes / pods)
# -----------------------------------------------------------------------

resource "aws_subnet" "private_app" {
  count = var.availability_zone_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.tags, {
    Name                                        = "${var.name_prefix}-private-app-${data.aws_availability_zones.available.names[count.index]}"
    Tier                                        = "private-app"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# -----------------------------------------------------------------------
# Private database subnets (RDS / stateful services)
# -----------------------------------------------------------------------

resource "aws_subnet" "private_db" {
  count = var.availability_zone_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_db_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-db-${data.aws_availability_zones.available.names[count.index]}"
    Tier = "private-db"
  })
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = aws_subnet.private_db[*].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-subnet-group"
  })
}

# -----------------------------------------------------------------------
# Elastic IP(s) + NAT Gateway(s)
# -----------------------------------------------------------------------

resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : var.availability_zone_count
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip-${count.index}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = var.single_nat_gateway ? 1 : var.availability_zone_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-${count.index}"
  })

  depends_on = [aws_internet_gateway.this]
}

# -----------------------------------------------------------------------
# Route tables
# -----------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-rt"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id              = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = var.availability_zone_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# One private route table PER AZ (even with a single shared NAT Gateway),
# each routing 0.0.0.0/0 to the appropriate NAT Gateway. This keeps the
# design ready to switch to `single_nat_gateway = false` (one NAT per AZ)
# without restructuring route tables - only the NAT target changes.
resource "aws_route_table" "private" {
  count  = var.availability_zone_count
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-rt-${data.aws_availability_zones.available.names[count.index]}"
  })
}

resource "aws_route" "private_nat" {
  count = var.availability_zone_count

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id          = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "private_app" {
  count          = var.availability_zone_count
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "private_db" {
  count          = var.availability_zone_count
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

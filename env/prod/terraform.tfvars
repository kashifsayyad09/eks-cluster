project_name = "veera"
environment  = "prod"
owner        = "drocart"
aws_region   = "us-east-1"

vpc_cidr                = "10.2.0.0/16"
availability_zone_count = 3
# Production should isolate NAT failure domains per-AZ.
single_nat_gateway = false

existing_cluster_role_name = ""
existing_node_role_name    = ""

kubernetes_version      = null
endpoint_private_access = true
endpoint_public_access  = true
# Lock this down to your office/VPN CIDR before going live.
public_access_cidrs = ["0.0.0.0/0"]

node_instance_types = ["t3.medium", "t3a.medium"]
node_capacity_type  = "ON_DEMAND"
node_disk_size_gb   = 30
node_desired_size   = 3
node_min_size       = 3
node_max_size       = 6
ssh_key_name        = ""

create_app_bucket = true
app_bucket_name    = ""

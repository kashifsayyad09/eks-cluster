project_name = "veera"
environment  = "qa"
owner        = "drocart"
aws_region   = "us-east-1"

vpc_cidr                = "10.1.0.0/16"
availability_zone_count = 3
single_nat_gateway      = true

existing_cluster_role_name = ""
existing_node_role_name    = ""

kubernetes_version      = null
endpoint_private_access = true
endpoint_public_access  = true
public_access_cidrs     = ["0.0.0.0/0"]

node_instance_types = ["t3.medium"]
node_capacity_type  = "ON_DEMAND"
node_disk_size_gb   = 30
node_desired_size   = 2
node_min_size       = 2
node_max_size       = 4
ssh_key_name        = ""

create_app_bucket = true
app_bucket_name    = ""

project_name = "veera"
environment  = "dev"
owner        = "drocart"
aws_region   = "us-east-1"

vpc_cidr                = "10.0.0.0/16"
availability_zone_count = 3
single_nat_gateway      = true

existing_cluster_role_name = ""
existing_node_role_name    = ""

kubernetes_version      = null
endpoint_private_access = true
endpoint_public_access  = true
public_access_cidrs     = ["0.0.0.0/0"]

node_instance_types = ["t2.medium"]
node_capacity_type  = "ON_DEMAND"
node_disk_size_gb   = 30
node_desired_size   = 2
node_min_size       = 2
node_max_size       = 4
ssh_key_name        = ""

authentication_mode                         = "API_AND_CONFIG_MAP"
bootstrap_cluster_creator_admin_permissions = true
# Add your sandbox user ARN here so `kubectl get nodes` works right after
# apply, with no manual `aws eks associate-access-policy` step, e.g.:
# cluster_admin_principal_arns = ["arn:aws:iam::548830423449:user/cloud_user"]
cluster_admin_principal_arns = []

# Set create_github_actions_role = true and fill these in once you're
# ready to wire up the GitHub Actions workflow in .github/workflows/.
create_github_actions_role          = false
github_org                          = ""
github_repo                         = ""
github_allowed_refs                 = ["ref:refs/heads/main"]
github_oidc_provider_already_exists = false
existing_github_oidc_provider_arn   = ""

create_app_bucket = true
app_bucket_name    = ""

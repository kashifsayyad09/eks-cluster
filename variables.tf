###############################################################################
# variables.tf (root)
#
# Every input the root module accepts. Environment-specific values live in
# env/<env>/terraform.tfvars — this file only defines the contract
# (type, description, validation, sane default) so the module is self
# documenting and safe to reuse across dev/qa/prod.
###############################################################################

# -----------------------------------------------------------------------
# Global / naming
# -----------------------------------------------------------------------

variable "project_name" {
  description = "Short project identifier used as a prefix for all resource names (e.g. 'veera')."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project_name))
    error_message = "project_name must be lowercase alphanumeric/hyphen, start with a letter, 2-21 chars."
  }
}

variable "environment" {
  description = "Deployment environment name."
  type        = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be one of: dev, qa, prod."
  }
}

variable "owner" {
  description = "Tag value identifying who owns/deployed this stack."
  type        = string
  default     = "platform-team"
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

# -----------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the EKS VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zone_count" {
  description = "Number of Availability Zones to spread subnets across. EKS requires >= 2; production best practice is 3."
  type        = number
  default     = 3

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 4
    error_message = "availability_zone_count must be between 2 and 4."
  }
}

variable "single_nat_gateway" {
  description = <<-EOT
    If true, deploy exactly ONE NAT Gateway (in the first public subnet) shared
    by all private subnets. If false, deploy one NAT Gateway PER Availability
    Zone for full AZ isolation.

    Production guidance: use false (one NAT per AZ) so that the failure of a
    single AZ's NAT Gateway cannot cut off outbound internet access for the
    other AZs. Default here is true because the Pluralsight Skills Sandbox
    caps concurrent Elastic IPs / NAT Gateways and bills sandbox time by the
    hour - a single NAT Gateway is materially cheaper and is sufficient for a
    non-HA training/practice cluster.
  EOT
  type    = bool
  default = true
}

# -----------------------------------------------------------------------
# IAM re-use vs create
# -----------------------------------------------------------------------

variable "existing_cluster_role_name" {
  description = "Name of an EXISTING IAM role to reuse as the EKS cluster role. Leave empty string to have Terraform create a new one."
  type        = string
  default     = ""
}

variable "existing_node_role_name" {
  description = "Name of an EXISTING IAM role to reuse as the EKS managed node group role. Leave empty string to have Terraform create a new one."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------
# EKS control plane
# -----------------------------------------------------------------------

variable "kubernetes_version" {
  description = "EKS Kubernetes version. Leave null to let AWS choose the latest version EKS currently supports."
  type        = string
  default     = null
}

variable "endpoint_private_access" {
  description = "Enable the private API server endpoint (required for in-VPC access, e.g. from a bastion)."
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable the public API server endpoint (required for kubectl from outside the VPC, e.g. Pluralsight sandbox Cloud Shell)."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint. Restrict this in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_log_types" {
  description = "EKS control plane log types to ship to CloudWatch Logs."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_log_retention_days" {
  description = "CloudWatch Logs retention period for EKS control plane logs."
  type        = number
  default     = 30
}

# -----------------------------------------------------------------------
# Managed node group
# -----------------------------------------------------------------------

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group (first type is primary; extras allow Spot diversification)."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_disk_size_gb" {
  description = "Root EBS volume size (GiB) for worker nodes."
  type        = number
  default     = 30
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 4
}

variable "ssh_key_name" {
  description = "Optional EC2 key pair name for SSH/SSM debugging access to worker nodes. Leave empty to disable SSH access (SSM Session Manager is still available via the node IAM role)."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------
# Application S3 bucket
# -----------------------------------------------------------------------

variable "create_app_bucket" {
  description = "Whether to create the application/artifact S3 bucket (modules/s3)."
  type        = bool
  default     = true
}

variable "app_bucket_name" {
  description = "Globally-unique name for the application S3 bucket. Leave empty to auto-generate one from project/environment/account ID."
  type        = string
  default     = ""
}

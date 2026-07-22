###############################################################################
# providers.tf
#
# Configures the AWS provider and default resource tags. Default tags are
# applied to every taggable resource created by this provider instance,
# which guarantees consistent cost-allocation and ownership tagging without
# having to repeat the same tag block in every module.
###############################################################################

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
    }
  }
}

# Used by modules/iam to build the OIDC provider's thumbprint and by any
# resource that needs the calling identity's account ID.
data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

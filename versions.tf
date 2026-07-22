###############################################################################
# versions.tf
#
# Pins the Terraform core version and every provider used in this root module.
# Pinning with a floor (>=) plus a major-version ceiling (<) is the standard
# production pattern: it lets `terraform init -upgrade` pull in patch/minor
# fixes automatically while blocking breaking major-version upgrades from
# being applied silently in CI.
###############################################################################

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.3.0"
    }
  }
}

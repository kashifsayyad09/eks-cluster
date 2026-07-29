variable "name_prefix" { type = string }

variable "github_org" {
  description = "GitHub organization or username that owns the repo (e.g. 'kashifsayyad09')."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix)."
  type        = string
}

variable "allowed_refs" {
  description = <<-EOT
    Git refs allowed to assume this role, as OIDC subject-claim patterns.
    Defaults to the main branch only. Add pull_request or other-branch
    patterns explicitly rather than widening to '*' - the subject claim
    is the only thing standing between "any workflow in this repo" and
    "any workflow anywhere".
    Examples: "ref:refs/heads/main", "ref:refs/heads/dev",
              "pull_request"
  EOT
  type = list(string)
  default = ["ref:refs/heads/main"]
}

variable "create_oidc_provider" {
  description = "Whether to create the token.actions.githubusercontent.com IAM OIDC provider. Set to false if it already exists in this AWS account (an account can only have ONE OIDC provider per issuer URL - a second `terraform apply` from another repo's stack must reuse it, not recreate it)."
  type        = bool
  default     = true
}

variable "existing_oidc_provider_arn" {
  description = "ARN of an existing GitHub OIDC provider to reuse when create_oidc_provider = false."
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}

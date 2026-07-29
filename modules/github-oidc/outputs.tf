output "role_arn" {
  description = "Paste this into the GitHub Actions workflow's role-to-assume input, or into a repo variable/secret referenced by it."
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  value = local.oidc_provider_arn
}

variable "name_prefix" { type = string }
variable "bucket_name" {
  description = "Explicit bucket name. Leave empty to auto-generate a globally-unique name from name_prefix + account ID."
  type        = string
  default     = ""
}
variable "account_id" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

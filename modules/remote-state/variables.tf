variable "state_bucket_key_alias_prefix" {
  description = "Prefix for S3 bucket key alias"
  type        = string
  default     = "alias/terraform-key"
}

variable "state_bucket_name" {
  description = "S3 Bucket Name"
  type        = string
}

variable "default_tags" {
  description = "Default tags applied to resources"
  type        = map(string)
}

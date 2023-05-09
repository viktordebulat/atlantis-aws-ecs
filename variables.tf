################################################################################
# Project
################################################################################

variable "project" {
  type = object({
    # Name of the project in single word, without special characters
    name = string
    # Zone name in Route53
    domain = string
  })
  description = "Project parameters"
  default = {
    name   = "atlantis"
    domain = "example.com"
  }
}

variable "default_tags" {
  type        = map(string)
  description = "These tags will be applied to all created resources"
  default = {
    Name         = "Atlantis"
    Budget_Group = "Infrastructure"
    Terraform    = "True"
  }
}

################################################################################
# AWS Basic
################################################################################

variable "aws_region" {
  type        = string
  description = "AWS region to operate on"
  default     = "us-east-1"
}

################################################################################
# AWS VPC
################################################################################

variable "vpc" {
  type = object({
    tag_name  = string
    tag_value = string
  })
  description = "Primary VPC tag"
}

variable "public_subnets" {
  type = object({
    tag_name  = string
    tag_value = string
  })
  description = "Public subnets tag"
}

variable "private_subnets" {
  type = object({
    tag_name  = string
    tag_value = string
  })
  description = "Private subnets tag"
}

variable "sg_names" {
  type        = list(string)
  description = "List of security groups be attached to ALB (can use wildcard *)"
}

variable "prefix_name" {
  type        = string
  description = "Name of managed prefixes"
  default     = ""
}

################################################################################
# AWS IAM
################################################################################

variable "iam_role_boundary" {
  type        = string
  description = "Role boundary name for all new roles (if exists)"
}

variable "iam_policies_arn" {
  description = "ARN of policies to apply"
  type        = list(string)
}

################################################################################
# Gitlab
################################################################################

variable "gitlab" {
  type = object({
    # Gitlab Hostname
    hostname = string
    # Gitlab user
    user = string
    # Repos able to work with Atlantis
    repo_names = list(string)
  })
  description = "Gitlab parameters"
}

variable "gitlab_user_token" {
  type        = string
  description = "Gitlab User Token with full access to repositories"
  sensitive   = true
}

# variable "atlantis_image" {
#   description = "Use custom atlantis image for container"
#   type        = string
#   default     = ""
# }

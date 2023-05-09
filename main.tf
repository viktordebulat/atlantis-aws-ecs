terraform {
  required_version = ">= 1.2.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.63"
    }
  }

  # backend "s3" {}
  backend "local" {}
}

provider "aws" {
  region = var.aws_region
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Get Account ID for permit S3 Bucket policy
data "aws_elb_service_account" "current" {}

################################################################################
# Use existing infrastructure
################################################################################

# Get already created VPC
data "aws_vpc" "primary_vpc" {
  filter {
    name   = "tag:${var.vpc.tag_name}"
    values = [var.vpc.tag_value]
  }
}

# Get already created public subnets
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.primary_vpc.id]
  }
  tags = {
    "${var.public_subnets.tag_name}" = var.public_subnets.tag_value
  }
}

# Get already created private subnets
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.primary_vpc.id]
  }
  tags = {
    "${var.private_subnets.tag_name}" = var.private_subnets.tag_value
  }
}

data "aws_security_groups" "existing" {
  filter {
    name   = "group-name"
    values = var.sg_names
  }
}

# Get managed CIDRs prefix for ALB
data "aws_ec2_managed_prefix_list" "this" {
  count = length(var.prefix_name) > 0 ? 1 : 0

  filter {
    name   = "prefix-list-name"
    values = [var.prefix_name]
  }
}

# Make sure Route53 zone exists
data "aws_route53_zone" "this" {
  name = var.project.domain
}

data "aws_acm_certificate" "existing_certificate" {
  count       = var.create_acm_cert ? 0 : 1
  domain      = "*.${var.project.domain}"
  statuses    = ["ISSUED"]
  most_recent = true
}

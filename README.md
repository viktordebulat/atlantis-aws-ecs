# Atlantis
Start [Atlantis](https://www.runatlantis.io/) on ECS Fargate with exitsting infrastructure.

Resources created:
- ECS Cluster with AWS Fargate
- ALB
- S3 and DynamoDB table for remote state
- S3 for ALB access logs
- ACM certificate for `atlantis.*` (optionally, if wildcard cert doesn't exist)
- Route53 TXT record (optionally, if ACM cert issued)
- Route53 A record for ALB
- IAM roles and policies
- GitLab webhook

Uses existing infrastructure (Route53 zone, VPC with public and private subnets, security groups).

[Babenko Atlantis module](https://registry.terraform.io/modules/terraform-aws-modules/atlantis/aws/latest) used.

## Prerequisites

1. VPC with public and private subnets (tagged) created.
2. Route53 zone added.

## Installation
1. Make a copy of `terraform.tfvars.sample` > `terraform.tfvars` and fill it with your values.
2. `make init`, `make apply`

`backend.conf` is used for further runs (migrate state to created S3 first).

You can customise your atlantis workflow on the repo level. Create [proper atlantis.yaml](https://www.runatlantis.io/docs/repo-level-atlantis-yaml.html#example-using-all-keys) in your repo root directory.

## TO-DO
- [ ] Use optionally private Route53 zone.
- [ ] Add authorization for Atlantis by default.
- [ ] Add sample of `atlantis.yaml` configuration for repos.

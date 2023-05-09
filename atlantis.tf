################################################################################
# Atlantis
################################################################################

module "atlantis" {
  source  = "terraform-aws-modules/atlantis/aws"
  version = "3.26.0"

  name = var.project.name

  vpc_id             = data.aws_vpc.primary_vpc.id
  public_subnet_ids  = data.aws_subnets.public.ids
  private_subnet_ids = data.aws_subnets.private.ids

  # Ephemeral storage Fargate
  enable_ephemeral_storage = true

  # ECS
  ecs_service_platform_version = "LATEST"
  ecs_container_insights       = true
  ecs_task_cpu                 = 512
  ecs_task_memory              = 1024
  container_memory_reservation = 256
  container_cpu                = 512
  container_memory             = 1024

  # Use custom Atlantis image
  # atlantis_image = var.atlantis_image

  runtime_platform = {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  entrypoint        = ["docker-entrypoint.sh"]
  command           = ["server"]
  working_directory = "/tmp"
  docker_labels = {
    "org.opencontainers.image.title"       = "Atlantis"
    "org.opencontainers.image.description" = "A self-hosted golang application that listens for Terraform pull request events via webhooks."
    "org.opencontainers.image.url"         = "https://github.com/runatlantis/atlantis/pkgs/container/atlantis"
  }
  start_timeout = 30
  stop_timeout  = 30

  readonly_root_filesystem = false
  ulimits = [{
    name      = "nofile"
    softLimit = 4096
    hardLimit = 16384
  }]

  # DNS record
  route53_zone_name   = data.aws_route53_zone.this.name
  route53_record_name = "atlantis.${data.aws_route53_zone.this.name}"

  # ACM certificate
  certificate_arn = length(data.aws_acm_certificate.existing_certificate.arn) > 0 ? data.aws_acm_certificate.existing_certificate.arn : data.aws_acm_certificate.new_certificate[0].arn

  # Trusted roles
  trusted_principals = ["ssm.amazonaws.com"]

  # IAM role options
  policies_arn = var.iam_policies_arn
  # Use permission boundary for role if exist
  permissions_boundary = length(var.iam_role_boundary) > 0 ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.iam_role_boundary}" : ""

  # ALB
  # Use managed prefixes to access ALB if exist
  alb_ingress_cidr_blocks = length(data.aws_ec2_managed_prefix_list.this[0].entries) > 0 ? [for v in data.aws_ec2_managed_prefix_list.this[0].entries : v.cidr] : []

  alb_ingress_ipv6_cidr_blocks = []

  # Attach existing SG
  security_group_ids = data.aws_security_groups.existing.ids

  alb_logging_enabled                  = true
  alb_log_bucket_name                  = module.atlantis_access_log_bucket.s3_bucket_id
  alb_log_location_prefix              = "atlantis-alb"
  alb_listener_ssl_policy_default      = "ELBSecurityPolicy-TLS-1-2-2017-01"
  alb_drop_invalid_header_fields       = true
  alb_enable_cross_zone_load_balancing = true

  # Just in case for the future to bypass OIDC authentication
  allow_unauthenticated_access = true

  # Allow to use atlantis.yaml files in repos
  allow_repo_config = true

  # GitLab access in ECS
  atlantis_gitlab_hostname   = var.gitlab.hostname
  atlantis_gitlab_user       = var.gitlab.user
  atlantis_gitlab_user_token = var.gitlab_user_token

  # Set list of allowed repos for webhook
  atlantis_repo_allowlist = [for repo in var.gitlab.repo_names : "${var.gitlab.hostname}/${repo}"]

  # Extra container definitions
  extra_container_definitions = [
    {
      name      = "log-router"
      image     = "amazon/aws-for-fluent-bit:latest"
      essential = true

      firelens_configuration = {
        type = "fluentbit"

        logConfiguration = {
          logDriver = "awslogs",
          options = {
            awslogs-group         = "firelens-container",
            awslogs-region        = data.aws_region.current.name,
            awslogs-create-group  = true,
            awslogs-stream-prefix = "firelens"
          }
        }
      }
    }
  ]

  tags = var.default_tags
}

################################################################################
# Gitlab webhook
################################################################################

module "gitlab_repository_webhook" {
  source  = "terraform-aws-modules/atlantis/aws//modules/gitlab-repository-webhook"
  version = "3.26.0"

  create_gitlab_repository_webhook = true

  gitlab_token    = var.gitlab_user_token
  gitlab_base_url = "https://${var.gitlab.hostname}"

  atlantis_repo_allowlist = var.gitlab.repo_names
  webhook_url             = module.atlantis.atlantis_url_events
  webhook_secret          = module.atlantis.webhook_secret
}

################################################################################
# ALB Log Bucket + Policy
################################################################################

data "aws_iam_policy_document" "atlantis_access_log_bucket_policy" {
  statement {
    sid     = "LogsLogDeliveryWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = [
      "${module.atlantis_access_log_bucket.s3_bucket_arn}/*/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]

    principals {
      type = "AWS"
      identifiers = [
        # https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html#access-logging-bucket-permissions
        data.aws_elb_service_account.current.arn,
      ]
    }
  }

  statement {
    sid     = "AWSLogDeliveryWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = [
      "${module.atlantis_access_log_bucket.s3_bucket_arn}/*/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]

    principals {
      type = "Service"
      identifiers = [
        "delivery.logs.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"

      values = [
        "bucket-owner-full-control"
      ]
    }
  }

  statement {
    sid     = "AWSLogDeliveryAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    resources = [
      module.atlantis_access_log_bucket.s3_bucket_arn
    ]

    principals {
      type = "Service"
      identifiers = [
        "delivery.logs.amazonaws.com"
      ]
    }
  }
}

module "atlantis_access_log_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "atlantis-access-logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  attach_policy = true
  policy        = data.aws_iam_policy_document.atlantis_access_log_bucket_policy.json

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  force_destroy = true

  tags = var.default_tags

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule = [
    {
      id      = "all"
      enabled = true

      transition = [
        {
          days          = 30
          storage_class = "ONEZONE_IA"
          }, {
          days          = 60
          storage_class = "GLACIER"
        }
      ]

      expiration = {
        days = 90
      }

      noncurrent_version_expiration = {
        days = 30
      }
    },
  ]
}

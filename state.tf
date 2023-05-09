module "remote_state_atlantis" {
  source                        = "./modules/remote-state"
  state_bucket_name             = "${var.project.name}-tfstate.${var.project.domain}"
  state_bucket_key_alias_prefix = "alias/${var.project.name}-bucket-key"
  default_tags                  = var.default_tags
}

resource "aws_dynamodb_table" "state_lock_atlantis" {
  name = "${var.project.name}-tflock"
  point_in_time_recovery {
    enabled = true
  }
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# Used by tflint job in the pipeline

# rules: https://github.com/terraform-linters/tflint-ruleset-terraform/blob/main/docs/rules/README.md
plugin "terraform" {
  enabled = true
  version = "0.2.2"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}

# rules: https://github.com/terraform-linters/tflint-ruleset-aws/blob/master/docs/rules/README.md
plugin "aws" {
  enabled = true
  version = "0.21.2"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

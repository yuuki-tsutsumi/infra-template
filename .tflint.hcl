plugin "aws" {
    enabled = true
    deep_check = true
    version = "0.34.0"
    source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "terraform_required_version" {
  enabled = false
}

rule "terraform_required_providers" {
  enabled = false
}

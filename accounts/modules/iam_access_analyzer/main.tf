resource "aws_accessanalyzer_analyzer" "this" {
  analyzer_name = "access-analyzer"
  type          = "ACCOUNT_UNUSED_ACCESS"

  configuration {
    unused_access {
      unused_access_age = 90
    }
  }

  tags = {
    Terraform = "true"
  }
}

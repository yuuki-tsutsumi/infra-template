resource "random_password" "basic" {
  length           = 12
  special          = true
  override_special = "!#&,:;_"

  lifecycle {
    ignore_changes = [
      override_special
    ]
  }
}

resource "aws_ssm_parameter" "basic_username" {
  name  = "/basic/username"
  type  = "SecureString"
  value = "admin"

  tags = {
    Terraform = "true"
  }
}

resource "aws_ssm_parameter" "basic_password" {
  name  = "/basic/password"
  type  = "SecureString"
  value = random_password.basic.result

  tags = {
    Terraform = "true"
  }
}

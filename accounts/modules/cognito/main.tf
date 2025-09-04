resource "aws_cognito_user_pool" "this" {
  name = "cognito-user-pool"

  lambda_config {
    pre_token_generation_config {
      lambda_arn     = aws_lambda_function.add_email_to_access_token.arn
      lambda_version = "V2_0"
    }
  }

  password_policy {
    minimum_length    = 12
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
  }

  admin_create_user_config {
    invite_message_template {
      email_subject = "【Product Name】ユーザー名と仮パスワードをお知らせします"
      email_message = " Product Nameへようこそ。<br><br>ご登録いただきありがとうございます。<br>ユーザー名と仮パスワードをお知らせします。<br><br>ユーザー名： {username}<br>仮パスワード： {####}<br><br>今後とも Product Name をよろしくお願いいたします。<br><br>Organization Name<br>Product Name"
      sms_message   = "Your username is {username}. Your temporary password is {####}. "
    }
  }

  auto_verified_attributes = ["email"]

  verification_message_template {
    default_email_option  = "CONFIRM_WITH_LINK"
    email_subject_by_link = "【Product Name】ユーザー登録のためのメールアドレスの確認をお願いします"
    email_message_by_link = "Product Nameへようこそ。<br><br>ご登録いただきありがとうございます。<br>ユーザー登録完了するには、以下のリンクをクリックして、メールアドレスの確認を行ってください。<br><br>{##こちらをクリックしてメールアドレスを確認してください##}<br><br>※このリンクは24時間のみ有効です。有効期限が過ぎた場合は、再度サインアップを行ってください。<br><br>今後とも Product Name をよろしくお願いいたします。<br><br>Organization Name<br>Product Name"
  }

  mfa_configuration = "OPTIONAL"

  email_configuration {
    configuration_set     = "ConfigurationSet"
    email_sending_account = "DEVELOPER"
    from_email_address    = "noreply@${var.ses_domain}"
    source_arn            = var.ses_arn
  }

  email_mfa_configuration {
    subject = "【Product Name】ログイン認証コード"
    message = "Product Nameにログインするための認証コードはこちらです。<br><br>{####}<br><br>このコードは10分間のみ有効です。有効期限が過ぎた場合は、再度ログインを行ってください。<br><br>今後とも Product Name をよろしくお願いいたします。<br><br>Organization Name<br>Product Name"
  }

  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
    mutable             = true
  }

  user_pool_add_ons {
    advanced_security_mode = "AUDIT"
  }

  tags = {
    Terraform = "true"
  }
}

# ユーザプールのログを出力するロググループ。
# ユーザプールのログストリーミングの設定は現状Terraformでは対応中。
# cf: https://github.com/hashicorp/terraform-provider-aws/issues/36251
resource "aws_cloudwatch_log_group" "this" {
  name = "/aws/cognito/user-pool-logs"

  tags = {
    Terraform = "true"
  }
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = "${var.service_name}-${var.env}"
  user_pool_id = aws_cognito_user_pool.this.id
}

resource "aws_cognito_user_pool_client" "this" {
  name                                 = "user-pool-client"
  user_pool_id                         = aws_cognito_user_pool.this.id
  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true

  supported_identity_providers = ["COGNITO"]

  allowed_oauth_flows  = ["code"]
  allowed_oauth_scopes = ["email", "openid"]

  // localhost:8000を、ECSのドメインに変える
  callback_urls = ["http://localhost:8000/docs/oauth2-redirect", "https://${var.alb_dns_name}/docs/oauth2-redirect"]
  logout_urls   = ["http://localhost:3000/home", "https://${var.alb_dns_name}/home"]

  access_token_validity  = 60 * 24
  id_token_validity      = 10
  refresh_token_validity = 30

  # トークンの有効期限の単位 (デフォルトは "minutes")
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

resource "aws_lambda_permission" "cognito_trigger_permission" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.add_email_to_access_token.function_name

  principal  = "cognito-idp.amazonaws.com"
  source_arn = aws_cognito_user_pool.this.arn
}


resource "aws_lambda_function" "add_email_to_access_token" {
  function_name = "add_email_to_access_token"
  runtime       = "python3.10"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"

  filename         = "addEmailToAccessToken.zip"
  source_code_hash = filebase64sha256("addEmailToAccessToken.zip")

  environment {
    variables = {
      LOG_LEVEL = "DEBUG"
    }
  }

  tags = {
    Terraform = "true"
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Terraform = "true"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "Lambda Errors Alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  dimensions = {
    FunctionName = aws_lambda_function.add_email_to_access_token.function_name
  }
  alarm_actions             = [var.chatbot_sns_topic_arn]
  insufficient_data_actions = []
  ok_actions                = [var.chatbot_sns_topic_arn]

  tags = {
    Terraform = "true"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "Lambda Throttles Alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  dimensions = {
    FunctionName = aws_lambda_function.add_email_to_access_token.function_name
  }
  alarm_actions             = [var.chatbot_sns_topic_arn]
  insufficient_data_actions = []
  ok_actions                = [var.chatbot_sns_topic_arn]

  tags = {
    Terraform = "true"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "cognito_power_user" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonCognitoPowerUser"
}

resource "aws_ssm_parameter" "user_pool_id" {
  name  = "/cognito/user_pool_id"
  type  = "SecureString"
  value = aws_cognito_user_pool.this.id

  tags = {
    Terraform = "true"
  }
}

resource "aws_ssm_parameter" "client_id" {
  name  = "/cognito/client_id"
  type  = "SecureString"
  value = aws_cognito_user_pool_client.this.id

  tags = {
    Terraform = "true"
  }
}

resource "aws_ssm_parameter" "domain" {
  name  = "/cognito/domain"
  type  = "SecureString"
  value = "${aws_cognito_user_pool.this.domain}.auth.ap-northeast-1.amazoncognito.com"

  tags = {
    Terraform = "true"
  }
}

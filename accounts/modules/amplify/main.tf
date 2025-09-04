# コンソールから直接作成する。
# Githubで、Developer Settings > Personal access tokensで作成したトークンの値。堤が発行したものを使用している。
data "aws_secretsmanager_secret" "this" {
  name = "amplify-oauth-token___"
}

data "aws_secretsmanager_secret_version" "this" {
  secret_id = data.aws_secretsmanager_secret.this.id
}

resource "aws_amplify_app" "this" {
  name        = "${var.service_name}-frontend"
  repository  = "https://github.com/..."
  oauth_token = jsondecode(data.aws_secretsmanager_secret_version.this.secret_string)["token"]
  platform    = "WEB_COMPUTE"

  enable_branch_auto_build    = true
  enable_auto_branch_creation = true
  enable_branch_auto_deletion = true
  auto_branch_creation_patterns = [
    "*",
    "*/**",
  ]
  custom_headers = <<-EOT
    customHeaders:
      - pattern: '**'
        headers:
          - key: 'Strict-Transport-Security'
            value: 'max-age=63072000; includeSubDomains; preload'
  EOT

  auto_branch_creation_config {
    enable_pull_request_preview = true
    environment_variables = {
      NEXT_PUBLIC_CLIENT_ID    = var.cognito_user_pool_client_id
      NEXT_PUBLIC_USER_POOL_ID = var.cognito_user_pool_id
      NEXT_PUBLIC_HOST_URL     = "http://${var.alb_dns_name}"
    }
  }

  tags = {
    Terraform = "true"
  }

  build_spec = <<BUILD_SPEC
version: 1
frontend:
  phases:
    preBuild:
      commands:
        - nvm install 20.19.2
        - nvm use 20.19.2
        - node -v
        - yarn install
    build:
      commands:
        - yarn run build
  artifacts:
    baseDirectory: .next
    files:
      - '**/*'
  cache:
    paths:
      - .next/cache/**/*
      - node_modules/**/*
  BUILD_SPEC
}

resource "aws_amplify_branch" "this" {
  app_id = aws_amplify_app.this.id
  // TODO: 環境を考慮した場合分けが必要
  branch_name = var.env == "production" ? "main" : "develop"

  enable_pull_request_preview = true
  environment_variables = {
    NEXT_PUBLIC_CLIENT_ID    = var.cognito_user_pool_client_id
    NEXT_PUBLIC_USER_POOL_ID = var.cognito_user_pool_id
    NEXT_PUBLIC_HOST_URL     = "https://${var.alb_dns_name}"
  }

  enable_auto_build = true

  tags = {
    Terraform = "true"
  }
}

resource "aws_amplify_domain_association" "this" {
  app_id      = aws_amplify_app.this.id
  domain_name = var.domain_name

  sub_domain {
    branch_name = aws_amplify_branch.this.branch_name
    prefix      = "www"
  }

  lifecycle {
    ignore_changes = [
      certificate_settings
    ]
  }
}

resource "aws_cloudwatch_metric_alarm" "amplify_5xx_error" {
  alarm_name          = "Amplify 5xxError Alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "5xxErrors"
  namespace           = "AWS/Amplify"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  dimensions = {
    App = aws_amplify_app.this.id
  }
  alarm_actions             = [var.chatbot_sns_topic_arn]
  insufficient_data_actions = []
  ok_actions                = [var.chatbot_sns_topic_arn]

  tags = {
    Terraform = "true"
  }
}

resource "aws_cloudwatch_metric_alarm" "amplify_latency" {
  alarm_name          = "Amplify Latency Alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "Latency"
  namespace           = "AWS/Amplify"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  dimensions = {
    App = aws_amplify_app.this.id
  }
  alarm_actions             = [var.chatbot_sns_topic_arn]
  insufficient_data_actions = []
  ok_actions                = [var.chatbot_sns_topic_arn]

  tags = {
    Terraform = "true"
  }
}

resource "aws_cloudwatch_event_rule" "this" {
  name        = "amplify-deploy-event"
  description = "Rule to capture Amplify deployment status"
  event_pattern = jsonencode({
    source = [
      "aws.amplify"
    ],
    "detail-type" = [
      "Amplify Deployment Status Change"
    ],
    detail = {
      jobStatus = [
        "FAILED",
        "SUCCEED"
      ]
    }
  })

  tags = {
    Terraform = "true"
  }
}

resource "aws_cloudwatch_event_target" "this" {
  target_id = "amplify-deploy-event-rule-target"
  rule      = aws_cloudwatch_event_rule.this.name
  arn       = var.amplify_deploy_status_sns_topic_arn

  input_transformer {
    input_paths = {
      "account" : "$.account",
      "appId" : "$.detail.appId",
      "branch" : "$.detail.branchName",
      "detail-type" : "$.detail-type",
      "id" : "$.id",
      "jobId" : "$.detail.jobId",
      "region" : "$.region",
      "resources" : "$.resources",
      "source" : "$.source",
      "status" : "$.detail.jobStatus",
      "time" : "$.time",
      "version" : "$.version"
    }
    input_template = <<EOF
{
  "version": "1.0",
  "source": "custom",
  "content": {
    "textType": "client-markdown",
    "title": "<status>",
    "description": "<detail-type>",
    "nextSteps": [
      "view build details : https://console.aws.amazon.com/amplify/home?region=<region>#<appId>/<branch>/<jobId>",
      "view app url : https://<branch>.<appId>.amplifyapp.com/"
    ]
  },
  "metadata": {
    "threadId": "<appId>-<branch>-<jobId>"
  }
}
EOF
  }
}

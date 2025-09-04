resource "aws_chatbot_slack_channel_configuration" "this" {
  slack_channel_id   = var.alert_notification_slack_channel_id
  slack_team_id      = "T02QZDUV709"
  configuration_name = "aws-alert"

  iam_role_arn = aws_iam_role.this.arn

  sns_topic_arns = [
    aws_sns_topic.this.arn
  ]

  tags = {
    Terraform = "true"
  }
}

resource "aws_chatbot_slack_channel_configuration" "amplify_deploy_status" {
  slack_channel_id   = var.amplify_deploy_status_notification_slack_channel_id
  slack_team_id      = "T02QZDUV709"
  configuration_name = "amplify-deploy-status"

  iam_role_arn = aws_iam_role.this.arn

  sns_topic_arns = [
    aws_sns_topic.amplify_deploy_status.arn
  ]

  tags = {
    Terraform = "true"
  }
}

resource "aws_iam_role" "this" {
  name = "chatbot-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "chatbot.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Terraform = "true"
  }
}

resource "aws_iam_policy" "this" {
  name        = "chatbot-policy"
  description = "Policy to allow AWS Chatbot to access SNS topics"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowSNSPublish"
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = aws_sns_topic.this.arn
      },

      {
        Sid = "AllowGetCloudWatchInfo"
        Action = [
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })

  tags = {
    Terraform = "true"
  }
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

resource "aws_sns_topic" "this" {
  name = "slack-notifications"

  tags = {
    Terraform = "true"
  }
}

resource "aws_sns_topic_policy" "this" {
  arn = aws_sns_topic.this.arn

  policy = data.aws_iam_policy_document.this.json
}

data "aws_iam_policy_document" "this" {
  statement {
    sid    = "__default_statement_ID"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "SNS:GetTopicAttributes",
      "SNS:SetTopicAttributes",
      "SNS:AddPermission",
      "SNS:RemovePermission",
      "SNS:DeleteTopic",
      "SNS:Subscribe",
      "SNS:ListSubscriptionsByTopic",
      "SNS:Publish",
    ]

    resources = [aws_sns_topic.this.arn]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AllowEventBridgePublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = ["sns:Publish"]

    resources = [aws_sns_topic.this.arn]
  }
}

resource "aws_sns_topic" "amplify_deploy_status" {
  name = "amplify-deploy-status-notifications"

  tags = {
    Terraform = "true"
  }
}
resource "aws_sns_topic_policy" "amplify_deploy_status" {
  arn = aws_sns_topic.amplify_deploy_status.arn

  policy = data.aws_iam_policy_document.amplify_deploy_status.json
}

data "aws_iam_policy_document" "amplify_deploy_status" {
  statement {
    sid    = "__default_statement_ID"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "SNS:GetTopicAttributes",
      "SNS:SetTopicAttributes",
      "SNS:AddPermission",
      "SNS:RemovePermission",
      "SNS:DeleteTopic",
      "SNS:Subscribe",
      "SNS:ListSubscriptionsByTopic",
      "SNS:Publish",
    ]

    resources = [aws_sns_topic.amplify_deploy_status.arn]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AllowEventBridgePublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = ["sns:Publish"]

    resources = [aws_sns_topic.amplify_deploy_status.arn]
  }
}

data "aws_caller_identity" "current" {}

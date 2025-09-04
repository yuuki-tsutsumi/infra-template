resource "aws_cloudwatch_event_rule" "this" {
  name        = "aws-health-event-rule"
  description = "Rule to capture AWS Health events"
  event_pattern = jsonencode({
    source = [
      "aws.health"
    ],
    "detail-type" = [
      "AWS Health Event"
    ]
  })

  tags = {
    Terraform = "true"
  }
}

resource "aws_cloudwatch_event_target" "this" {
  target_id = "aws-health-event-rule-target"
  rule      = aws_cloudwatch_event_rule.this.name
  arn       = var.chatbot_sns_topic_arn
}

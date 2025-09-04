output "chatbot_sns_topic_arn" {
  value = aws_sns_topic.this.arn
}
output "amplify_deploy_status_sns_topic_arn" {
  value = aws_sns_topic.amplify_deploy_status.arn
}

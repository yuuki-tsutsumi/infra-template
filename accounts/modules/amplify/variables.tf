variable "env" {
  type = string
}
variable "service_name" {
  type = string
}
variable "cognito_user_pool_id" {
  type = string
}
variable "cognito_user_pool_client_id" {
  type = string
}
variable "alb_dns_name" {
  type = string
}
variable "domain_name" {
  type = string
}
variable "chatbot_sns_topic_arn" {
  type = string
}
variable "amplify_deploy_status_sns_topic_arn" {
  type = string
}

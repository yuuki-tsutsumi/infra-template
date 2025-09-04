variable "alb_alias" {
  type = any
}
variable "certificate" {
  type = any
}
variable "subnets" {
  type = list(string)
}
variable "vpc_id" {
  type = string
}
variable "chatbot_sns_topic_arn" {
  type = string
}

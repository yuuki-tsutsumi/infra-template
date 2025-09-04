variable "service_name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "subnets" {
  type = list(string)
}
variable "lb_security_group_id" {
  type = string
}
variable "lb_target_group" {
  type = any
}
variable "s3_bucket_name" {
  type = string
}
variable "chatbot_sns_topic_arn" {
  type = string
}

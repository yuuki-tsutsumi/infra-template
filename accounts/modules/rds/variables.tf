variable "vpc_id" {
  type = string
}
variable "azs" {
  type = list(string)
}
variable "db_subnet_group_name" {
  type = string
}
variable "access_allow_cidr_blocks" {
  type = list(string)
}
variable "bastion_security_group_id" {
  type = string
}
variable "chatbot_sns_topic_arn" {
  type = string
}

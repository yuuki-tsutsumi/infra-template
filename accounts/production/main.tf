
# 共通的に使用する値を変数として定義
locals {
  env            = "production"
  aws_account_id = "<production aws account id>"

  cidr            = "192.168.1.0/24"
  public_subnets  = ["192.168.1.64/28", "192.168.1.80/28"]
  private_subnets = ["192.168.1.32/28", "192.168.1.48/28"]
  rds_subnets     = ["192.168.1.0/28", "192.168.1.16/28"]
  azs             = ["ap-northeast-1a", "ap-northeast-1c"]

  service_name            = "product-name"
  service_name_underscore = "product_name"

  alert_notification_slack_channel_id                 = "C0960ULAXKL"
  amplify_deploy_status_notification_slack_channel_id = "C089E3YRE4B"
}

module "vpc" {
  source = "../modules/vpc"

  cidr            = local.cidr
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets
  rds_subnets     = local.rds_subnets
  azs             = local.azs
}

module "alb" {
  source = "../modules/alb"

  alb_alias             = module.route53.alb_alias
  certificate           = module.route53.certificate
  subnets               = module.vpc.vpc.public_subnets
  vpc_id                = module.vpc.vpc.vpc_id
  chatbot_sns_topic_arn = module.chatbot.chatbot_sns_topic_arn
}

module "amplify" {
  source = "../modules/amplify"

  env                                 = local.env
  service_name                        = local.service_name
  cognito_user_pool_client_id         = module.cognito.cognito_user_pool_client_id
  cognito_user_pool_id                = module.cognito.cognito_user_pool_id
  alb_dns_name                        = module.route53.alb_alias.name
  domain_name                         = module.route53.domain_name
  chatbot_sns_topic_arn               = module.chatbot.chatbot_sns_topic_arn
  amplify_deploy_status_sns_topic_arn = module.chatbot.amplify_deploy_status_sns_topic_arn
}

module "bastion" {
  source = "../modules/bastion"

  vpc_id    = module.vpc.vpc.vpc_id
  subnet_id = module.vpc.vpc.public_subnets[0]
}

module "cognito" {
  source = "../modules/cognito"

  alb_dns_name          = module.route53.alb_alias.name
  env                   = local.env
  service_name          = local.service_name
  chatbot_sns_topic_arn = module.chatbot.chatbot_sns_topic_arn
  ses_domain            = module.ses.ses_domain
  ses_arn               = module.ses.ses_arn
}

module "ecr" {
  source = "../modules/ecr"
}

module "ecs" {
  source = "../modules/ecs"

  lb_security_group_id  = module.alb.lb_security_group_id
  lb_target_group       = module.alb.lb_target_group
  subnets               = module.vpc.vpc.private_subnets
  service_name          = local.service_name
  vpc_id                = module.vpc.vpc.vpc_id
  s3_bucket_name        = module.s3_bucket.bucket_name
  chatbot_sns_topic_arn = module.chatbot.chatbot_sns_topic_arn
}

module "rds" {
  source = "../modules/rds"

  vpc_id                    = module.vpc.vpc.vpc_id
  azs                       = local.azs
  db_subnet_group_name      = module.vpc.vpc.database_subnet_group
  access_allow_cidr_blocks  = module.vpc.vpc.private_subnets_cidr_blocks
  bastion_security_group_id = module.bastion.bastion_security_group_id
  chatbot_sns_topic_arn     = module.chatbot.chatbot_sns_topic_arn
}

module "route53" {
  source = "../modules/route53"

  env = local.env
  lb  = module.alb.lb
}

module "ssm" {
  source = "../modules/ssm"
}

module "s3_bucket" {
  source = "../modules/s3"

  env          = local.env
  service_name = local.service_name
}

module "cloudtrail" {
  source = "../modules/cloudtrail"
}

module "athena" {
  source = "../modules/athena"

  service_name            = local.service_name
  service_name_underscore = local.service_name_underscore
}

module "chatbot" {
  source = "../modules/chatbot"

  alert_notification_slack_channel_id                 = local.alert_notification_slack_channel_id
  amplify_deploy_status_notification_slack_channel_id = local.amplify_deploy_status_notification_slack_channel_id
}

module "awshealth" {
  source = "../modules/awshealth"

  chatbot_sns_topic_arn = module.chatbot.chatbot_sns_topic_arn
}

module "iam_access_analyzer" {
  source = "../modules/iam_access_analyzer"
}

module "ses" {
  source = "../modules/ses"

  domain_name = module.route53.domain_name
  zone_id     = module.route53.zone_id
}

module "openai" {
  source = "../modules/openai"

  env          = local.env
  service_name = local.service_name
}

module "github" {
  source = "../modules/github"

  env            = local.env
  service_name   = local.service_name
  aws_account_id = local.aws_account_id
}

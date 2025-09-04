locals {
  master_username = "postgres"
  engine          = "aurora-postgresql"
  engine_version  = "16.8"
  instance_class  = "db.t4g.medium"
  database_name   = "appdb"
}

resource "aws_rds_cluster" "this" {
  cluster_identifier = "cluster-${local.database_name}"

  database_name                   = local.database_name
  master_username                 = local.master_username
  master_password                 = random_password.this.result
  availability_zones              = var.azs
  port                            = 5432
  vpc_security_group_ids          = [aws_security_group.this.id]
  db_subnet_group_name            = var.db_subnet_group_name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.id
  engine                          = local.engine
  engine_version                  = local.engine_version
  backup_retention_period         = 35
  final_snapshot_identifier       = "cluster-final-snapshot-${local.database_name}"
  skip_final_snapshot             = true
  apply_immediately               = true

  tags = {
    Terraform = "true"
  }

  lifecycle {
    ignore_changes = [
      availability_zones,
    ]
  }
}

resource "aws_rds_cluster_instance" "this" {
  count                      = 1
  identifier                 = "${local.database_name}-${count.index}"
  engine                     = local.engine
  engine_version             = local.engine_version
  cluster_identifier         = aws_rds_cluster.this.id
  instance_class             = local.instance_class
  auto_minor_version_upgrade = false

  tags = {
    Terraform = "true"
  }
}

resource "random_password" "this" {
  length           = 12
  special          = true
  override_special = "!#&,:;_"

  lifecycle {
    ignore_changes = [
      override_special
    ]
  }
}

resource "aws_rds_cluster_parameter_group" "this" {
  name   = "rds-cluster-parameter-group-${local.database_name}"
  family = "aurora-postgresql16"

  parameter {
    name  = "timezone"
    value = "Asia/Tokyo"
  }

  tags = {
    Terraform = "true"
  }
}

resource "aws_security_group" "this" {
  name   = "security-group-rds-${local.database_name}"
  vpc_id = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Terraform = "true"
  }
}

resource "aws_security_group_rule" "this" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = var.access_allow_cidr_blocks
  security_group_id = aws_security_group.this.id
}

resource "aws_security_group_rule" "allow_bastion" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.this.id
  source_security_group_id = var.bastion_security_group_id
}

# 各種パラメータを AWS Systems Manager Parameter Store へ保存
# コンテナの環境変数として使う
resource "aws_ssm_parameter" "master_username" {
  name  = "/rds/${local.database_name}/master_username"
  type  = "SecureString"
  value = aws_rds_cluster.this.master_username

  tags = {
    Terraform = "true"
  }
}

resource "aws_ssm_parameter" "master_password" {
  name  = "/rds/${local.database_name}/master_password"
  type  = "SecureString"
  value = aws_rds_cluster.this.master_password

  tags = {
    Terraform = "true"
  }
}

resource "aws_ssm_parameter" "port" {
  name  = "/rds/${local.database_name}/port"
  type  = "SecureString"
  value = aws_rds_cluster.this.port

  tags = {
    Terraform = "true"
  }
}

resource "aws_ssm_parameter" "database_name" {
  name  = "/rds/${local.database_name}/database_name"
  type  = "SecureString"
  value = aws_rds_cluster.this.database_name

  tags = {
    Terraform = "true"
  }
}

resource "aws_ssm_parameter" "cluster_endpoint" {
  name  = "/rds/${local.database_name}/endpoint_w"
  type  = "SecureString"
  value = aws_rds_cluster.this.endpoint

  tags = {
    Terraform = "true"
  }
}

resource "aws_ssm_parameter" "cluster_reader_endpoint" {
  name  = "/rds/${local.database_name}/endpoint_r"
  type  = "SecureString"
  value = aws_rds_cluster.this.reader_endpoint

  tags = {
    Terraform = "true"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_writer_cpu_utilization" {
  alarm_name          = "RDS Writer CPU Utilization Alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "breaching"
  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.this.id
    Role                = "WRITER"
  }
  alarm_actions             = [var.chatbot_sns_topic_arn]
  insufficient_data_actions = []
  ok_actions                = [var.chatbot_sns_topic_arn]

  tags = {
    Terraform = "true"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_writer_freeable_memory" {
  alarm_name          = "RDS Writer Freeable Memory Alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 209715200 # 200MB
  treat_missing_data  = "breaching"
  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.this.id
    Role                = "WRITER"
  }
  alarm_actions             = [var.chatbot_sns_topic_arn]
  insufficient_data_actions = []
  ok_actions                = [var.chatbot_sns_topic_arn]

  tags = {
    Terraform = "true"
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_writer_database_connections" {
  alarm_name          = "RDS Writer Database Connections Alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 300
  treat_missing_data  = "breaching"
  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.this.id
    Role                = "WRITER"
  }
  alarm_actions             = [var.chatbot_sns_topic_arn]
  insufficient_data_actions = []
  ok_actions                = [var.chatbot_sns_topic_arn]

  tags = {
    Terraform = "true"
  }
}

# READER DBインスタンスに関するアラーム
# READER構築時（インスタンス数2以上）に変更する際に有効化する
# resource "aws_cloudwatch_metric_alarm" "rds_reader_cpu_utilization" {
#   alarm_name          = "RDS Reader CPU Utilization Alarm"
#   comparison_operator = "GreaterThanOrEqualToThreshold"
#   evaluation_periods  = 1
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/RDS"
#   period              = 60
#   statistic           = "Average"
#   threshold           = 80
#   treat_missing_data  = "breaching"
#   dimensions = {
#     DBClusterIdentifier = aws_rds_cluster.this.id
#     Role                = "READER"
#   }
#   alarm_actions             = [var.chatbot_sns_topic_arn]
#   insufficient_data_actions = []
#   ok_actions                = [var.chatbot_sns_topic_arn]
# 
#   tags = {
#     Terraform = "true"
#   }
# }
# 
# resource "aws_cloudwatch_metric_alarm" "rds_reader_freeable_memory" {
#   alarm_name          = "RDS Reader Freeable Memory Alarm"
#   comparison_operator = "LessThanThreshold"
#   evaluation_periods  = 1
#   metric_name         = "FreeableMemory"
#   namespace           = "AWS/RDS"
#   period              = 60
#   statistic           = "Average"
#   threshold           = 209715200 # 200MB
#   treat_missing_data  = "breaching"
#   dimensions = {
#     DBClusterIdentifier = aws_rds_cluster.this.id
#     Role                = "READER"
#   }
#   alarm_actions             = [var.chatbot_sns_topic_arn]
#   insufficient_data_actions = []
#   ok_actions                = [var.chatbot_sns_topic_arn]
# 
#   tags = {
#     Terraform = "true"
#   }
# }
# 
# resource "aws_cloudwatch_metric_alarm" "rds_reader_database_connections" {
#   alarm_name          = "RDS Reader Database Connections Alarm"
#   comparison_operator = "GreaterThanOrEqualToThreshold"
#   evaluation_periods  = 1
#   metric_name         = "DatabaseConnections"
#   namespace           = "AWS/RDS"
#   period              = 60
#   statistic           = "Average"
#   threshold           = 300
#   treat_missing_data  = "breaching"
#   dimensions = {
#     DBClusterIdentifier = aws_rds_cluster.this.id
#     Role                = "READER"
#   }
#   alarm_actions             = [var.chatbot_sns_topic_arn]
#   insufficient_data_actions = []
#   ok_actions                = [var.chatbot_sns_topic_arn]
# 
#   tags = {
#     Terraform = "true"
#   }
# }

resource "aws_cloudwatch_event_rule" "this" {
  name        = "rds-event-rule"
  description = "Rule to capture RDS events for availability, failure, low storage, etc."
  event_pattern = jsonencode({
    source = [
      "aws.rds"
    ],
    "detail-type" = [
      "RDS DB Instance Event"
    ],
    detail = {
      EventCategories = [
        "availability",
        "failure",
        "low storage",
        "maintenance",
        "notification",
        "recovery"
      ]
    }
  })

  tags = {
    Terraform = "true"
  }
}

resource "aws_cloudwatch_event_target" "this" {
  target_id = "rds-event-rule-target"
  rule      = aws_cloudwatch_event_rule.this.name
  arn       = var.chatbot_sns_topic_arn
}

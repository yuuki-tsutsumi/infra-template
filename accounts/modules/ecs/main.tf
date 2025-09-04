resource "aws_ecs_cluster" "this" {
  name = "ecs-cluster"

  tags = {
    Terraform = "true"
  }
}

resource "aws_ecs_service" "this" {
  name            = "ecs-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn

  desired_count        = 2
  launch_type          = "FARGATE"
  platform_version     = "1.4.0"
  force_new_deployment = true

  network_configuration {
    subnets         = var.subnets
    security_groups = [aws_security_group.this.id]
  }

  load_balancer {
    target_group_arn = var.lb_target_group.arn
    container_name   = "app"
    container_port   = "80"
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = {
    Terraform = "true"
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = "task-definition"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  container_definitions = jsonencode([
    {
      name = "app"
      # 暫定で nginx を立てる
      # 別途 CD でイメージを上書きする
      image = "nginx:latest"
      logConfiguration : {
        logDriver : "awslogs",
        options : {
          awslogs-region : "ap-northeast-1",
          awslogs-stream-prefix : var.service_name,
          awslogs-group : "/ecs/${var.service_name}"
        }
      }
      portMappings = [
        {
          containerPort = 80
        }
      ]
    }
  ])
  task_role_arn      = aws_iam_role.this.arn
  execution_role_arn = aws_iam_role.this.arn

  tags = {
    Terraform = "true"
  }
}


resource "aws_security_group" "this" {
  name        = "security-group-ecs"
  description = "security-group-ecs"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.lb_security_group_id]
  }
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

resource "aws_cloudwatch_log_group" "this" {
  name = "/ecs/${var.service_name}"

  tags = {
    Terraform = "true"
  }
}

resource "aws_iam_role" "this" {
  name = "ecs-execution-role"

  tags = {
    Terraform = "true"
  }

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "ecs-tasks.amazonaws.com",
          "ssm.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "this" {
  name = "ecs-execution-role-policy"
  role = aws_iam_role.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameters",
          "kms:Decrypt",
          "secretsmanager:GetSecretValue",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = {
    Terraform = "true"
  }
}

resource "aws_appautoscaling_policy" "scale_out" {
  name               = "scale-out"
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  policy_type        = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

resource "aws_appautoscaling_policy" "scale_in" {
  name               = "scale-in"
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  policy_type        = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization_high_scale_out_trigger" {
  alarm_name          = "ECS CPU High Scale Out Trigger Alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "Monitors ECS CPU utilization for scale-out when exceeds 70%"
  alarm_actions       = [aws_appautoscaling_policy.scale_out.arn]

  dimensions = {
    ServiceName = aws_ecs_service.this.name
    ClusterName = aws_ecs_cluster.this.name
  }

  tags = {
    Terraform = "true"
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization_low_scale_in_trigger" {
  alarm_name          = "ECS CPU Low Scale In Trigger Alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "30"
  alarm_description   = "Monitors ECS CPU utilization for scale-in when below 30%"
  alarm_actions       = [aws_appautoscaling_policy.scale_in.arn]

  dimensions = {
    ServiceName = aws_ecs_service.this.name
    ClusterName = aws_ecs_cluster.this.name
  }

  tags = {
    Terraform = "true"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization" {
  alarm_name          = "ECS CPU Utilization Alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "breaching"
  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.this.name
  }
  alarm_actions             = [var.chatbot_sns_topic_arn]
  insufficient_data_actions = []
  ok_actions                = [var.chatbot_sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization" {
  alarm_name          = "ECS Memory Utilization Alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "breaching"
  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.this.name
  }
  alarm_actions             = [var.chatbot_sns_topic_arn]
  insufficient_data_actions = []
  ok_actions                = [var.chatbot_sns_topic_arn]

  tags = {
    Terraform = "true"
  }
}

resource "aws_cloudwatch_log_metric_filter" "ecs_error_filter" {
  name           = "ecs-service-error-filter"
  log_group_name = aws_cloudwatch_log_group.this.name
  pattern        = "ERROR"

  metric_transformation {
    name          = "EcsLogsErrorCount"
    namespace     = "CloudwatchLogsCount"
    value         = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_error_alarm" {
  alarm_name                = "ECS Error Alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "EcsLogsErrorCount"
  namespace                 = "CloudwatchLogsCount"
  period                    = 60
  statistic                 = "Sum"
  threshold                 = 1
  treat_missing_data        = "notBreaching"
  alarm_actions             = [var.chatbot_sns_topic_arn]
  insufficient_data_actions = []
  ok_actions                = [var.chatbot_sns_topic_arn]
}

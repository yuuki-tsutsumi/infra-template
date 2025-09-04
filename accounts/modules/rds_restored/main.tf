locals {
  engine         = "aurora-postgresql"
  engine_version = "16.8"
  instance_class = "db.t4g.medium"
  database_name  = "restoreddb"
  snapshot_id    = "manual-cluster-appdb-20250713221105"
}

resource "aws_rds_cluster" "this" {
  cluster_identifier = "cluster-${local.database_name}"

  snapshot_identifier             = local.snapshot_id
  availability_zones              = var.azs
  port                            = 5432
  vpc_security_group_ids          = [var.rds_security_group_id]
  db_subnet_group_name            = var.db_subnet_group_name
  db_cluster_parameter_group_name = "rds-cluster-parameter-group-tempdb"
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

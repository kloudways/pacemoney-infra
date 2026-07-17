resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = aws_subnet.isolated[*].id

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  identifier        = "${local.name_prefix}-rds"
  engine            = "postgres"
  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = var.app_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az                = false
  publicly_accessible     = false
  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name = "${local.name_prefix}-rds"
  }
}

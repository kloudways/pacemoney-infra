locals {
  db_url = "postgresql+psycopg2://${var.db_username}:${var.db_password}@${aws_db_instance.main.address}:5432/${var.app_name}"
}

resource "aws_secretsmanager_secret" "db_url" {
  name                    = "${var.app_name}/db-url"
  recovery_window_in_days = 0

  tags = {
    Name = "${local.name_prefix}-db-url"
  }
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id     = aws_secretsmanager_secret.db_url.id
  secret_string = local.db_url
}

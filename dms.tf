# Security Group for DMS
resource "aws_security_group" "dms_sg" {
  name        = "dms-replication-sg"
  description = "Security Group for DMS Replication Instance"
  vpc_id      = aws_vpc.main.id

  # Outbound: Allow DMS to talk to everything (EC2 and RDS)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# SUBNET GROUP (Where DMS lives)
resource "aws_dms_replication_subnet_group" "dms_subnet_group" {
  replication_subnet_group_description = "DMS Subnet Group"
  replication_subnet_group_id          = "dms-subnet-group"

  # DMS should run in the PUBLIC subnet to easily reach the EC2 instance
  # (Or private, if peering is set up, but public is easier for this tutorial)
  subnet_ids = [
    aws_subnet.private.id,
    aws_subnet.private_subnet_2.id
  ]

  tags = {
    Name = "dms-subnet-group"
  }
}
# 3. Replication Instance (The "Worker")
resource "aws_dms_replication_instance" "dms_instance" {
  replication_instance_id    = "my-dms-instance"
  replication_instance_class = "dms.t3.micro" # Free Tier eligible
  allocated_storage          = 20

  vpc_security_group_ids      = [aws_security_group.dms_sg.id]
  replication_subnet_group_id = aws_dms_replication_subnet_group.dms_subnet_group.id

  publicly_accessible = true # Helps with debugging, turn off for prod

  tags = {
    Name = "My-DMS-Instance"
  }
}

# 4. Source Endpoint (Your EC2 Postgres)
resource "aws_dms_endpoint" "source" {
  endpoint_id   = "source-ec2-postgres"
  endpoint_type = "source"
  engine_name   = "postgres"

  # Connection Details
  username      = "flask_user"                          # Must match your EC2 DB user
  password      = "admin"                               # Must match your EC2 DB password
  server_name   = aws_instance.public_server.private_ip # Uses Private IP for speed/security
  port          = 5432
  database_name = "flask_db"

  ssl_mode = "none"

  tags = {
    Name = "Source-EC2"
  }
}

# 5. Target Endpoint (Your RDS Postgres)
resource "aws_dms_endpoint" "target" {
  endpoint_id   = "target-rds-postgres"
  endpoint_type = "target"
  engine_name   = "postgres"

  # Connection Details
  username      = var.db_username                  # From variables.tf
  password      = var.db_password                  # From variables.tf
  server_name   = aws_db_instance.postgres.address # The RDS endpoint
  port          = 5432
  database_name = "flask_db"

  ssl_mode = "none"

  tags = {
    Name = "Target-RDS"
  }
}

#6. MIGRATION TASK (The "Job")
resource "aws_dms_replication_task" "migrate_data" {
  replication_task_id = "migrate-ec2-to-rds"
  migration_type      = "full-load" # Copies data once. Use "cdc" for continuous sync.
  table_mappings      = "{\"rules\":[{\"rule-type\":\"selection\",\"rule-id\":\"1\",\"rule-name\":\"1\",\"object-locator\":{\"schema-name\":\"public\",\"table-name\":\"%\"},\"rule-action\":\"include\"}]}"

  replication_instance_arn = aws_dms_replication_instance.dms_instance.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target.endpoint_arn

  # Start the task automatically when created? 
  start_replication_task = true

  tags = {
    Name = "Migration-Task"
  }
}

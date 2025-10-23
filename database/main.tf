# ============================================
# AWS Aurora PostgreSQL Serverless v2
# ============================================

# VPC e Subnets (usar uma existente ou criar uma nova)
# Para simplificar, vamos criar uma VPC e subnets básicas aqui.
# Em um cenário real, você provavelmente usaria uma VPC existente.
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_a_cidr_block
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "${var.project_name}-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_b_cidr_block
  availability_zone = "${var.aws_region}b"
  tags = {
    Name = "${var.project_name}-private-b"
  }
}

# Grupo de Subnets para o RDS
resource "aws_db_subnet_group" "aurora_snet" {
  name       = "${var.project_name}-aurora-snet"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  tags = {
    Name = "${var.project_name}-Aurora-Subnet-Group"
  }
}

# Security Group para permitir acesso ao banco
resource "aws_security_group" "aurora_sg" {
  name        = "${var.project_name}-aurora-sg"
  description = "Allow traffic to Aurora PostgreSQL"
  vpc_id      = aws_vpc.main.id

  # Permite tráfego na porta do PostgreSQL (5432) de dentro da VPC
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block] # Apenas da própria VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Cluster Aurora Serverless v2
resource "aws_rds_cluster" "aurora_serverless" {
  cluster_identifier      = "${var.project_name}-cluster"
  engine                  = "aurora-postgresql"
  engine_version          = var.aurora_engine_version
  database_name           = var.aurora_database_name
  master_username         = var.aurora_master_username
  manage_master_user_password = true # AWS Secrets Manager gerencia a senha
  db_subnet_group_name    = aws_db_subnet_group.aurora_snet.name
  vpc_security_group_ids  = [aws_security_group.aurora_sg.id]
  skip_final_snapshot     = true # Para testes. Em produção, use 'false'
  deletion_protection     = false # Para testes. Em produção, use 'true'
}

resource "aws_rds_cluster_instance" "aurora_instance" {
  identifier         = "${var.project_name}-instance-1"
  cluster_identifier = aws_rds_cluster.aurora_serverless.id
  instance_class     = var.aurora_instance_class
  engine             = aws_rds_cluster.aurora_serverless.engine
  engine_version     = aws_rds_cluster.aurora_serverless.engine_version
}
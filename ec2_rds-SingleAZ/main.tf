provider "aws" {
  region = "ap-northeast-1"
}


############################################################
#### parameters

variable "instance_type" {
  default = "t3.micro"
}

variable "ami_id" {
  default = "ami-0a211f4f633a3af5f"
}

############################################################
### VPC

resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
}

############################################################
### Public subnet

resource "aws_subnet" "public_0" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1a"
  tags = {
    Name = "example_public_1a"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1c"
  tags = {
    Name = "example_public_1c"
  }
}

############################################################
### Internet Gateway

resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id
}

############################################################
### Route Table

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route" "example" {
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.example.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "example" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_0.id
}

############################################################
#### EC2

resource "aws_instance" "example" {
  subnet_id              = aws_subnet.public_0.id
  ami                    = var.ami_id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.example.name
  vpc_security_group_ids = [aws_security_group.example_ec2.id]
  user_data              = file("./user_data.sh")
}

############################################################
#### Security Group

resource "aws_security_group" "example_ec2" {
  name   = "example-ec2"
  vpc_id = aws_vpc.example.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################################
#### KMS

resource "aws_kms_key" "example" {
  description             = "Example Customer Master key"
  enable_key_rotation     = true
  is_enabled              = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "example" {
  name          = "alias/example"
  target_key_id = aws_kms_key.example.key_id
}

############################################################
#### RDS

resource "aws_db_parameter_group" "example" {
  name   = "example"
  family = "mysql8.0"

  parameter {
    name  = "character_set_database"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
}

resource "aws_db_option_group" "example" {
  name                     = "example"
  option_group_description = "Terraform Option Group"
  engine_name              = "mysql"
  major_engine_version     = "8.0"
  option {
    option_name = "MARIADB_AUDIT_PLUGIN"
  }
}

resource "aws_db_subnet_group" "example" {
  name       = "example"
  subnet_ids = [aws_subnet.public_0.id, aws_subnet.public_1.id]
}

resource "aws_db_instance" "example" {
  identifier                  = "example"
  engine                      = "mysql"
  engine_version              = "8.0"
  instance_class              = "db.t3.micro"
  allocated_storage           = 20
  max_allocated_storage       = 100
  storage_type                = "gp2"
  storage_encrypted           = true
  kms_key_id                  = aws_kms_key.example.arn
  username                    = "admin"
  password                    = "password!"
  multi_az                    = false
  publicly_accessible         = false
  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true
  backup_retention_period     = 1
  backup_window               = "10:00-10:30"
  maintenance_window          = "Sun:11:00-Sun:11:30"
  copy_tags_to_snapshot       = true
  delete_automated_backups    = true
  deletion_protection         = false
  skip_final_snapshot         = true
  port                        = 3306
  apply_immediately           = false
  parameter_group_name        = aws_db_parameter_group.example.name
  option_group_name           = aws_db_option_group.example.name
  db_subnet_group_name        = aws_db_subnet_group.example.name
  vpc_security_group_ids      = [module.mysql_sg.security_group_id]
  lifecycle {
    # passwordの変更はTerraformとして無視する。
    # セキュリティの観点からインスタンス構築後、手動でパスワードを変更するため。
    ignore_changes = [password]
  }
}

module "mysql_sg" {
  source      = "./security_group"
  name        = "mysql-sg"
  vpc_id      = aws_vpc.example.id
  port        = 3306
  cidr_blocks = [aws_vpc.example.cidr_block]
}

############################################################
#### IAM

# AmazonSSMManagedInstanceCore policyを付加したロールを作成
resource "aws_iam_role" "example" {
  name               = "example"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "example_policy_ssm_managed_instance_core" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.example.name
  policy_arn = data.aws_iam_policy.example_policy_ssm_managed_instance_core.arn
}

resource "aws_iam_instance_profile" "example" {
  name = "example"
  role = aws_iam_role.example.name
}

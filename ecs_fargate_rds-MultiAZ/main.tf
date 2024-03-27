
provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = {
      Worker = "YusukeIkeda"
      Date   = "2024/03/21"
    }
  }
}


############################################################
### VPC

resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.prefix}-${var.system_Name}-vpc"
  }
}

############################################################
### Public subnet

resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1a"
  tags = {
    Name = "${var.prefix}-${var.system_Name}-public-1a"
  }
}

resource "aws_subnet" "public_1c" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1c"
  tags = {
    Name = "${var.prefix}-${var.system_Name}-public-1c"
  }
}

############################################################
### Private subnet

resource "aws_subnet" "private_1a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.65.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-northeast-1a"
  tags = {
    Name = "${var.prefix}-${var.system_Name}-private-1a"
  }
}

resource "aws_subnet" "private_1c" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.66.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-northeast-1c"
  tags = {
    Name = "${var.prefix}-${var.system_Name}-private-1c"
  }
}

############################################################
### Internet Gateway

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.prefix}-${var.system_Name}-igw"
  }
}

############################################################
### EIP・NAT Gateway

resource "aws_eip" "nat_gateway_1a" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]
  tags = {
    Name = "${var.prefix}-${var.system_Name}-eip-1a"
  }
}

resource "aws_eip" "nat_gateway_1c" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]
  tags = {
    Name = "${var.prefix}-${var.system_Name}-1c-eip"
  }
}

resource "aws_nat_gateway" "nat_gateway_1a" {
  allocation_id = aws_eip.nat_gateway_1a.id
  subnet_id     = aws_subnet.public_1a.id
  depends_on    = [aws_internet_gateway.this]
  tags = {
    Name = "${var.prefix}-${var.system_Name}-public-1a-ngw"
  }
}

resource "aws_nat_gateway" "nat_gateway_1c" {
  allocation_id = aws_eip.nat_gateway_1c.id
  subnet_id     = aws_subnet.public_1c.id
  depends_on    = [aws_internet_gateway.this]
  tags = {
    Name = "${var.prefix}-${var.system_Name}-public-1c-ngw"
  }
}

############################################################
### Route tables (private)

resource "aws_route_table" "private_1a" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.prefix}-${var.system_Name}-private-1a-rt"
  }
}

resource "aws_route_table" "private_1c" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.prefix}-${var.system_Name}-private-1c-rt"
  }
}

resource "aws_route" "private_1a" {
  route_table_id         = aws_route_table.private_1a.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_1a.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "private_1c" {
  route_table_id         = aws_route_table.private_1c.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_1c.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private_1a.id
}

resource "aws_route_table_association" "private_1c" {
  subnet_id      = aws_subnet.private_1c.id
  route_table_id = aws_route_table.private_1c.id
}

############################################################
### Route tables (public)

resource "aws_route_table" "public_1a" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.prefix}-${var.system_Name}-public-1a-rt"
  }
}

resource "aws_route_table" "public_1c" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.prefix}-${var.system_Name}-public-1c-rt"
  }
}

resource "aws_route" "public_1a" {
  route_table_id         = aws_route_table.public_1a.id
  gateway_id             = aws_internet_gateway.this.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "public_1c" {
  route_table_id         = aws_route_table.public_1c.id
  gateway_id             = aws_internet_gateway.this.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public_1a.id
}

resource "aws_route_table_association" "public_1c" {
  subnet_id      = aws_subnet.public_1c.id
  route_table_id = aws_route_table.public_1c.id
}

#############################################################
#### S3 Bucket

resource "aws_s3_bucket" "alb_log" {
  bucket = "tf-alb-log-s3bucket-example"
  tags = {
    Name = "${var.prefix}-${var.system_Name}-s3-alb-log"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_log" {
  bucket = aws_s3_bucket.alb_log.id
  rule {
    status = "Enabled"
    id     = "s3-example-lifecycle"
    expiration {
      days = 180
    }
  }
}

#############################################################
#### Route53

data "aws_route53_zone" "this" {
  name = "aws-manager.net" //実際にドメインを取得する必要がある
}

resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = data.aws_route53_zone.this.name
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

output "domain_name" {
  value = aws_route53_record.this.name
}

#############################################################
#### ACM
// ACMのCNAMEの設定は手動
resource "aws_acm_certificate" "example" {
  domain_name       = "aws-manager.net"
  validation_method = "DNS"
  tags = {
    Name = "aws-manager.net"
  }
  lifecycle {
    create_before_destroy = true
  }
}


#############################################################
#### ALB

module "http_sg" {
  source      = "./security_group"
  name        = "http-sg"
  vpc_id      = aws_vpc.this.id
  port        = 80
  cidr_blocks = ["0.0.0.0/0"]

}

module "https_sg" {
  source      = "./security_group"
  name        = "https-sg"
  vpc_id      = aws_vpc.this.id
  port        = 443
  cidr_blocks = ["0.0.0.0/0"]
}

module "http_redirect_sg" {
  source      = "./security_group"
  name        = "https-redirect-sg"
  vpc_id      = aws_vpc.this.id
  port        = 8080
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_lb" "this" {
  name                       = "aws-manager"
  load_balancer_type         = "application"
  internal                   = false
  idle_timeout               = 60
  enable_deletion_protection = false

  subnets = [
    aws_subnet.public_1a.id,
    aws_subnet.public_1c.id,
  ]

  security_groups = [
    module.http_sg.security_group_id,
    module.https_sg.security_group_id,
    module.http_redirect_sg.security_group_id,
  ]
  tags = {
    Name = "${var.prefix}-${var.system_Name}-lb"
  }
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}


#############################################################
#### TargetGroup

resource "aws_lb_target_group" "this" {
  name                 = "${var.prefix}-${var.system_Name}-tg"
  target_type          = "ip" //インスタンスIDを使う場合はinstanceを指定
  vpc_id               = aws_vpc.this.id
  port                 = 80
  protocol             = "HTTP"
  deregistration_delay = 300

  health_check {
    path                = "/"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = 200
    port                = "traffic-port"
    protocol            = "HTTP"
  }
  tags = {
    Name = "${var.prefix}-${var.system_Name}-tg"
  }
}

#############################################################
#### ALB Listener

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.example.arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_lb_listener" "redirect_http_to_https" {
  load_balancer_arn = aws_lb.this.arn
  port              = "8080"
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener_rule" "example" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}


#############################################################
#### ECS Cluster

resource "aws_ecs_cluster" "this" {
  name = "${var.prefix}-${var.system_Name}-cluster"
}

#### ECS Task
resource "aws_ecs_task_definition" "web" {
  family                   = "web"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  container_definitions    = file("./container_definitions.json")
}

### ECS Service
resource "aws_ecs_service" "service" {
  name                              = "service"
  cluster                           = aws_ecs_cluster.this.id
  task_definition                   = aws_ecs_task_definition.web.arn
  desired_count                     = 2
  launch_type                       = "FARGATE"
  platform_version                  = "1.3.0"
  health_check_grace_period_seconds = 60
  network_configuration {
    assign_public_ip = false
    security_groups  = [module.nginx_sg.security_group_id]
    subnets = [
      aws_subnet.private_1a.id,
      aws_subnet.private_1c.id,
    ]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "example"
    container_port   = 80
  }
  lifecycle {
    ignore_changes = [task_definition]
  }
}

module "nginx_sg" {
  source      = "./security_group"
  name        = "nginx-sg"
  vpc_id      = aws_vpc.this.id
  port        = 80
  cidr_blocks = [aws_vpc.this.cidr_block]
}


############################################################
#### KMS

resource "aws_kms_key" "this" {
  description             = "Example Customer Master key"
  enable_key_rotation     = true
  is_enabled              = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "this" {
  name          = "alias/key-${var.prefix}-${var.system_Name}"
  target_key_id = aws_kms_key.this.key_id
}

#############################################################
#### RDS

resource "aws_db_parameter_group" "this" {
  name   = "${var.prefix}-${var.system_Name}-mysql80-parameter"
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

resource "aws_db_option_group" "this" {
  name                     = "${var.prefix}-${var.system_Name}-mysql80-option"
  option_group_description = "Terraform Option Group"
  engine_name              = "mysql"
  major_engine_version     = "8.0"
  option {
    option_name = "MARIADB_AUDIT_PLUGIN"
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.prefix}-${var.system_Name}-subnet-group"
  subnet_ids = [aws_subnet.private_1a.id, aws_subnet.private_1c.id]
}

resource "aws_db_instance" "this" {
  identifier                  = "${var.prefix}-${var.system_Name}"
  engine                      = "mysql"
  engine_version              = "8.0"
  instance_class              = "db.t3.micro"
  allocated_storage           = 20
  max_allocated_storage       = 100
  storage_type                = "gp2"
  storage_encrypted           = true
  kms_key_id                  = aws_kms_key.this.arn
  username                    = "admin"
  password                    = "muBTDfzH(Ds%,Zgq.!ShU9qv" //Dummy
  multi_az                    = false
  publicly_accessible         = false
  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true
  backup_retention_period     = 1
  copy_tags_to_snapshot       = true
  delete_automated_backups    = true
  deletion_protection         = false
  skip_final_snapshot         = true
  port                        = 3306
  apply_immediately           = false
  parameter_group_name        = aws_db_parameter_group.this.name
  option_group_name           = aws_db_option_group.this.name
  db_subnet_group_name        = aws_db_subnet_group.this.name
  vpc_security_group_ids      = [module.mysql_sg.security_group_id]
  lifecycle {
    # passwordの変更はTerraformとして無視する。
    # セキュリティの観点からインスタンス構築後、手動でパスワードを変更するため。
    ignore_changes = [password]
  }
  tags = {
    Name = "${var.prefix}-${var.system_Name}-rds"
  }
}

module "mysql_sg" {
  source      = "./security_group"
  name        = "mysql-sg"
  vpc_id      = aws_vpc.this.id
  port        = 3306
  cidr_blocks = [aws_vpc.this.cidr_block]
}

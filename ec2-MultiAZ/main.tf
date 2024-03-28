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
    Name = "${var.prefix}-${var.system_Name}-public_1a"
  }
}

resource "aws_subnet" "public_1c" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1c"
  tags = {
    Name = "${var.prefix}-${var.system_Name}-public_1c"
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
    Name = "${var.prefix}-${var.system_Name}-private_1a"
  }
}

resource "aws_subnet" "private_1c" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.66.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-northeast-1c"
  tags = {
    Name = "${var.prefix}-${var.system_Name}-private_1c"
  }
}

############################################################
### EIP・NAT Gateway

resource "aws_eip" "nat_gateway_0" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]
}

resource "aws_eip" "nat_gateway_1" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "nat_gateway_0" {
  allocation_id = aws_eip.nat_gateway_0.id
  subnet_id     = aws_subnet.public_1a.id
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "nat_gateway_1" {
  allocation_id = aws_eip.nat_gateway_1.id
  subnet_id     = aws_subnet.public_1c.id
  depends_on    = [aws_internet_gateway.this]
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
### Route tables (private)

resource "aws_route_table" "private_1a" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.prefix}-${var.system_Name}-rt-1a"
  }
}

resource "aws_route_table" "private_1c" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.prefix}-${var.system_Name}-rt-1c"
  }
}

resource "aws_route" "private_1a" {
  route_table_id         = aws_route_table.private_1a.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_0.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "private_1c" {
  route_table_id         = aws_route_table.private_1c.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_1.id
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
}

resource "aws_route_table" "public_1c" {
  vpc_id = aws_vpc.this.id
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
## ACMの取得は一旦手動にする

resource "aws_acm_certificate" "this" {
  domain_name       = "aws-manager.net"
  validation_method = "DNS"
  tags = {
    Name = "${var.prefix}-${var.system_Name}-acm"
  }
  lifecycle {
    create_before_destroy = true
  }
}

#############################################################
#### ALB

module "http_sg" {
  source      = "./modules/security_group"
  name        = "http-sg"
  vpc_id      = aws_vpc.this.id
  port        = 80
  cidr_blocks = ["0.0.0.0/0"]
}

module "https_sg" {
  source      = "./modules/security_group"
  name        = "https-sg"
  vpc_id      = aws_vpc.this.id
  port        = 443
  cidr_blocks = ["0.0.0.0/0"]
}

module "http_redirect_sg" {
  source      = "./modules/security_group"
  name        = "https-redirect-sg"
  vpc_id      = aws_vpc.this.id
  port        = 8080
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_lb" "this" {
  name   = "${var.prefix}-${var.system_Name}-alb"
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
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
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
  certificate_arn   = aws_acm_certificate.this.arn
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

resource "aws_lb_listener_rule" "this" {
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
#### TargetGroup

resource "aws_lb_target_group" "this" {
  name                 = "targetgroup"
  target_type          = "instance" // ECSの場合は ip と指定
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
}

// TargetGroupをinstanceに紐づける
resource "aws_lb_target_group_attachment" "for_web_server_a" {
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = aws_instance.instance_1a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "for_web_server_c" {
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = aws_instance.instance_1c.id
  port             = 80
}

############################################################
#### EC2

resource "aws_instance" "instance_1a" {
  subnet_id              = aws_subnet.private_1a.id
  ami                    = var.ami_id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  user_data              = file("./sh/user_data.sh")
  tags = {
    Name = "${var.prefix}-${var.system_Name}-1a"
  }
}

resource "aws_instance" "instance_1c" {
  subnet_id              = aws_subnet.private_1c.id
  ami                    = var.ami_id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  user_data              = file("./sh/user_data.sh")
  tags = {
    Name = "${var.prefix}-${var.system_Name}-1c"
  }
}

############################################################
#### Security Group

resource "aws_security_group" "this" {
  name   = "${var.prefix}-${var.system_Name}-sg"
  vpc_id = aws_vpc.this.id

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
#### SSM接続用のIAM

resource "aws_iam_role" "this" {
  name               = "${var.prefix}-${var.system_Name}-role"
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

data "aws_iam_policy" "policy_ssm_managed_instance_core" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.this.name
  policy_arn = data.aws_iam_policy.policy_ssm_managed_instance_core.arn
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.prefix}-${var.system_Name}-iam"
  role = aws_iam_role.this.name
}




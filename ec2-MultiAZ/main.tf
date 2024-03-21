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
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    "Name" = "example"
  }
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
    Name = "example_public_1a"
  }
}

############################################################
### Private subnet

resource "aws_subnet" "private_0" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.65.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-northeast-1a"
  tags = {
    Name = "example_private_1a"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.66.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-northeast-1c"
  tags = {
    Name = "example_private_1c"
  }
}

############################################################
### EIP・NAT Gateway

resource "aws_eip" "nat_gateway_0" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.example]
}

resource "aws_eip" "nat_gateway_1" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.example]
}

resource "aws_nat_gateway" "nat_gateway_0" {
  allocation_id = aws_eip.nat_gateway_0.id
  subnet_id     = aws_subnet.public_0.id
  depends_on    = [aws_internet_gateway.example]
}

resource "aws_nat_gateway" "nat_gateway_1" {
  allocation_id = aws_eip.nat_gateway_1.id
  subnet_id     = aws_subnet.public_1.id
  depends_on    = [aws_internet_gateway.example]
}

############################################################
### Internet Gateway

resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id
}

############################################################
### Route tables (private)

resource "aws_route_table" "private_0" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route" "private_0" {
  route_table_id         = aws_route_table.private_0.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_0.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "private_1" {
  route_table_id         = aws_route_table.private_1.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_1.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "private_0" {
  subnet_id      = aws_subnet.private_0.id
  route_table_id = aws_route_table.private_0.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

############################################################
### Route tables (public)

resource "aws_route_table" "public_0" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route_table" "public_1" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route" "public_0" {
  route_table_id         = aws_route_table.public_0.id
  gateway_id             = aws_internet_gateway.example.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "public_1" {
  route_table_id         = aws_route_table.public_1.id
  gateway_id             = aws_internet_gateway.example.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "public_0" {
  subnet_id      = aws_subnet.public_0.id
  route_table_id = aws_route_table.public_0.id
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_1.id
}

#############################################################
#### Route53

data "aws_route53_zone" "example" {
  name = "aws-manager.net" //実際にドメインを取得する必要がある
}

resource "aws_route53_record" "example" {
  zone_id = data.aws_route53_zone.example.zone_id
  name    = data.aws_route53_zone.example.name
  type    = "A"

  alias {
    name                   = aws_lb.example.dns_name
    zone_id                = aws_lb.example.zone_id
    evaluate_target_health = true
  }
}

output "domain_name" {
  value = aws_route53_record.example.name
}

#############################################################
#### ACM
## ACMの取得は一旦手動にする

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
  vpc_id      = aws_vpc.example.id
  port        = 80
  cidr_blocks = ["0.0.0.0/0"]
}

module "https_sg" {
  source      = "./security_group"
  name        = "https-sg"
  vpc_id      = aws_vpc.example.id
  port        = 443
  cidr_blocks = ["0.0.0.0/0"]
}

module "http_redirect_sg" {
  source      = "./security_group"
  name        = "https-redirect-sg"
  vpc_id      = aws_vpc.example.id
  port        = 8080
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_lb" "example" {
  name                       = "aws-manager"
  load_balancer_type         = "application"
  internal                   = false
  idle_timeout               = 60
  enable_deletion_protection = false

  subnets = [
    aws_subnet.public_0.id,
    aws_subnet.public_1.id,
  ]

  security_groups = [
    module.http_sg.security_group_id,
    module.https_sg.security_group_id,
    module.http_redirect_sg.security_group_id,
  ]
}

output "alb_dns_name" {
  value = aws_lb.example.dns_name
}

#############################################################
#### ALB Listener

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.example.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.example.arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }
}

resource "aws_lb_listener" "redirect_http_to_https" {
  load_balancer_arn = aws_lb.example.arn
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
    target_group_arn = aws_lb_target_group.example.arn
  }
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

#############################################################
#### TargetGroup

resource "aws_lb_target_group" "example" {
  name                 = "example"
  target_type          = "instance" // ECSの場合は ip と指定
  vpc_id               = aws_vpc.example.id
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
  target_group_arn = aws_lb_target_group.example.arn
  target_id        = aws_instance.instance_0.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "for_web_server_c" {
  target_group_arn = aws_lb_target_group.example.arn
  target_id        = aws_instance.instance_1.id
  port             = 80
}

############################################################
#### EC2

resource "aws_instance" "instance_0" {
  subnet_id              = aws_subnet.private_0.id
  ami                    = var.ami_id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.example.name
  vpc_security_group_ids = [aws_security_group.example_ec2.id]
  user_data              = file("./user_data.sh")
}

resource "aws_instance" "instance_1" {
  subnet_id              = aws_subnet.private_1.id
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
#### SSM接続用のIAM

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




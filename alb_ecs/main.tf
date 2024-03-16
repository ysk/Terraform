
provider "aws" {
  region = "ap-northeast-1"
}

############################################################
#### パラメータ設定

variable "instance_type" {
  default = "t3.micro"
}

variable "ami_id" {
  default = "ami-0a211f4f633a3af5f"
}

############################################################
### VPC

## VPC
resource "aws_vpc" "example_vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    "Name" = "example_vpc"
  }
}

############################################################
### パブリックサブネット

## aws_subnet public_0
resource "aws_subnet" "public_0" {
  vpc_id                  = aws_vpc.example_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1a"
  tags = {
    Name = "example_public_1a"
  }
}

## aws_subnet public_1
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.example_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1c"
  tags = {
    Name = "example_public_1a"
  }
}

############################################################
### プライベートサブネット

## aws_subnet private_0
resource "aws_subnet" "private_0" {
  vpc_id                  = aws_vpc.example_vpc.id
  cidr_block              = "10.0.65.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-northeast-1a"
  tags = {
    Name = "example_private_1a"
  }
}
## aws_subnet private_1
resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.example_vpc.id
  cidr_block              = "10.0.66.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-northeast-1c"
  tags = {
    Name = "example_private_1c"
  }
}

############################################################
### インターネットゲートウェイ

## aws_internet_gateway
resource "aws_internet_gateway" "example_igw" {
  vpc_id = aws_vpc.example_vpc.id
}

############################################################
### EIP・NATゲートウェイ

## aws_eip
resource "aws_eip" "nat_gateway_0" {
  vpc        = true
  depends_on = [aws_internet_gateway.example_igw]
}
resource "aws_eip" "nat_gateway_1" {
  vpc        = true
  depends_on = [aws_internet_gateway.example_igw]
}

## aws_nat_gateway
resource "aws_nat_gateway" "nat_gateway_0" {
  allocation_id = aws_eip.nat_gateway_0.id
  subnet_id     = aws_subnet.public_0.id
  depends_on    = [aws_internet_gateway.example_igw]
}
resource "aws_nat_gateway" "nat_gateway_1" {
  allocation_id = aws_eip.nat_gateway_1.id
  subnet_id     = aws_subnet.public_1.id
  depends_on    = [aws_internet_gateway.example_igw]
}

############################################################
### ルートテーブル(プライベート)

resource "aws_route_table" "private_0" {
  vpc_id = aws_vpc.example_vpc.id
}
resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.example_vpc.id
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
### ルートテーブル（パブリック）

resource "aws_route_table" "public_0" {
  vpc_id = aws_vpc.example_vpc.id
}
resource "aws_route_table" "public_1" {
  vpc_id = aws_vpc.example_vpc.id
}

resource "aws_route" "public_0" {
  route_table_id         = aws_route_table.public_0.id
  gateway_id             = aws_internet_gateway.example_igw.id
  destination_cidr_block = "0.0.0.0/0"
}
resource "aws_route" "public_1" {
  route_table_id         = aws_route_table.public_1.id
  gateway_id             = aws_internet_gateway.example_igw.id
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
#### S3バケット
# resource "aws_s3_bucket" "private" {
#   bucket = "tf-s3bucket-example"
#   versioning {
#     enabled = true
#   }
#   server_side_encryption_configuration {
#     rule {
#       apply_server_side_encryption_by_default {
#         sse_algorithm = "AES256"
#       }
#     }
#   }
# }

resource "aws_s3_bucket" "alb_log" {
  bucket = "tf-alb-log-s3bucket-example"
  lifecycle_rule {
    enabled = true
    expiration {
      days = "180"
    }
  }
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
  vpc_id      = aws_vpc.example_vpc.id
  port        = 80
  cidr_blocks = ["0.0.0.0/0"]
}

module "https_sg" {
  source      = "./security_group"
  name        = "https-sg"
  vpc_id      = aws_vpc.example_vpc.id
  port        = 443
  cidr_blocks = ["0.0.0.0/0"]
}

module "http_redirect_sg" {
  source      = "./security_group"
  name        = "https-redirect-sg"
  vpc_id      = aws_vpc.example_vpc.id
  port        = 8080
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_lb" "example" {
  name                       = "example"
  load_balancer_type         = "application"
  internal                   = false
  idle_timeout               = 60
  enable_deletion_protection = false

  subnets = [
    aws_subnet.public_0.id,
    aws_subnet.public_1.id,
  ]

  access_logs {
    bucket  = aws_s3_bucket.alb_log.id
    enabled = true
  }

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
#### ALBリスナー
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "これは『HTTP』です"
      status_code  = "200"
    }
  }
}

# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.example.arn
#   port              = "443"
#   protocol          = "HTTPS"
#   certificate_arn   = aws_acm_certificate.example.arn
#   ssl_policy        = "ELBSecurityPolicy-2016-08"

#   default_action {
#     type = "fixed-response"

#     fixed_response {
#       content_type = "text/plain"
#       message_body = "これは『HTTPS』です"
#       status_code  = "200"
#     }
#   }
# }

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

#############################################################
#### TargetGroup

resource "aws_lb_target_group" "example" {
  name                 = "example"
  target_type          = "ip" //インスタンスIDを使う場合はinstanceを指定
  vpc_id               = aws_vpc.example_vpc.id
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


# resource "aws_lb_listener" "example" {
#   listener_arn = aws_lb_listener.https.arn
#   priotity     = 100

#   action {
#     type            = "forward"
#     Target_grup_arn = aws_lb_target_grop.example.arn
#   }

#   condition {
#     field = "path-pattern"
#     value = ["/*"]
#   }
# }


#############################################################
#### EC2インスタンス

# ## aws_instance
# resource "aws_instance" "example_ec2" {
#   subnet_id     = aws_subnet.private_0.id
#   ami           = var.ami_id
#   instance_type = var.instance_type
#   tags = {
#     Name = "example_ec2"
#   }
# }

# module "example_sg" {
#   source      = "./security_group"
#   name        = "module-sg"
#   vpc_id      = aws_vpc.example_vpc.id
#   port        = 80
#   cidr_blocks = ["0.0.0.0/0"]
# }






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
### Public subnet

resource "aws_subnet" "public_0" {
  vpc_id                  = aws_vpc.example_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1a"
  tags = {
    Name = "example_public_1a"
  }
}

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
### Private subnet

resource "aws_subnet" "private_0" {
  vpc_id                  = aws_vpc.example_vpc.id
  cidr_block              = "10.0.65.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-northeast-1a"
  tags = {
    Name = "example_private_1a"
  }
}

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
### Internet Gateway

resource "aws_internet_gateway" "example_igw" {
  vpc_id = aws_vpc.example_vpc.id
}

############################################################
### EIP・NAT Gateway

resource "aws_eip" "nat_gateway_0" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.example_igw]
}

resource "aws_eip" "nat_gateway_1" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.example_igw]
}

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
### Route tables (private)

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
### Route tables (public)

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
#### S3 Bucket

resource "aws_s3_bucket" "alb_log" {
  bucket = "tf-alb-log-s3bucket-example"
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

# resource "aws_route53_record" "example_certificate" {
#   for_each = {
#     for domain_validation_option in aws_acm_certificate.example.domain_validation_options : domain_validation_option.domain_name => {
#       name   = domain_validation_option.resource_record_name
#       record = domain_validation_option.resource_record_value
#       type   = domain_validation_option.resource_record_type
#     }
#   }
#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = data.aws_route53_zone.example.zone_id
# }

# resource "aws_acm_certificate_validation" "example" {
#   certificate_arn         = aws_acm_certificate.example.arn
#   validation_record_fqdns = [aws_route53_record.example_certificate.validation_record_fqdns]
#}

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
  name                       = "aws-manager"
  load_balancer_type         = "application"
  internal                   = false
  idle_timeout               = 60
  enable_deletion_protection = false

  subnets = [
    aws_subnet.public_0.id,
    aws_subnet.public_1.id,
  ]

  # access_logs {
  #   bucket  = aws_s3_bucket.alb_log.id
  #   enabled = true
  # }

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
#### ECS Cluster

resource "aws_ecs_cluster" "example" {
  name = "example"
}

#### ECS Task
resource "aws_ecs_task_definition" "example" {
  family                   = "example"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  container_definitions    = file("./container_definitions.json")
}

### ECS Service
resource "aws_ecs_service" "example" {
  name                              = "example"
  cluster                           = aws_ecs_cluster.example.id
  task_definition                   = aws_ecs_task_definition.example.arn
  desired_count                     = 2
  launch_type                       = "FARGATE"
  platform_version                  = "1.3.0"
  health_check_grace_period_seconds = 60
  network_configuration {
    assign_public_ip = false
    security_groups  = [module.nginx_sg.security_group_id]
    subnets = [
      aws_subnet.private_0.id,
      aws_subnet.private_1.id,
    ]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.example.arn
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
  vpc_id      = aws_vpc.example_vpc.id
  port        = 80
  cidr_blocks = [aws_vpc.example_vpc.cidr_block]
}

#############################################################
#### RDS


############################################################
#### IAM

data "aws_iam_policy_document" "allow_describe_regions" {
  statement {
    effect    = "Allow"
    actions   = ["ec2:DescribeRegions"] #リージョン一覧を取得する
    resources = ["*"]
  }
}

resource "aws_iam_policy" "example" {
  name   = "example"
  policy = data.aws_iam_policy_document.allow_describe_regions.json
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "example" {
  name               = "example"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "example" {
  role       = aws_iam_role.example.name
  policy_arn = aws_iam_policy.example.arn
}

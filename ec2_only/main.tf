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

resource "aws_subnet" "example" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1a"
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
  subnet_id      = aws_subnet.example.id
}

############################################################
#### EC2

resource "aws_instance" "example" {
  subnet_id              = aws_subnet.example.id
  ami                    = var.ami_id
  instance_type          = var.instance_type
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


# module "describe_regions_for_ec2" {
#   source     = "./iam_role"
#   name       = "describe-regions-for-ec2"
#   identifier = "ec2.amazonaws.com"
#   policy     = data.aws_iam_policy_document.allow_describe_regions.json
# }

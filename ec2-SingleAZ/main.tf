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
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${var.prefix}-${var.system_Name}-vpc"
  }
}

############################################################
### Public subnet

resource "aws_subnet" "this" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-1a"
  tags = {
    Name = "${var.prefix}-${var.system_Name}-1a"
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
### Route Table

resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.prefix}-${var.system_Name}-rt"
  }
}

resource "aws_route" "this" {
  route_table_id         = aws_route_table.this.id
  gateway_id             = aws_internet_gateway.this.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "this" {
  route_table_id = aws_route_table.this.id
  subnet_id      = aws_subnet.this.id
}

############################################################
#### EC2

resource "aws_instance" "this" {
  subnet_id              = aws_subnet.this.id
  ami                    = var.ami_id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  user_data              = file("./user_data.sh")
  tags = {
    Name = "${var.prefix}-${var.system_Name}-instance"
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
  tags = {
    Name = "${var.prefix}-${var.system_Name}-sg"
  }
}

############################################################
#### IAM

# AmazonSSMManagedInstanceCore policyを付加したロールを作成
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

data "aws_iam_policy" "iam_policy_ssm_managed_instance_core" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.this.name
  policy_arn = data.aws_iam_policy.iam_policy_ssm_managed_instance_core.arn
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.prefix}-${var.system_Name}-iam"
  role = aws_iam_role.this.name
}


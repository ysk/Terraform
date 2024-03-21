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


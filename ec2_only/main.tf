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
#### EC2

resource "aws_instance" "example" {
  subnet_id              = aws_subnet.example.id
  ami                    = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.example_ec2.id]
  user_data              = file("./user_data.sh")
}

resource "aws_security_group" "example_ec2" {
  name = "example-ec2"
  vpc_id                  = aws_vpc.example.id

  ingress {
    from_port         = 80
    to_port           = 80
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }

  egress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
  }
}
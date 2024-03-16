
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
### ルートテーブル

resource "aws_route_table" "private_0" {
  vpc_id = aws_vpc.example_vpc.id
}
resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.example_vpc.id
}
resource "aws_route" "private_0" {
  route_table_id = aws_route_table.private_0.id
  nat_gateway_id = aws_nat_gateway.nat_gateway_0.id

  destination_cidr_block = "0.0.0.0/0"
}
resource "aws_route" "private_1" {
  route_table_id         = aws_route_table.private_1.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_1.id
  destination_cidr_block = "0.0.0.0/0"
}

#############################################################
#### EC2インスタンス

## aws_instance
resource "aws_instance" "example_ec2" {
  subnet_id     = aws_subnet.private_0.id
  ami           = var.ami_id
  instance_type = var.instance_type
  tags = {
    Name = "example_ec2"
  }
}

module "example_sg" {
  source      = "./security_group"
  name        = "module-sg"
  vpc_id      = aws_vpc.example_vpc.id
  port        = 80
  cidr_blocks = ["0.0.0.0/0"]
}

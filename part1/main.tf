# terraform setting
terraform {
  required_version = ">= 0.14"
  required_providers {
    aws = ">= 3.50.0"
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

# network setting
## vpc
resource "aws_vpc" "this_vpc" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "intro-terraform"
  }
}

## internet gateway
resource "aws_internet_gateway" "this_igw" {
  vpc_id = aws_vpc.this_vpc.id
  tags = {
    Name = "intro-terraform"
  }
}

## subnet
resource "aws_subnet" "this_public_sub_a" {
  vpc_id            = aws_vpc.this_vpc.id
  cidr_block        = "192.168.0.0/24"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "intro-terraform-subnet-public-a"
  }
}

resource "aws_subnet" "this_public_sub_z" {
  vpc_id            = aws_vpc.this_vpc.id
  cidr_block        = "192.168.1.0/24"
  availability_zone = "ap-northeast-1c"
  tags = {
    Name = "intro-terraform-subnet-public-c"
  }
}

## route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this_igw.id
  }

  tags = {
    Name = "intro-terraform-routetable-public"
  }
}

### route table association
resource "aws_route_table_association" "this_public_a_rt" {
  subnet_id      = aws_subnet.this_public_sub_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "this_public_z_rt" {
  subnet_id      = aws_subnet.this_public_sub_z.id
  route_table_id = aws_route_table.public.id
}

# security group
resource "aws_security_group" "this_public_sg" {
  name   = "intro-terraform-sg-public"
  vpc_id = aws_vpc.this_vpc.id

  tags = {
    Name = "intro-terraform-sg-public"
  }
}

## get my ip
data "http" "ifconfig" {
  url = "http://ipv4.icanhazip.com/"
}

variable "allowed-myip" {
  default = null
}

locals {
  current-ip   = chomp(data.http.ifconfig.body)
  allowed-myip = (var.allowed-myip == null) ? "${local.current-ip}/32" : var.allowed-myip
}

## inbound
resource "aws_security_group_rule" "this_public_sg_in_rule_public" {
  security_group_id = aws_security_group.this_public_sg.id
  type              = "ingress"
  from_port         = "22"
  to_port           = "22"
  protocol          = "TCP"
  cidr_blocks       = ["192.168.0.0/24", "192.168.1.0/24", local.allowed-myip]
}

## outbound
resource "aws_security_group_rule" "this_public_sg_out_rule_all" {
  security_group_id = aws_security_group.this_public_sg.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
}

# EC2 setting
## key setting
resource "aws_key_pair" "this_key" {
  key_name   = "intro-terraform-keypair"
  public_key = file("./id_rsa.pub")
}

resource "aws_instance" "this" {
  ami                         = "ami-0b276ad63ba2d6009"
  vpc_security_group_ids      = [aws_security_group.this_public_sg.id]
  subnet_id                   = aws_subnet.this_public_sub_a.id
  key_name                    = aws_key_pair.this_key.id
  instance_type               = "t2.micro"
  associate_public_ip_address = "true"

  tags = {
    Name = "intro-terraform-ec2-part1"
  }
}
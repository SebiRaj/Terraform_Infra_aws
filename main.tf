terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}

# Create a VPC
resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name="My_VPC_New"
  }
}

resource "aws_subnet" "Private_subnet" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "My_Private_subnet"
  }
}

resource "aws_subnet" "Public_subnet" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "My_Public_subnet"
  }
}

resource "aws_internet_gateway" "MyIGW" {
  vpc_id = aws_vpc.myvpc.id
  tags = {
    Name = "My_IGW"
  }
}

resource "aws_route_table" "pubrt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.MyIGW.id
  }
  tags = {
    Name = "Pub_RT"
  }
}

resource "aws_route_table_association" "pubrtasso" {
  subnet_id      = aws_subnet.Public_subnet.id
  route_table_id = aws_route_table.pubrt.id
}

resource "aws_eip" "myeip" {
  domain   = "vpc"
}

resource "aws_nat_gateway" "TNat" {
  allocation_id = aws_eip.myeip.id
  subnet_id     = aws_subnet.Public_subnet.id

  tags = {
    Name = "NATGW"
  }
}


resource "aws_route_table" "PrivRT" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.TNat.id
  }
  tags = {
    Name = "Private_RT"
  }
}

resource "aws_route_table_association" "privrtasso" {
  subnet_id      = aws_subnet.Private_subnet.id
  route_table_id = aws_route_table.PrivRT.id
}


resource "aws_security_group" "allow_SGall" {
  name        = "allow_SGall"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  tags = {
    Name = "allow_all_SG"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4_443" {
  security_group_id = aws_security_group.allow_SGall.id
  cidr_ipv4         = aws_vpc.myvpc.cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4_22" {
  security_group_id = aws_security_group.allow_SGall.id
  cidr_ipv4         = aws_vpc.myvpc.cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4_80" {
  security_group_id = aws_security_group.allow_SGall.id
  cidr_ipv4         = aws_vpc.myvpc.cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_SGall.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


resource "aws_instance" "Jumpbox" {
  ami           = "ami-0ad21ae1d0696ad58" 
  instance_type = "t2.micro"
  subnet_id = aws_subnet.Public_subnet.id
  vpc_security_group_ids = [aws_security_group.allow_SGall.id]
  key_name = "terraformKeyPair"
  associate_public_ip_address= true
  }


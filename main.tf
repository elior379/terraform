# Variables
variable "access_key" {
  description = "Please enter your AWS access key"
}

variable "secret_key" {
  description = "Please enter your AWS secret key"
}

# AWS Login credentials
provider "aws" {
  region     = "eu-west-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

# VPC 
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

# Internet gateway
resource "aws_internet_gateway" "prod-gw" {
  vpc_id = aws_vpc.prod-vpc.id
  tags = {
    Name = "production"
  }
}

# Route tables
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod-gw.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.prod-gw.id
  }
  tags = {
    Name = "production"
  }
}

# Subnet
resource "aws_subnet" "private-subnet-1" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-1a"
  tags = {
    Name = "production"
  }
}

# Subnet association
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.private-subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# Security groups
resource "aws_security_group" "web-traffic" {
  name        = "web-traffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
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
    Name = "production"
  }
}

# Network interface
resource "aws_network_interface" "prod-nic" {
  subnet_id       = aws_subnet.private-subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.web-traffic.id]

}

# Elastic IP
resource "aws_eip" "prod-eip" {
  vpc                       = true
  associate_with_private_ip = "10.0.1.50"
  network_interface         = aws_network_interface.prod-nic.id
  depends_on                = [aws_internet_gateway.prod-gw]
}


# EC2 Instance 
resource "aws_instance" "web-server" {
  ami               = "ami-063d4ab14480ac177"
  instance_type     = "t2.micro"
  availability_zone = "eu-west-1a"
  key_name          = "dev-vm-key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.prod-nic.id

  }

  user_data = <<-EOF
            !#/bin/bash
            sudo apt update -y
            sudo apt install apache2 -y
            sudo systemctl start apache2
            sudo bash -c 'echo my first server with terraform > var/www/html/index.html'
            EOF

  tags = {
    Name = "production"


  }

}





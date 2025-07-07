terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Generate a random suffix to avoid name duplication
resource "random_id" "suffix" {
  byte_length = 4
}

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Use public key from GitHub Secrets via terraform.tfvars
resource "aws_key_pair" "splunk_key" {
  key_name   = "splunk-key-${random_id.suffix.hex}"
  public_key = var.public_key
}

# Security Group allowing port 8000 (Splunk Web) and SSH
resource "aws_security_group" "splunk_sg" {
  name        = "splunk-sg-${random_id.suffix.hex}"
  description = "Allow Splunk Web and SSH"

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
}

# Launch EC2 instance and install Splunk
resource "aws_instance" "splunk" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.medium"
  key_name      = aws_key_pair.splunk_key.key_name
  security_groups = [aws_security_group.splunk_sg.name]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install wget -y
              wget -O splunk.rpm 'https://download.splunk.com/products/splunk/releases/9.2.1/linux/splunk-9.2.1-b6b9c8185839-linux-2.6-x86_64.rpm'
              rpm -i splunk.rpm
              /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd 'admin123'
              /opt/splunk/bin/splunk enable boot-start
              EOF

  tags = {
    Name = "SplunkServer"
  }
}

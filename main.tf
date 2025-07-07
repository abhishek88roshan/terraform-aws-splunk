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

# Generate a random suffix to avoid name conflicts
resource "random_id" "suffix" {
  byte_length = 4
}

# Get the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Inject SSH public key (to be passed from GitHub Secret or .tfvars)
resource "aws_key_pair" "splunk_key" {
  key_name   = "splunk-key-${random_id.suffix.hex}"
  public_key = var.public_key
}

# Security group to allow Splunk (8000) and SSH (22)
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

# EC2 Instance with Splunk installation via user_data
resource "aws_instance" "splunk" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.medium"
  key_name               = aws_key_pair.splunk_key.key_name
  vpc_security_group_ids = [aws_security_group.splunk_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              set -e
              sudo dnf update -y
              sudo dnf install -y wget
              cd /opt
              wget -O splunk.rpm "https://download.splunk.com/products/splunk/releases/9.4.3/linux/splunk-9.4.3-237ebbd22314.x86_64.rpm"
              rpm -i splunk.rpm

              mkdir -p /opt/splunk/etc/system/local
              cat <<EOT > /opt/splunk/etc/system/local/user-seed.conf
              [user_info]
              USERNAME = admin
              PASSWORD = admin123
              EOT

              /opt/splunk/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt
              /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt
              EOF

  tags = {
    Name = "SplunkServer"
  }
}

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

# Generate random suffix to avoid duplication
resource "random_id" "suffix" {
  byte_length = 4
}

# Fetch latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Inject public key (from GitHub Actions secret)
resource "aws_key_pair" "splunk_key" {
  key_name   = "splunk-key-${random_id.suffix.hex}"
  public_key = var.public_key
}

# Create security group with required ports
resource "aws_security_group" "splunk_sg" {
  name        = "splunk-sg-${random_id.suffix.hex}"
  description = "Allow Splunk Web UI and SSH access"

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

              # Download and install Splunk
              wget -O /tmp/splunk.rpm "https://download.splunk.com/products/splunk/releases/9.2.1/linux/splunk-9.2.1-b6b9c8185839-linux-2.6-x86_64.rpm"
              rpm -i /tmp/splunk.rpm

              # Enable Splunk at boot
              /opt/splunk/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt

              # Set initial admin password
              echo "[user_info]" > /opt/splunk/etc/system/local/user-seed.conf
              echo "USERNAME=admin" >> /opt/splunk/etc/system/local/user-seed.conf
              echo "PASSWORD=admin123" >> /opt/splunk/etc/system/local/user-seed.conf

              # Start Splunk
              /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt

              # Disable firewall (if enabled)
              systemctl stop firewalld || true
              EOF

  tags = {
    Name = "SplunkServer"
  }
}

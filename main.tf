provider "aws" {
  region = "us-east-1"
}

resource "random_pet" "name" {}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "splunk_key" {
  key_name   = "splunk-key-${random_pet.name.id}"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "aws_security_group" "splunk_sg" {
  name        = "splunk-sg-${random_pet.name.id}"
  description = "Allow SSH and Splunk UI"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Splunk UI"
    from_port   = 8000
    to_port     = 8000
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
    Name = "splunk-sg-${random_pet.name.id}"
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "splunk" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.medium"
  key_name               = aws_key_pair.splunk_key.key_name
  vpc_security_group_ids = [aws_security_group.splunk_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              set -e
              sudo dnf update -y
              sudo dnf install -y wget tar

              sudo mkdir -p /opt/downloads
              cd /opt/downloads
              sudo wget -O splunk.rpm "https://download.splunk.com/products/splunk/releases/9.4.3/linux/splunk-9.4.3-237ebbd22314.x86_64.rpm"

              sudo rpm -i splunk.rpm

              sudo mkdir -p /opt/splunk/etc/system/local
              cat <<EOC | sudo tee /opt/splunk/etc/system/local/web.conf
              [settings]
              enableSplunkWebSSL = false
              httpport = 8000
              server.socket_host = 0.0.0.0
              EOC

              sudo /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt
              EOF

  tags = {
    Name = "SplunkServer"
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_key_pair" "splunk_key" {
  key_name   = "splunk-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_security_group" "splunk_sg" {
  name        = "splunk-sg"

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

resource "aws_instance" "splunk" {
  ami           = "ami-0c2b8ca1dad447f8a"
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

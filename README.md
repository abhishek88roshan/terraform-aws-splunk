# terraform-aws-splunk
# Splunk on AWS (Public Access)

This Terraform project deploys a Splunk Enterprise server on AWS EC2 with public internet access.

## Splunk Access
- URL: http://<public-ip>:8000
- Username: `admin`
- Password: `admin123`

## Requirements
- AWS credentials configured
- Terraform installed
- Public SSH key in `~/.ssh/id_rsa.pub`

## Usage
```bash
terraform init
terraform apply

output "splunk_url" {
  description = "Access the Splunk Web UI at this URL"
  value       = "http://${aws_instance.splunk.public_ip}:8000"
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.splunk.public_ip
}

output "key_pair_name" {
  value = aws_key_pair.splunk_key.key_name
}

output "security_group_name" {
  value = aws_security_group.splunk_sg.name
}

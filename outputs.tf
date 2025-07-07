output "splunk_url" {
  value = "http://${aws_instance.splunk.public_ip}:8000"
}

output "key_pair_name" {
  value = aws_key_pair.splunk_key.key_name
}

output "security_group_name" {
  value = aws_security_group.splunk_sg.name
}

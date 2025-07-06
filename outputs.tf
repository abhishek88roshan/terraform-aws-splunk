output "splunk_public_url" {
  value = "http://${aws_instance.splunk.public_ip}:8000"
}

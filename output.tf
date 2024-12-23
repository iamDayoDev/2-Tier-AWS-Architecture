output "instance_public_ip_url" {
  description = "Apache Servers Public IP URL"
  value       = ["http://${aws_instance.apache-server-1.public_ip}", "http://${aws_instance.apache-server-2.public_ip}"]
}
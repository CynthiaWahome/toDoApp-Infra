output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = module.ec2.public_ip
}

output "application_url" {
  description = "URL to access the application"
  value       = "https://${var.domain_name}"
}

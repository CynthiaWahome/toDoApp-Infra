# This file contains the Terraform code to create an EC2 instance
# Use the data source to find the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  
  owners = ["099720109477"] # Canonical
}

# Create a security group for the EC2 instance
resource "aws_security_group" "app_sg" {
  # Only create if create_sg is true
  count       = var.create_sg ? 1 : 0
  
  name        = "todo-app-sg"
  description = "Security group for Todo App"
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = {
    Name = "todo-app-sg"
  }
}

# Add a local to replace the data source
locals {
  sg_id = var.create_sg ? (length(aws_security_group.app_sg) > 0 ? aws_security_group.app_sg[0].id : "") : var.existing_sg_id
}

# Add the instance specific configuration
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [local.sg_id]
  
  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }
  
  tags = {
    Name = "todo-app-server"
  }
  
  # Store variables that will be needed by Ansible
  user_data = <<-EOT
#!/bin/bash
mkdir -p /app_config
echo "${var.domain_name}" > /app_config/domain_name
echo "${var.app_repo}" > /app_config/app_repo
echo "${var.email}" > /app_config/email
EOT
}

# ALWAYS generate a new SSH key
resource "tls_private_key" "ssh" {
  # Remove count - always create
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ALWAYS create a new key pair with timestamp to ensure uniqueness
resource "aws_key_pair" "generated" {
  # Remove count - always create
  key_name   = "todoapp-key-${formatdate("YYMMDDhhmmss", timestamp())}"
  public_key = tls_private_key.ssh.public_key_openssh
}

# ALWAYS create keys directory
resource "null_resource" "create_keys_dir" {
  # Remove count - always create
  provisioner "local-exec" {
    command = <<-EOT
      echo "[$(date)] 🔑 Creating keys directory..."
      mkdir -p ${path.module}/keys 
      echo '.pem' > ${path.module}/keys/.gitignore
      echo "[$(date)] ✅ Keys directory created successfully at ${path.module}/keys"
    EOT
  }
}

# ALWAYS save private key locally
resource "local_sensitive_file" "private_key" {
  # Remove count - always create
  depends_on      = [null_resource.create_keys_dir]
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/keys/todoapp-key.pem"
  file_permission = "0600"

  provisioner "local-exec" {
    command = "echo \"[$(date)] 💾 SSH private key saved to ${path.module}/keys/todoapp-key.pem\""
  }
}

# # Update your local variable to use the new key directly
# locals {
#   key_name = aws_key_pair.generated.key_name
# }

# data "aws_security_group" "existing_sg" {
#   name = "todo-app-sg"
  
#   # This prevents failure if the security group doesn't exist
#   filter {
#     name   = "group-name"
#     values = ["todo-app-sg"]
#   }
# }

# Add a local to replace the data source
locals {
  key_name = aws_key_pair.generated.key_name
  # Add this line
  existing_sg_id = ""
}

# Update the EC2 module to use the local variable
module "ec2" {
  source = "./modules/ec2"
  
  instance_type   = var.instance_type
  key_name        = local.key_name
  domain_name     = var.domain_name
  app_repo        = var.app_repo
  email           = var.email
  create_sg       = true  # Always create SG during apply
  existing_sg_id  = local.existing_sg_id  # Use empty string
}

# Track that the EC2 instance was created
resource "null_resource" "ec2_created" {
  depends_on = [module.ec2]
  
  provisioner "local-exec" {
    command = "echo \"[$(date)] 🖥️ EC2 instance created with IP: ${module.ec2.public_ip}\""
  }
}

# Create Ansible inventory with better feedback
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tmpl", {
    public_ip    = module.ec2.public_ip
    key_name     = local.key_name
    ssh_key_path = abspath("${path.module}/keys/todoapp-key.pem")
  })
  filename = "${path.module}/../ansible/inventory.ini"
  depends_on = [local_sensitive_file.private_key] # Make sure key exists first
  
  provisioner "local-exec" {
    command = "echo \"[$(date)] 📄 Created Ansible inventory at ${path.module}/../ansible/inventory.ini\""
  }
}

# Enhanced wait_for_SSH with better output
resource "null_resource" "wait_for_ssh" {
  depends_on = [module.ec2, local_file.ansible_inventory]

  provisioner "local-exec" {
    command = <<-EOT
      echo "[$(date)] 🔄 Waiting for SSH to become available on ${module.ec2.public_ip}..."
      count=0
      max_retries=30
      until nc -z ${module.ec2.public_ip} 22 2>/dev/null || [ $count -eq $max_retries ]; do
        count=$((count+1))
        echo "[$(date)] ⏳ Attempt $count/$max_retries: Waiting for SSH on ${module.ec2.public_ip}..."
        sleep 10
      done
      
      if [ $count -eq $max_retries ]; then
        echo "[$(date)] ❌ ERROR: Timed out waiting for SSH connection."
        exit 1
      else
        echo "[$(date)] ✅ SSH is now available on ${module.ec2.public_ip}"
      fi
    EOT
  }
}

# Enhanced run_ansible resource with better output
resource "null_resource" "run_ansible" {
  depends_on = [local_file.ansible_inventory, null_resource.wait_for_ssh]

  provisioner "local-exec" {
    working_dir = "${path.module}/.."
    command     = <<-EOT
      export ANSIBLE_HOST_KEY_CHECKING=False
      echo "[$(date)] 🚀 Starting Ansible deployment..."
      sleep 20
      ansible-playbook -vv -i ansible/inventory.ini ansible/deploy.yml || {
        echo "[$(date)] ❌ ERROR: Ansible deployment failed!"
        exit 1
      }
      echo "[$(date)] ✅ Ansible deployment completed successfully"
    EOT
  }
}

# # Debug paths resource with better formatting
# resource "null_resource" "run_ansible" {
#   depends_on = [local_file.ansible_inventory, null_resource.wait_for_ssh]

#   provisioner "local-exec" {
#     working_dir = "${path.module}/.."
#     command     = <<-EOT
#       echo "[$(date)] 🚀 Starting Ansible deployment..."
      
#       # Disable host key checking
#       export ANSIBLE_HOST_KEY_CHECKING=False
      
#       ansible-playbook -vv -i ansible/inventory.ini ansible/deploy.yml || {
#         echo "[$(date)] ❌ ERROR: Ansible deployment failed!"
#         exit 1
#       }
#       echo "[$(date)] ✅ Ansible deployment completed successfully"
#     EOT
#   }
# }

# Comprehensive deployment summary
resource "null_resource" "deployment_summary" {
  depends_on = [local_file.ansible_inventory, null_resource.wait_for_ssh]

  provisioner "local-exec" {
    working_dir = "${path.module}/.."
    command = <<-EOT
      echo ""
      echo "========================================================="
      echo "🎉 DEPLOYMENT COMPLETE - $(date)"
      echo "========================================================="
      echo ""
      echo "✅ INFRASTRUCTURE DEPLOYED:"
      echo "   - EC2 Instance: ${module.ec2.public_ip}"
      echo "   - SSH Key Pair: ${local.key_name} (newly created)"
      echo "   - Security Group: created new"
      echo ""
      echo "✅ CONFIGURATION COMPLETED:"
      echo "   - SSH access configured"
      echo "   - Ansible inventory created"
      echo "   - Application deployed via Ansible"
      echo ""
      echo "✅ APPLICATION ACCESS:"
      echo "   - Application URL: https://${var.domain_name != "" ? var.domain_name : module.ec2.public_ip}"
      echo "   - HTTP port: 80"
      echo "   - HTTPS port: 443"
      echo ""
      echo "✅ SSH ACCESS:"
      echo "   ssh -i ${path.module}/keys/todoapp-key.pem ubuntu@${module.ec2.public_ip}"
      echo ""
      echo "✅ DEPLOYMENT METADATA:"
      echo "   - Instance Type: ${var.instance_type}"
      echo "   - Domain Name: ${var.domain_name != "" ? var.domain_name : "Not configured"}"
      echo "   - Repository: ${var.app_repo}"
      echo "   - Contact Email: ${var.email}"
      echo ""
      echo "✅ NEXT STEPS:"
      echo "   - Verify application at https://${var.domain_name != "" ? var.domain_name : module.ec2.public_ip}"
      echo "   - Set up monitoring (optional)"
      echo "   - Configure backup (optional)"
      echo "========================================================="
      echo "Todo App Deployment Succeeded!"
      echo "========================================================="
    EOT
  }
}

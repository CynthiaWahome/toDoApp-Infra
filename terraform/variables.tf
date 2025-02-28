variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

# Change this variable to have a default value
variable "key_name" {
  description = "SSH key name"
  type        = string
  default     = null  # This makes it optional since we generate the key
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "app_repo" {
  description = "Git repository URL for the application"
  type        = string
}

variable "email" {
  description = "Email used for Let's Encrypt"
  type        = string
}

# Add these two variables at the end of the file
variable "create_sg" {
  description = "Whether to create a new security group"
  type        = bool
  default     = true
}

variable "existing_sg_id" {
  description = "ID of an existing security group to use"
  type        = string
  default     = ""
}

# Add branch_name variable
variable "branch_name" {
  description = "Git branch to deploy"
  type        = string
  default     = "main"
}

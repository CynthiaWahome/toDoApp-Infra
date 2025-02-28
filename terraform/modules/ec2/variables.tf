variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name" {
  description = "SSH key name"
  type        = string
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
  default     = "fix/docker-build-compatibility" # Change based on stable branch
}


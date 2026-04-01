variable "profile" {
  type        = string
  description = "AWS CLI profile"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "project_name" {
  type        = string
  default     = "cloud-homelab"
  description = "Project name for resource naming"
}

variable "public_key_path" {
  type        = string
  default     = ".ssh/cloud-homelab-key.pem.pub"
  description = "Path to the public key file"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC CIDR block"
}

variable "public_subnet_cidr" {
  type        = string
  default     = "10.0.1.0/24"
  description = "Public subnet CIDR block"
}

variable "private_subnet_1_cidr" {
  type        = string
  default     = "10.0.2.0/24"
  description = "Private subnet 1 CIDR block"
}

variable "private_subnet_2_cidr" {
  type        = string
  default     = "10.0.3.0/24"
  description = "Private subnet 2 CIDR block"
}

variable "instance_types" {
  type = object({
    jump_box = string
    nat      = string
    main_vm  = string
    web_app  = string
  })
  default = {
    jump_box = "t3.micro"
    nat      = "t3.micro"
    main_vm  = "t3.micro"
    web_app  = "t3.micro"
  }
  description = "EC2 instance types for each instance"
}

variable "log_retention_days" {
  type        = number
  default     = 30
  description = "CloudWatch log retention in days"
}

variable "db_instance_class" {
  type        = string
  default     = "db.t3.micro"
  description = "Instance class of RDS"
}

variable "db_name" {
  type        = string
  description = "Name of the RDS database"
}

variable "db_username" {
  type        = string
  sensitive   = true
  description = "Master username for RDS database"
}

variable "github_repo_url" {
  type        = string
  description = "The URL of the GitHub repository containing the application code"
  default     = "https://github.com/SteliosSpanos/cloud-homelab.git"
}

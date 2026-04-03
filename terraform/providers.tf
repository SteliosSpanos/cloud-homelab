terraform {
  required_version = ">= 1.5, < 2.0"

  backend "s3" {
    bucket         = "cloud-homelab-terraform-state-487322974754"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "cloud-homelab-terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  profile = var.profile
  region  = var.region

  default_tags {
    tags = {
      Project = var.project_name
    }
  }
}

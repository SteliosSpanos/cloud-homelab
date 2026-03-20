/*
  The set-up for 1 VPC, 2 subnets (1 public, 2 private),
  2 route tables (1 public, 1 private) and 1 IGW
*/

// VPC

resource "aws_vpc" "homelab_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

// Subnets

resource "aws_subnet" "homelab_public_subnet" {
  vpc_id                  = aws_vpc.homelab_vpc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_subnet" "homelab_private_subnet_1" {
  vpc_id            = aws_vpc.homelab_vpc.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-private-subnet-1"
  }
}

resource "aws_subnet" "homelab_private_subnet_2" {
  vpc_id            = aws_vpc.homelab_vpc.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-private-subnet-2"
  }
}

// IGW

resource "aws_internet_gateway" "homelab_igw" {
  vpc_id = aws_vpc.homelab_vpc.id

  tags = {
    Name = "${project_name}-igw"
  }
}

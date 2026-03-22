/*
    Security groups for the 3 EC2 instances
*/

// NAT Instance

resource "aws_security_group" "nat_instance" {
  name        = "${var.project_name}-nat-instance-sg"
  description = "Security group for NAT instance"
  vpc_id      = aws_vpc.homelab_vpc.id

  ingress {
    description = "HTTP from private subnets"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [
      aws_subnet.homelab_private_subnet_1.cidr_block,
      aws_subnet.homelab_private_subnet_2.cidr_block
    ]
  }

  ingress {
    description = "HTTPS from private subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [
      aws_subnet.homelab_private_subnet_1.cidr_block,
      aws_subnet.homelab_private_subnet_2.cidr_block
    ]
  }

  ingress {
    description     = "SSH from jump box"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.jump_box.id]
  }

  ingress {
    description     = "ICMP (ping) from jump box"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.jump_box.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-nat-instance-sg"
  }
}

// Jump Box

resource "aws_security_group" "jump_box" {
  name        = "${var.project_name}-jump-box-sg"
  description = "Security group for jump box instance"
  vpc_id      = aws_vpc.homelab_vpc.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${data.external.my_ip.result.ip}/32"]
  }

  ingress {
    description = "ICMP (ping) from my IP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["${data.external.my_ip.result.ip}/32"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-jump-box-sg"
  }
}

// Main VM

resource "aws_security_group" "main_vm" {
  name        = "${var.project_name}-main-vm-sg"
  description = "Security group for main VM"
  vpc_id      = aws_vpc.homelab_vpc.id

  ingress {
    description     = "SSH from jump box"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.jump_box.id]
  }

  ingress {
    description     = "ICMP (ping) from jump box"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.jump_box.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-main-vm-sg"
  }
}

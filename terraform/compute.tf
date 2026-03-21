/*
    The 3 EC2 instances (Jump Box, NAT, Main) and
    the key pair for SSH
*/

resource "aws_key_pair" "homelab_key" {
  key_name   = "${var.project_name}-key"
  public_key = file("${path.module}/.ssh/homelab-key.pub")

  tags = {
    Name = "${var.project_name}-key"
  }
}

// NAT Instance

resource "aws_instance" "nat_instance" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_types.nat
  subnet_id              = aws_subnet.homelab_public_subnet.id
  vpc_security_group_ids = [aws_security_group.nat_instance.id]
  iam_instance_profile   = aws_iam_instance_profile.nat_instance.name
  key_name               = aws_key_pair.homelab_key.key_name

  source_dest_check = false

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted  = true
    kms_key_id = aws_kms_key.homelab.arn
  }
}

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

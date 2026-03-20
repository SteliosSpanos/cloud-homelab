/*
    IAM roles and policies for the EC2 instances
*/

// Jump Box

resource "aws_iam_role" "jump_box" {
  name               = "${var.project_name}-jump-box-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "jump_box_ssm" {
  role       = aws_iam_role.jump_box.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "jump_box" {
  name = "${var.project_name}-jump-box-profile"
  role = aws_iam_role.jump_box.name
}

// NAT Instance

resource "aws_iam_role" "nat_instance" {
  name               = "${var.project_name}-nat-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "nat_instance_ssm" {
  role       = aws_iam_role.nat_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "nat_instance" {
  name = "${var.project_name}-nat-instance-profile"
  role = aws_iam_role.nat_instance.name
}

// Main VM

resource "aws_iam_role" "main_vm" {
  name               = "${var.project_name}-main-vm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "main_vm_ssm" {
  role       = aws_iam_role.main_vm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "main_vm" {
  name = "${var.project_name}-main-vm-profile"
  role = aws_iam_role.main_vm.name
}

/*
    IAM roles and policies for the EC2 instances
*/

// KMS reusable policy

resource "aws_iam_policy" "kms_usage" {
  name        = "${var.project_name}-kms-usage"
  description = "Allows EC2 instances to use the homelab KMS key"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = [aws_kms_key.homelab.arn]
      },
      {
        Effect   = "Allow"
        Action   = "kms:CreateGrant"
        Resource = [aws_kms_key.homelab.arn]
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = true
          }
        }
      }
    ]
  })
}

// Jump Box

resource "aws_iam_role" "jump_box" {
  name               = "${var.project_name}-jump-box-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "jump_box_ssm" {
  role       = aws_iam_role.jump_box.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "jump_box_kms" {
  role       = aws_iam_role.jump_box.name
  policy_arn = aws_iam_policy.kms_usage.arn
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

resource "aws_iam_role_policy_attachment" "nat_instance_kms" {
  role       = aws_iam_role.nat_instance.name
  policy_arn = aws_iam_policy.kms_usage.arn
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

resource "aws_iam_role_policy_attachment" "main_vm_kms" {
  role       = aws_iam_role.main_vm.name
  policy_arn = aws_iam_policy.kms_usage.arn
}

resource "aws_iam_instance_profile" "main_vm" {
  name = "${var.project_name}-main-vm-profile"
  role = aws_iam_role.main_vm.name
}

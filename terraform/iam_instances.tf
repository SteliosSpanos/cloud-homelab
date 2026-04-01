/*
    IAM roles and policies for the EC2 instances
*/

// CloudWatch logging policy for instances

resource "aws_iam_policy" "cloudwatch" {
  for_each    = local.instance_log_groups
  name        = "${var.project_name}-${replace(each.key, "_", "-")}-cloudwatch-policy"
  description = "Allow ${replace(each.key, "_", "-")} to write to its own CloudWatch log group"

  policy = data.aws_iam_policy_document.cloudwatch_logging[each.key].json
}

// KMS reusable policy

resource "aws_iam_policy" "kms_usage" {
  name        = "${var.project_name}-kms-usage"
  description = "Allows EC2 instances to use the homelab KMS key"

  policy = data.aws_iam_policy_document.kms_usage.json
}

// Main VM S3 Policy

resource "aws_iam_policy" "s3_access" {
  name        = "${var.project_name}-s3-access-policy"
  description = "Allow main VM to access homelab S3 bucket"

  policy = data.aws_iam_policy_document.s3_access.json
}

// Jump Box

resource "aws_iam_role" "jump_box" {
  name               = "${var.project_name}-jump-box-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "jump_box_kms" {
  role       = aws_iam_role.jump_box.name
  policy_arn = aws_iam_policy.kms_usage.arn
}

resource "aws_iam_role_policy_attachment" "jump_box_cloudwatch" {
  role       = aws_iam_role.jump_box.name
  policy_arn = aws_iam_policy.cloudwatch["jump_box"].arn
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

resource "aws_iam_role_policy_attachment" "nat_instance_kms" {
  role       = aws_iam_role.nat_instance.name
  policy_arn = aws_iam_policy.kms_usage.arn
}

resource "aws_iam_role_policy_attachment" "nat_instance_cloudwatch" {
  role       = aws_iam_role.nat_instance.name
  policy_arn = aws_iam_policy.cloudwatch["nat_instance"].arn
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

resource "aws_iam_role_policy_attachment" "main_vm_kms" {
  role       = aws_iam_role.main_vm.name
  policy_arn = aws_iam_policy.kms_usage.arn
}

resource "aws_iam_role_policy_attachment" "main_vm_cloudwatch" {
  role       = aws_iam_role.main_vm.name
  policy_arn = aws_iam_policy.cloudwatch["main_vm"].arn
}

resource "aws_iam_role_policy_attachment" "main_vm_s3" {
  role       = aws_iam_role.main_vm.name
  policy_arn = aws_iam_policy.s3_access.arn
}

resource "aws_iam_instance_profile" "main_vm" {
  name = "${var.project_name}-main-vm-profile"
  role = aws_iam_role.main_vm.name
}

// Web App

resource "aws_iam_role" "web_app" {
  name               = "${var.project_name}-web-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "web_app_kms" {
  role       = aws_iam_role.web_app.name
  policy_arn = aws_iam_policy.kms_usage.arn
}

resource "aws_iam_role_policy_attachment" "web_app_cloudwatch" {
  role       = aws_iam_role.web_app.name
  policy_arn = aws_iam_policy.cloudwatch["web_app"].arn
}

resource "aws_iam_instance_profile" "web_app" {
  name = "${var.project_name}-web-app-profile"
  role = aws_iam_role.web_app.name
}

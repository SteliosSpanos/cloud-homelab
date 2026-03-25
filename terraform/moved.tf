moved {
  from = aws_iam_policy.jump_box_cloudwatch
  to   = aws_iam_policy.cloudwatch["jump_box"]
}

moved {
  from = aws_iam_policy.nat_instance_cloudwatch
  to   = aws_iam_policy.cloudwatch["nat_instance"]
}

moved {
  from = aws_iam_policy.main_vm_cloudwatch
  to   = aws_iam_policy.cloudwatch["main_vm"]
}

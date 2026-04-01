/*
    One encryption key for the homelab (with KMS)
*/

resource "aws_kms_key" "homelab" {
  description             = "${var.project_name}-encryption-key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = data.aws_iam_policy_document.kms_key_policy.json

  tags = {
    Name = "${var.project_name}-kms-key"
  }
}

resource "aws_kms_alias" "homelab" {
  name          = "alias/${var.project_name}"
  target_key_id = aws_kms_key.homelab.key_id
}

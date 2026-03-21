/*
    One encryption key for the homelab (with KMS)
*/

resource "aws_kms_key" "homelab" {
  description             = "${var.project_name}-encryption-key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KeyAdministrator"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*" // It's already KMS key scoped
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.region}.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey",
          "kms:ReEncryptTo"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/${var.project_name}/*"
          }
        }
      },
      {
        Sid    = "AllowRDSKeyUsage"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:ReEncryptFrom",
          "kms:ReEncryptTo"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "rds.${var.region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "AllowEC2Encryption"
        Effect = "Allow"
        Principal = {
          AWS = [
            aws_iam_role.jump_box.arn,
            aws_iam_role.nat_instance.arn,
            aws_iam_role.main_vm.arn
          ]
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowAttachmentOfPersistentVolumes"
        Effect = "Allow"
        Principal = {
          AWS = [
            aws_iam_role.jump_box.arn,
            aws_iam_role.nat_instance.arn,
            aws_iam_role.main_vm.arn
          ]
        }
        Action = [
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = true // Only when a resource (like EBS) is the one asking
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-kms-key"
  }
}

resource "aws_kms_alias" "homelab" {
  name          = "alias/${var.project_name}"
  target_key_id = aws_kms_key.homelab.key_id
}

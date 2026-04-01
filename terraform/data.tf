locals {
  instance_log_groups = {
    jump_box     = aws_cloudwatch_log_group.jump_box.arn
    nat_instance = aws_cloudwatch_log_group.nat_instance.arn
    main_vm      = aws_cloudwatch_log_group.main_vm.arn
    web_app      = aws_cloudwatch_log_group.web_app.arn
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "external" "my_ip" {
  program = ["bash", "${path.module}/scripts/my_ip_json.sh"]
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

// EC2 Assume Role Policy

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

// CloudWatch Logging Policy for Instances

data "aws_iam_policy_document" "cloudwatch_logging" {
  for_each = local.instance_log_groups
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = [
      each.value,
      "${each.value}:*"
    ]
  }
}

// KMS Key Usage Policy

data "aws_iam_policy_document" "kms_usage" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.homelab.arn]
  }

  statement {
    effect  = "Allow"
    actions = ["kms:CreateGrant"]
    resources = [
      aws_kms_key.homelab.arn
    ]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

// S3 Access Policy for Instances

data "aws_iam_policy_document" "s3_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:DeleteObject"
    ]
    resources = [
      aws_s3_bucket.homelab.arn,
      "${aws_s3_bucket.homelab.arn}/*"
    ]
  }
}

// VPC Flow Log Assume Role Policy

data "aws_iam_policy_document" "vpc_flow_log_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:vpc/${aws_vpc.homelab_vpc.id}"]
    }
    actions = ["sts:AssumeRole"]
  }
}

// VPC Flow Log Policy

data "aws_iam_policy_document" "vpc_flow_log" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}

// S3 Endpoint Policy (Gateway)

data "aws_iam_policy_document" "s3_endpoint_policy" {
  statement {
    sid    = "AllowHomelabBucket"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.main_vm.arn]
    }
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:DeleteObject"
    ]
    resources = [
      aws_s3_bucket.homelab.arn,
      "${aws_s3_bucket.homelab.arn}/*"
    ]
  }

  statement {
    sid    = "AllowAWSServiceBuckets"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.main_vm.arn]
    }
    actions = ["s3:GetObject"]
    resources = [
      "arn:aws:s3:::aws-ssm-${var.region}/*",
      "arn:aws:s3:::amazon-ssm-${var.region}/*",
      "arn:aws:s3:::amazon-ssm-packages-${var.region}/*",
      "arn:aws:s3:::${var.region}-birdwatcher-prod/*",
      "arn:aws:s3:::aws-ssm-document-attachments-${var.region}/*",
      "arn:aws:s3:::aws-ssm-distributor-file-${var.region}/*",
      "arn:aws:s3:::patch-baseline-snapshot-${var.region}/*",
      "arn:aws:s3:::amazoncloudwatch-agent-${var.region}/*"
    ]
  }
}

// Web App Secrets Manager Policy

data "aws_iam_policy_document" "secrets_manager_access" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [aws_db_instance.postgres.master_user_secret[0].secret_arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt"
    ]
    resources = [
      aws_kms_key.homelab.arn
    ]
  }
}

// S3 Bucket Resource-Based Policy

data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    sid    = "DenyNonSSLTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.homelab.arn,
      "${aws_s3_bucket.homelab.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "AllowOnlyMainVMRole"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.homelab.arn,
      "${aws_s3_bucket.homelab.arn}/*"
    ]
    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalArn"
      values = [
        aws_iam_role.main_vm.arn,
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }
  }
}

// KMS Resource-Based Policy

data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid    = "KeyAdministrator"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
      "kms:ReEncryptTo"
    ]
    resources = ["*"]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/${var.project_name}*"]
    }
  }

  statement {
    sid    = "AllowRDSKeyUsage"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions = [
      "kms:CreateGrant",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["rds.${var.region}.amazonaws.com"]
    }
  }

  statement {
    sid    = "AllowEC2Encryption"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.jump_box.arn,
        aws_iam_role.nat_instance.arn,
        aws_iam_role.main_vm.arn,
        aws_iam_role.web_app.arn
      ]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowAttachmentOfPersistentVolumes"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.jump_box.arn,
        aws_iam_role.nat_instance.arn,
        aws_iam_role.main_vm.arn,
        aws_iam_role.web_app.arn
      ]
    }
    actions   = ["kms:CreateGrant"]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

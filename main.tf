data "aws_caller_identity" "current" {}

locals {
  current_account_id = data.aws_caller_identity.current.account_id
}

####AWSConfig#####
resource "aws_config_config_rule" "r" {
  name = "${var.name_prefix}-config-rule"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_VERSIONING_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.recorder]
}

resource "aws_config_configuration_recorder_status" "recorde_status" {
  name       = aws_config_configuration_recorder.recorder.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.delivery]
}
resource "aws_s3_bucket" "config" {
  bucket = "${local.current_account_id}-awsconfig-logs"
}

resource "aws_config_delivery_channel" "delivery" {
  depends_on = [aws_config_configuration_recorder.recorder]
  name           = "${var.name_prefix}-awsconfig-delivery"
  s3_bucket_name = aws_s3_bucket.config.bucket
}
resource "aws_config_configuration_recorder" "recorder" {
  name     = "${var.name_prefix}-config-recorder"
  role_arn = aws_iam_role.r.arn
  recording_group {
    all_supported                 = "true"
    include_global_resource_types = "true"
  }
}
resource "aws_iam_role" "r" {
  name = "${var.name_prefix}-config-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "config.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "policy-attach" {
  role       = aws_iam_role.r.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

resource "aws_iam_role_policy" "p" {
  name = "awsconfig-delivery"
  role = aws_iam_role.r.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.config.arn}",
        "${aws_s3_bucket.config.arn}/*"
      ]
    }
  ]
}
POLICY
}
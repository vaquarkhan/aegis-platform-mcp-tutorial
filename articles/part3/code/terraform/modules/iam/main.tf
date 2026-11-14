# IAM: the role the instance runs as. Systems Manager core plus the least S3 it needs:
# read the source bundle under the prefix, write evidence under prefix/evidence/.

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "s3_scoped" {
  statement {
    sid       = "ReadBundle"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${var.s3_prefix}/*"]
  }
  statement {
    sid       = "WriteEvidence"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.bucket_name}/${var.s3_prefix}/evidence/*"]
  }
  statement {
    sid       = "ListPrefix"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.bucket_name}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.s3_prefix}/*"]
    }
  }
}

resource "aws_iam_role_policy" "s3_scoped" {
  name   = "${var.role_name}-s3"
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.s3_scoped.json
}

resource "aws_iam_instance_profile" "instance" {
  name = var.role_name
  role = aws_iam_role.instance.name
}

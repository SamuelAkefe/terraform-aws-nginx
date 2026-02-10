resource "aws_s3_bucket" "uploads" {
  # We use a prefix because S3 bucket names must be GLOBALLY unique.
  # Terraform will add a random set of characters to the end.
  bucket_prefix = "${var.project_name}-uploads-"

  # For the tutorial, this allows Terraform to delete the bucket even if it has files.
  # In production, set this to false to prevent accidental data loss.
  force_destroy = true

  tags = {
    Name = "${var.project_name}-uploads"
  }
}

# Block public access (Security Best Practice)
# We will access files via the App (boto3) or CloudFront, not direct public URLs for now.
resource "aws_s3_bucket_public_access_block" "uploads_access" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM ROLE (The Permission Slip)
# Create a role that EC2 can assume
resource "aws_iam_role" "ec2_s3_role" {
  name = "${var.project_name}-ec2-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Attach a policy to the role: "You can only touch THIS specific bucket"
resource "aws_iam_role_policy" "s3_access_policy" {
  name = "${var.project_name}-s3-access"
  role = aws_iam_role.ec2_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.uploads.arn,       # Access to the bucket itself
          "${aws_s3_bucket.uploads.arn}/*" # Access to all files inside
        ]
      }
    ]
  })
}

# INSTANCE PROFILE (THE CONNECTOR)
# This allows us to attach the Role to the EC2 Instance
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2_profile"
  role = aws_iam_role.ec2_s3_role.name
}
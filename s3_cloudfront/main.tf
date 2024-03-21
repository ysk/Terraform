terraform {
  required_version = ">= 0.13"
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Worker = "YusukeIkeda"
      Date   = "2024/03/21"
    }
  }
}

############################################################
#### CloudFront
resource "aws_cloudfront_distribution" "this" {
  enabled = true
  origin {
    origin_id   = aws_s3_bucket.this.id
    domain_name = aws_s3_bucket.this.bucket_regional_domain_name
    //OAI(Origin Access Identity)の設定
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.this.cloudfront_access_identity_path
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  default_cache_behavior {
    target_origin_id       = aws_s3_bucket.this.id
    viewer_protocol_policy = "redirect-to-https"
    cached_methods         = ["GET", "HEAD"]
    allowed_methods        = ["GET", "HEAD"]
    forwarded_values {
      query_string = false
      headers      = []
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "${var.prefix}-${var.system_Name}-cf"
  }

}

//OAIの作成
resource "aws_cloudfront_origin_access_identity" "this" {}



############################################################
#### S3 Bucket

resource "aws_s3_bucket" "this" {
  bucket = "tf-s3cloudfront-static"
  tags = {
    Name = "${var.prefix}-${var.system_Name}-s3"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.s3_main_policy.json
}

data "aws_iam_policy_document" "s3_main_policy" {
  //OAIからのアクセスのみ許可
  statement {
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.this.iam_arn]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }
}


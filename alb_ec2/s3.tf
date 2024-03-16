resource "aws_s3_bucket" "private" {
  bucket = "tf-s3bucket-example"
  versioning {
    enabled = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}


resource "aws_s3_bucket" "alb_log" {
  bucket = "tf-alb-log-s3bucket-example"
  lifecycle_rule {
    enabled = true
    expiration {
      days = "180"
    }
  }
}

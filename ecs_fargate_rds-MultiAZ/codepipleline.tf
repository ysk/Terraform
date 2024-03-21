############################################################
#### ECR

resource "aws_ecr_repository" "example" {
  name = "example"
}

resource "aws_ecr_lifecycle_policy" "example" {
  repository = aws_ecr_repository.example.name
  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire images older than 14 days",
            "selection": {
                "tagStatus"    : "tagged",
                "tagPrefixList : ["release"]
                "countType"    : "imageCountMoreThan",
                "countNumber"  : 30
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}


############################################################
#### CodeBuild

data "aws_iam_policy_document" "codebuild"{
  statement {
    effect="Allow"
    resources=["*"]
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
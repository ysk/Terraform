# ############################################################
#### ECR
resource "aws_ecr_repository" "this" {
  name = "${var.prefix}-${var.system_Name}-repo"
  tags = {
    Name = "${var.prefix}-${var.system_Name}-repo"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy     = <<EOF
  {
    "rules": [
      {
        "rulePriority": 1,
        "description": "Keep last 30 release tagged images",
        "selection": {
          "tagStatus": "tagged",
          "tagPrefixList": ["release"],
          "countType": "imageCountMoreThan",
          "countNumber": 30
        },
        "action": {
          "type": "expire"
        }
      }
    ]
  }
EOF
}

# ############################################################
# #### IAM CodeBuild

data "aws_iam_policy_document" "codebuild" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
  }
}

module "codebuild_role" {
  source     = "./iam_role"
  name       = "codebuild"
  identifier = "codebuild.amazonaws.com"
  policy     = data.aws_iam_policy_document.codebuild.json
}

resource "aws_codebuild_project" "this" {
  name         = "${var.prefix}-${var.system_Name}-codebuild"
  service_role = module.codebuild_role.iam_role_arn
  source {
    type = "CODEPIPELINE"
  }
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    type            = "LINUX_CONTAINER"
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:2.0"
    privileged_mode = true
  }
}

# ############################################################
# #### CodePipeline

data "aws_iam_policy_document" "codepipeline" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService",
      "iam:PassRole",
    ]
  }
}

module "codepipeline_role" {
  source     = "./iam_role"
  name       = "codepipeline"
  identifier = "codepipeline.amazonaws.com"
  policy     = data.aws_iam_policy_document.codepipeline.json
}

resource "aws_s3_bucket" "artifact" {
  bucket = "tf-artifact-pragmatic-terraform"
}

resource "aws_s3_bucket_lifecycle_configuration" "artifact_configuration" {
  bucket = aws_s3_bucket.artifact.id
  rule {
    id     = "artifact"
    status = "Enabled"
    expiration {
      days = 180
    }
  }
}

resource "aws_codepipeline" "this" {
  name     = "${var.prefix}-${var.system_Name}-codepipeline"
  role_arn = module.codepipeline_role.iam_role_arn
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = 1
      output_artifacts = ["Source"]
      configuration = {
        Owner                = "ysk"
        Repo                 = "codepipeline_test_repository"
        Branch               = "main"
        PollForSourceChanges = false
        OAuthToken           = var.github_token
      }
    }
  }

  // CodeBuild
  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = 1
      input_artifacts  = ["Source"]
      output_artifacts = ["Build"]
      configuration = {
        ProjectName = aws_codebuild_project.this.id
      }
    }
  }

  // CodeDeploy
  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = 1
      input_artifacts = ["Build"]
      configuration = {
        ClusterName = aws_ecs_cluster.this.name
        ServiceName = aws_ecs_service.service.name
        FileName    = "imagedefinitions.json"
      }
    }
  }

  artifact_store {
    location = aws_s3_bucket.artifact.id
    type     = "S3"
  }
}


# resource "aws_codepipeline_webhook" "main" {
#   name            = "webhook"
#   target_pipeline = aws_codepipeline.this.name
#   target_action   = "Source"
#   authentication  = "GITHUB_HMAC"
#   authentication_configuration {
#     secret_token = "zM8mcASvNC)pLF-LNCqtkQ3Y" // dummy
#   }
#   filter {
#     json_path    = "$.ref"
#     match_equals = "refs/heads/{Branch}"
#   }
#   filter {
#     json_path    = "$.head_commit.modified.*"
#     match_equals = "placeholder-file"
#   }
# }


############################################################
#### GitHub

# resource "github_repository_webhook" "this" {
#   repository = "codepipeline_test_repository"

#   configuration {
#     url          = aws_codepipeline_webhook.main.url
#     content_type = "json"
#     insecure_ssl = false
#     secret       = "zM8mcASvNC)pLF-LNCqtkQ3Y" // dummy
#   }
#   events = ["push"]
# }

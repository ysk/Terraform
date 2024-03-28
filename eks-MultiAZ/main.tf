terraform {
  required_version = ">= 0.13"
}

provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = {
      Worker = "YusukeIkeda"
      Date   = "2024/03/21"
    }
  }
}

locals {
  cluster_name    = "eks-example"
  cluster_version = "1.18"
}

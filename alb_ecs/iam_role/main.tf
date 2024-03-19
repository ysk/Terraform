# iam role


variable "name" {}
variable "policy" {}
variable "identifier" {}

resource "aws_iam_role" "default" {

}

resource "aws_iam_policy_document" "assume_role" {

}

resource "aws_iam_policy" "default" {

}

resource "aws_iam_role_policy_attachment" "default" {

}


output "iam_role_arn" {
  value = aws_iam_role.default.arn

}

output "iam_role_name" {
  value = aws_iam_policy.default.name
}
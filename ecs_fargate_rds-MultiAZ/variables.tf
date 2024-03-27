############################################################
#### parameters

variable "system_Name" {
  default = "systemname"
}

variable "prefix" {
  default = "dev"
}

variable "ami_id" {
  default = "ami-0a211f4f633a3af5f"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "github_token" {
  default = ""
}

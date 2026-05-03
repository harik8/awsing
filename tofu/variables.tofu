variable "account_id" {
  description = "The AWS Account ID"
}

variable "iac_role" {
  description = "The IAM role for Platform deployment"
}

variable "s3_backend" {
  description = "The S3 bucket name for OpenTofu remote state backend"
}

variable "aws_region" {
  description = "The AWS region"
}

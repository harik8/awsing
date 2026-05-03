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

# variable "db_master_username" {
#   description = "The master username for the RDS database"
#   default     = "root"
#   sensitive   = true
# }

# variable "db_master_password" {
#   description = "The master password for the RDS database"
#   sensitive   = true
# }

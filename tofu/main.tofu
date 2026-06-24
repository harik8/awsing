terraform {
  backend "s3" {
    bucket       = var.s3_backend
    key          = "opentofu.state"
    region       = var.aws_region
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.account_id}:role/${var.iac_role}"
    session_name = "${var.iac_role}-${terraform.workspace}"
  }

  default_tags {
    tags = {
      Stage = terraform.workspace
      IaC   = true
    }
  }
}

# provider "kubernetes" {
#   host                   = local.vars.eks.create ? module.eks.cluster_endpoint : "https://localhost"
#   cluster_ca_certificate = local.vars.eks.create ? base64decode(module.eks.cluster_certificate_authority_data) : null

#   exec {
#     api_version = "client.authentication.k8s.io/v1beta1"
#     command     = "aws"
#     args        = local.vars.eks.create ? ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--role-arn", "arn:aws:iam::${var.account_id}:role/${var.iac_role}", "--region", var.aws_region] : []
#   }
# }


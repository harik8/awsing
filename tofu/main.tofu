terraform {
  backend "s3" {
    bucket       = var.s3_backend
    key          = "tofu.state"
    region       = var.aws_region
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.account_id}:role/${terraform.workspace}-github-awsing-role"
    session_name = "${terraform.workspace}-github-awsing-role"
  }

  default_tags {
    tags = {
      Stage    = terraform.workspace
      OpenTofu = true
    }
  }
}

provider "kubernetes" {
  host                   = coalesce(module.eks.cluster_endpoint, local.vars.eks.create ? null : "https://localhost")
  cluster_ca_certificate = base64decode(coalesce(module.eks.cluster_certificate_authority_data, local.vars.eks.create ? null : "bnVsbA=="))

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = local.vars.eks.create ? ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--role-arn", "arn:aws:iam::${var.account_id}:role/${var.iac_role}", "--region", var.aws_region] : []
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, length(data.aws_availability_zones.available.names))

  # Template variables to pass to YAML files
  template_vars = {
    account_id = var.account_id
    workspace  = terraform.workspace
    pac_role   = var.pac_role
  }

  ec2_vars             = yamldecode(templatefile("${path.root}/vars/ec2.yaml", local.template_vars))
  cloudfront_vars      = yamldecode(templatefile("${path.root}/vars/cloudfront.yaml", local.template_vars))
  s3_vars              = yamldecode(templatefile("${path.root}/vars/s3.yaml", local.template_vars))
  lambda_vars          = yamldecode(templatefile("${path.root}/vars/lambda.yaml", local.template_vars))
  iam_github_oidc_vars = yamldecode(templatefile("${path.root}/vars/iam_github_oidc.yaml", local.template_vars))
  eventbridge_vars     = yamldecode(file("${path.root}/vars/eventbridge.yaml"))
  rds_vars             = yamldecode(file("${path.root}/vars/rds.yaml"))
  vars                 = yamldecode(file("${path.root}/vars/vars.yaml"))
  eks_vars             = yamldecode(templatefile("${path.root}/vars/eks.yaml", local.template_vars))
}

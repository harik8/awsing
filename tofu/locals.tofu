locals {
  azs = slice(data.aws_availability_zones.available.names, 0, length(data.aws_availability_zones.available.names))

  # Template variables to pass to YAML files
  template_vars = {
    account_id = var.account_id
    workspace  = terraform.workspace
  }

  cloudfront_vars = yamldecode(templatefile("${path.root}/vars/cloudfront.yaml", local.template_vars))
  s3_vars         = yamldecode(templatefile("${path.root}/vars/s3.yaml", local.template_vars))
  vars            = yamldecode(file("${path.root}/vars/vars.yaml"))
}

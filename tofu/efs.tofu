module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = local.vars.versions.efs

  create = contains(keys(module.eks.cluster_addons), "aws-efs-csi-driver") && local.vars.efs.create

  creation_token = terraform.workspace
  name           = terraform.workspace

  mount_targets         = { for k, v in zipmap(local.azs, module.vpc.private_subnets) : k => { subnet_id = v } }
  security_group_vpc_id = module.vpc.vpc_id
  security_group_ingress_rules = {
    vpc = {
      description = "NFS ingress from VPC private subnets"
      from_port   = 2049
      to_port     = 2049
      ip_protocol = "tcp"
      cidr_ipv4   = module.vpc.vpc_cidr_block
    }
  }

  enable_backup_policy = true
}

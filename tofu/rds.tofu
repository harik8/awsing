module "aurora_postgres" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "v9.16.1"

  count = length(local.rds_vars)

  create = local.rds_vars[count.index]["create"]

  name           = "${terraform.workspace}-${local.rds_vars[count.index]["name"]}"
  engine         = local.rds_vars[count.index]["engine"]
  engine_version = local.rds_vars[count.index]["engine_version"]
  instance_class = local.rds_vars[count.index]["instance_class"]
  instances      = local.rds_vars[count.index]["instances"]

  vpc_id                 = module.vpc.vpc_id
  create_db_subnet_group = true
  subnets                = module.vpc.private_subnets
  security_group_name    = "${terraform.workspace}-${local.rds_vars[count.index]["name"]}"
  security_group_rules = {
    vpc_ingress = {
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }

  storage_encrypted           = true
  apply_immediately           = true
  skip_final_snapshot         = true
  manage_master_user_password = false
  master_username             = var.db_master_username
  master_password             = var.db_master_password

  tags = {
    Name = "${terraform.workspace}-${local.rds_vars[count.index]["name"]}"
  }
}

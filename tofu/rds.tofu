module "aurora_postgres" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "v9.16.1"

  create = local.vars.rds.psql.create

  name           = "${terraform.workspace}-ar-psql"
  engine         = "aurora-postgresql"
  engine_version = "17"
  instance_class = "db.t4g.medium"
  instances      = local.vars.rds.psql.instances

  vpc_id                 = module.vpc.vpc_id
  create_db_subnet_group = true
  subnets                = module.vpc.private_subnets
  security_group_name    = "${terraform.workspace}-ar-psql"
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
    Name = "${terraform.workspace}-ar-psql"
  }
}
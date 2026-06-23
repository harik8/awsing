module "aurora_postgres" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = local.vars.versions.rds_aurora

  create = local.vars.rds.psql.create

  name           = "${terraform.workspace}-ar-psql"
  engine         = "aurora-postgresql"
  engine_version = "17"

  instances = { for k, v in local.vars.rds.psql.instances : k => merge(v, {
    instance_class = try(v.instance_class, "db.t4g.medium")
  }) }

  vpc_id                 = module.vpc.vpc_id
  create_db_subnet_group = true
  subnets                = module.vpc.private_subnets
  security_group_name    = "${terraform.workspace}-ar-psql"
  security_group_ingress_rules = {
    vpc_ingress = {
      cidr_ipv4   = module.vpc.vpc_cidr_block
      from_port   = 5432
      to_port     = 5432
      ip_protocol = "tcp"
      description = "PostgreSQL access from VPC"
    }
  }

  storage_encrypted           = true
  apply_immediately           = true
  skip_final_snapshot         = true
  manage_master_user_password = false
  master_username             = "root"
  master_password_wo          = random_password.password.result
  master_password_wo_version  = 1

  tags = {
    Name = "${terraform.workspace}-ar-psql"
  }
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

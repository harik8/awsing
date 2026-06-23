module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = local.vars.versions.ecs

  create                                 = local.vars.ecs.create
  cluster_name                           = terraform.workspace
  cloudwatch_log_group_retention_in_days = 1
  create_task_exec_iam_role              = true
  task_exec_iam_role_name                = "${terraform.workspace}-ecs-role"

  cluster_capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy = {
    FARGATE = {
      weight = 50
    }
    FARGATE_SPOT = {
      weight = 50
    }
  }
}

module "iam_role_ecs_task_exec_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = local.vars.versions.iam

  name            = "${terraform.workspace}-ecs-task-exec-role"
  use_name_prefix = false

  trust_policy_permissions = {
    AllowECSAssumeRole = {
      actions = ["sts:AssumeRole"]
      principals = [{
        type        = "Service"
        identifiers = ["ecs.amazonaws.com", "ecs-tasks.amazonaws.com"]
      }]
    }
  }

  policies = {
    AmazonECSTaskExecutionRolePolicy = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  }
}

module "ecs_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = local.vars.versions.security_group

  create = local.vars.ecs.create

  name        = "${terraform.workspace}-ecs-sg"
  description = "Security group of ECS ${terraform.workspace}"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    vpc_ingress = {
      from_port   = 0
      to_port     = 0
      ip_protocol = "tcp"
      cidr_ipv4   = module.vpc.vpc_cidr_block
      description = "Allow Solr traffic"
    }
  }

  egress_rules = {
    all_outbound = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow all outbound traffic"
    }
  }
}

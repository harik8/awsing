# Render ECS Managed Instance Task Definitions and Services

data "template_file" "ecs_mi_capacity_provider" {
  template = file("${path.module}/tmpl/ecs/mi_capacity_provider.json")

  vars = {
    account_id         = var.account_id
    ecs_cluster        = module.ecs.cluster_id
    subnet_ids         = join("\", \"", module.vpc.private_subnets)
    security_group_ids = module.ecs_sg.security_group_id
  }
}

data "template_file" "ecs_mi_default_capacity_provider" {
  template = file("${path.module}/tmpl/ecs/mi_default_capacity_provider.json")

  vars = {
    ecs_cluster = module.ecs.cluster_id
  }
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = local.vars.ecs.version

  create                                 = local.vars.ecs.create
  cluster_name                           = terraform.workspace
  cloudwatch_log_group_retention_in_days = 1
  create_task_exec_iam_role              = true
  task_exec_iam_role_name                = "${terraform.workspace}-ecs-role"

  default_capacity_provider_use_fargate = true

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
  }
}

module "iam_role_ecs_task_exec_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = local.vars.iam.version

  create_role = true
  role_name   = "${terraform.workspace}-ecs-task-exec-role"

  trusted_role_services = [
    "ecs.amazonaws.com",
    "ecs-tasks.amazonaws.com"
  ]

  role_requires_mfa = false

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}

module "ecs_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = local.vars.security_group.version

  create = local.vars.ecs.create

  name        = "${terraform.workspace}-ecs-sg"
  description = "Security group of ECS ${terraform.workspace}"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]
  ingress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "tcp"
      description = "Allow Solr traffic"
      cidr_blocks = module.vpc.vpc_cidr_block
    }
  ]
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Allow all outbound traffic"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

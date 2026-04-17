data "aws_iam_policy_document" "ecs_solr_instance_profile" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

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

data "template_file" "ecs_service_solr" {
  template = file("${path.module}/tmpl/ecs/mi_svc_solr.json")

  vars = {
    ecs_cluster = module.ecs.cluster_id
  }
}

data "template_file" "ecs_task_solr" {
  template = file("${path.module}/tmpl/ecs/mi_task_solr.json")

  vars = {
    account_id  = var.account_id
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

# ECS Managed Instances

module "iam_role_ecs_solr_infrastructure" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = local.vars.iam.version

  create_role = true
  role_name   = "${terraform.workspace}-ecsInfrastructureRole-solr"

  trusted_role_services = [
    "ecs.amazonaws.com",
    "ecs-tasks.amazonaws.com"
  ]

  role_requires_mfa = false

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRolePolicyForVolumes",
    "arn:aws:iam::aws:policy/AmazonECSInfrastructureRolePolicyForManagedInstances",
    module.iam_policy_ecs_solr_capacity_provider.arn
  ]
}

module "iam_policy_ecs_solr_capacity_provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = local.vars.iam.version

  name_prefix = "${terraform.workspace}-ecsInfrastructureRole-solr-cp"
  path        = "/"
  description = "${terraform.workspace}-ecsInfrastructureRole-solr to create capacity provider"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ecs:CreateCapacityProvider",
        "ecs:UpdateCapacityProvider",
        "ecs:DeleteCapacityProvider",
        "ecs:DescribeCapacityProviders",
        "ecs:DescribeClusters"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:ecs:${var.aws_region}:${var.account_id}:capacity-provider/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:CreateAutoScalingGroup",
        "autoscaling:UpdateAutoScalingGroup",
        "autoscaling:DeleteAutoScalingGroup",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeLaunchConfigurations"
      ],
      "Resource": "arn:aws:autoscaling:${var.aws_region}:${var.account_id}:autoScalingGroup:*:autoScalingGroupName/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::${var.account_id}:role/${terraform.workspace}-ecs-solr-instance-role"
      ]
    }
  ]
}
EOF
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

resource "aws_iam_instance_profile" "ecs_solr_instance_profile" {
  name = "${terraform.workspace}-ecs-solr-instance-profile"
  role = aws_iam_role.ecs_solr_instance_role.name
}

resource "aws_iam_role" "ecs_solr_instance_role" {
  name               = "${terraform.workspace}-ecs-solr-instance-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ecs_solr_instance_profile.json
}

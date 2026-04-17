data "aws_iam_policy_document" "lambda_aurora_clone" {
  statement {
    actions = [
      "rds:AddTagsToResource",
      "rds:CreateDBInstance",
      "rds:RestoreDBClusterToPointInTime"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:rds:${var.aws_region}:${var.account_id}:cluster:${terraform.workspace}-*",
      "arn:aws:rds:${var.aws_region}:${var.account_id}:db:${terraform.workspace}-*",
    ]
  }
  statement {
    actions = [
      "rds:RestoreDBClusterToPointInTime"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:rds:${var.aws_region}:${var.account_id}:subgrp:${terraform.workspace}-*",
    ]
  }
  statement {
    actions = [
      "rds:DescribeDBClusters"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "lambda_aurora_clone_purge" {
  statement {
    actions = [
      "rds:DescribeDBClusters"
    ]
    effect = "Allow"
    resources = [
      "*"
    ]
  }
  statement {
    actions = [
      "rds:DeleteDBCluster",
      "rds:DeleteDBInstance"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:rds:${var.aws_region}:${var.account_id}:cluster:${terraform.workspace}-*-clone-*",
      "arn:aws:rds:${var.aws_region}:${var.account_id}:db:${terraform.workspace}-*-clone-*"
    ]
  }
}

module "aurora_clone" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "v7.21.1"

  create = true

  function_name                     = "${terraform.workspace}-aurora-clone"
  handler                           = "function.lambda_handler"
  runtime                           = "python3.13"
  publish                           = true
  policy_json                       = data.aws_iam_policy_document.lambda_aurora_clone.json
  attach_policy_json                = true
  timeout                           = 60
  source_path                       = "${path.module}/src/lambda_aurora_clone/clone"
  skip_destroy                      = false
  cloudwatch_logs_retention_in_days = 1

  environment_variables = {
    DB_INSTANCE_CLASS = "db.t4g.medium"
  }
  allowed_triggers = {
    AllowToInvoke = {
      principal    = "arn:aws:iam::${var.account_id}:role/${var.pac_role}"
      action       = "lambda:InvokeFunction"
      statement_id = "AllowToInvoke"
    }
  }
}

module "aurora_clone_purge" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "v7.21.1"

  create = true

  function_name                     = "${terraform.workspace}-aurora-clone-purge"
  handler                           = "function.lambda_handler"
  runtime                           = "python3.13"
  publish                           = true
  policy_json                       = data.aws_iam_policy_document.lambda_aurora_clone_purge.json
  attach_policy_json                = true
  timeout                           = 60
  source_path                       = "${path.module}/src/lambda_aurora_clone/purge"
  skip_destroy                      = false
  cloudwatch_logs_retention_in_days = 1

  environment_variables = {
    STAGE          = terraform.workspace,
    RETENTION_DAYS = "1"
  }

  allowed_triggers = {
    AllowEventsBridgeToInvoke = {
      principal  = "events.amazonaws.com"
      source_arn = module.aurora_clone_purge_eventbridge.eventbridge_rule_arns["${terraform.workspace}-aurora-clone-purge"]
    }
  }
}

module "aurora_clone_purge_eventbridge" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "v3.17.1"

  create      = true
  create_bus  = false
  create_role = true
  role_name   = "${terraform.workspace}-aurora-clone-purge-eventbridge"

  rules = {
    "${terraform.workspace}-aurora-clone-purge" = {
      name                = "${terraform.workspace}-aurora-clone-purge"
      description         = "Schedule to trigger the aurora clone purge lambda function"
      schedule_expression = "cron(0 9 ? * MON-FRI *)"
      enabled             = true
    }
  }

  targets = {
    "${terraform.workspace}-aurora-clone-purge" = [
      {
        name  = "${terraform.workspace}-aurora-clone-purge"
        arn   = module.aurora_clone_purge.lambda_function_arn
        id    = "aurora-clone-purge-target"
        input = "{}"
      }
    ]
  }
}


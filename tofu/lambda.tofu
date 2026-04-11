module "lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "v7.21.1"

  count = length(local.lambda_vars)

  function_name                     = "${terraform.workspace}-${local.lambda_vars[count.index]["name"]}"
  handler                           = local.lambda_vars[count.index]["handler"]
  runtime                           = local.lambda_vars[count.index]["runtime"]
  publish                           = true
  timeout                           = local.lambda_vars[count.index]["timeout"]
  source_path                       = "${path.module}/${local.lambda_vars[count.index]["source_path"]}"
  skip_destroy                      = false
  cloudwatch_logs_retention_in_days = local.lambda_vars[count.index]["cloudwatch_logs_retention_in_days"]

  attach_policy_json = true
  policy_json        = local.lambda_vars[count.index]["policy_json"]

  environment_variables = local.lambda_vars[count.index]["environment_variables"]
  allowed_triggers      = try(local.lambda_vars[count.index]["allowed_triggers"], {})
}

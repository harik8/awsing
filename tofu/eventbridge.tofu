module "eventbridge" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "v3.17.1"

  count = length(local.eventbridge_vars)

  create      = true
  create_bus  = false
  create_role = true
  role_name   = "${terraform.workspace}-${local.eventbridge_vars[count.index]["name"]}-eventbridge"

  rules = {
    "${terraform.workspace}-${local.eventbridge_vars[count.index]["name"]}" = {
      name                = "${terraform.workspace}-${local.eventbridge_vars[count.index]["name"]}"
      description         = local.eventbridge_vars[count.index]["description"]
      schedule_expression = local.eventbridge_vars[count.index]["schedule_expression"]
      enabled             = true
    }
  }

  targets = {
    "${terraform.workspace}-${local.eventbridge_vars[count.index]["name"]}" = [
      {
        name  = "${terraform.workspace}-${local.eventbridge_vars[count.index]["name"]}"
        arn   = module.lambda[index(local.lambda_vars[*]["name"], local.eventbridge_vars[count.index]["target_lambda"])].lambda_function_arn
        id    = "${local.eventbridge_vars[count.index]["name"]}-target"
        input = "{}"
      }
    ]
  }
}

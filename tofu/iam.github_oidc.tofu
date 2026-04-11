module "iam_github_oidc_provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"
  version = local.vars.iam.version
}

module "iam_github_oidc_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = local.vars.iam.version

  name     = "${terraform.workspace}-github-oidc-role"
  subjects = local.vars.iam.github_oidc.repos
}

module "iam_github_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = local.vars.iam.version

  count = length(local.iam_github_oidc_vars)

  name        = "${terraform.workspace}-github-${local.iam_github_oidc_vars[count.index]["name"]}-policy"
  description = local.iam_github_oidc_vars[count.index]["description"]
  policy      = local.iam_github_oidc_vars[count.index]["policy"]
}

module "iam_github_assumable_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = local.vars.iam.version

  count = length(local.iam_github_oidc_vars)

  role_name   = "${terraform.workspace}-github-${local.iam_github_oidc_vars[count.index]["name"]}-role"
  create_role = true

  trusted_role_arns = [module.iam_github_oidc_role.arn]
  role_requires_mfa = false

  custom_role_policy_arns = [module.iam_github_policy[count.index].arn]
}

module "iam_github_oidc_provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"
  version = local.vars.iam.version
}

module "iam_github_oidc_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = local.vars.iam.version

  name = "${terraform.workspace}-github-oidc-role"

  # This should be updated to suit your organization, repository, references/branches, etc.
  subjects = local.vars.iam.github_oidc.repos
}

module "iam_github_portfolio_website_s3_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = local.vars.iam.version

  name        = "${terraform.workspace}-github-portfolio-website-s3-policy"
  path        = "/"
  description = "IAM policy for GitHub OIDC role to access ${terraform.workspace}-portfolio-website S3 bucket"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject*"
      ],
      "Effect": "Allow",
      "Resource": [
          "arn:aws:s3:::${terraform.workspace}-portfolio-website/*"
        ]
    },
    {
      "Action": [
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
          "arn:aws:s3:::${terraform.workspace}-portfolio-website"
        ]
    }
  ]
}
EOF
}

module "iam_assumable_role_github_portfolio_website" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = local.vars.iam.version

  role_name   = "${terraform.workspace}-github-portfolio-website-role"
  create_role = true

  trusted_role_arns = [
    module.iam_github_oidc_role.arn
  ]

  role_requires_mfa = false

  custom_role_policy_arns = [
    module.iam_github_portfolio_website_s3_policy.arn
  ]
}
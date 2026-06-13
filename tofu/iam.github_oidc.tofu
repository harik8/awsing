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

module "iam_github_hp_dev_s3_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = local.vars.iam.version

  name        = "${terraform.workspace}-github-hp-dev-s3-policy"
  path        = "/"
  description = "IAM policy for GitHub OIDC role to access ${terraform.workspace}-hp-dev S3 bucket"

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
          "arn:aws:s3:::${terraform.workspace}-hp-dev/*"
        ]
    },
    {
      "Action": [
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
          "arn:aws:s3:::${terraform.workspace}-hp-dev"
        ]
    }
  ]
}
EOF
}

module "iam_assumable_role_github_hp_dev" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = local.vars.iam.version

  role_name   = "${terraform.workspace}-github-hp-dev-role"
  create_role = true

  trusted_role_arns = [
    module.iam_github_oidc_role.arn
  ]

  role_requires_mfa = false

  custom_role_policy_arns = [
    module.iam_github_hp_dev_s3_policy.arn
  ]
}

module "iam_assumable_role_github_awsing" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = local.vars.iam.version

  role_name   = "${terraform.workspace}-github-awsing-role"
  create_role = true

  trusted_role_arns = [
    module.iam_github_oidc_role.arn,
    "arn:aws:iam::${var.account_id}:role/${terraform.workspace}-github-awsing-role",
    "arn:aws:sts::${var.account_id}:assumed-role/AWSReservedSSO_AdministratorAccess_0ada0c673e6da443/hari.karthigasu"
  ]

  role_requires_mfa = false

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]
}
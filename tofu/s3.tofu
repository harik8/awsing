module "s3" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = local.vars.s3.version

  count = length(local.s3_props)

  bucket                   = "${terraform.workspace}-${local.s3_props[count.index]["name"]}"
  acl                      = try(local.s3_props[count.index]["acl"], "private")
  control_object_ownership = try(local.s3_props[count.index]["control_object_ownership"], "true")
  object_ownership         = try(local.s3_props[count.index]["object_ownership"], "BucketOwnerPreferred")

  attach_policy = can(local.s3_props[count.index]["policy"])
  policy        = try(local.s3_props[count.index]["policy"], {})

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = try(local.s3_props[count.index]["sse_kms"], false) ? module.s3_kms[count.index].key_arn : null
        sse_algorithm     = try(local.s3_props[count.index]["sse_kms"], false) ? "aws:kms" : "AES256"
      }
    }
  }

  versioning = {
    enabled = true
  }

  website = try(local.s3_props[count.index]["website"], {})
}

module "s3_kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "v3.1.1"

  count = length([for bucket in local.s3_props : bucket if can(bucket["sse_kms"])])

  aliases            = ["/s3/${terraform.workspace}-${local.s3_props[count.index]["name"]}"]
  description        = "KMS key is used to encrypt bucket objects for ${terraform.workspace}-${local.s3_props[count.index]["name"]}"
  key_administrators = ["arn:aws:iam::${var.account_id}:role/${var.pac_role}"]
  key_usage          = "ENCRYPT_DECRYPT"
}

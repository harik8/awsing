module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "v5.2.0"

  count = length(local.cloudfront_props)

  aliases = local.cloudfront_props[count.index]["aliases"]
  comment = try(local.cloudfront_props[count.index]["comment"], "${terraform.workspace}-${local.cloudfront_props[count.index]["name"]}")

  create_origin_access_control = can(local.cloudfront_props[count.index]["create_oac"])
  default_cache_behavior       = local.cloudfront_props[count.index]["default_cache_behavior"]
  default_root_object          = try(local.cloudfront_props[count.index]["default_root_object"], "index.html")
  origin                       = local.cloudfront_props[count.index]["origin"]
  ordered_cache_behavior       = try(local.cloudfront_props[count.index]["ordered_cache_behavior"], [])
  viewer_certificate           = try(local.cloudfront_props[count.index]["viewer_certificate"], {})

  logging_config = {
    bucket = try(local.cloudfront_props[count.index]["logging_config"]["bucket"], "")
    prefix = try(local.cloudfront_props[count.index]["logging_config"]["prefix"], "logs")
  }
}

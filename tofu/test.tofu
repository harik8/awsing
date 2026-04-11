# data "http" "configs" {
#   for_each = local.repos
#   url      = each.value
# }

# locals {
#   repos = {
#     hariprasad_dev  = "https://raw.githubusercontent.com/harik8/hariprasad.dev/refs/heads/D-310326/.tofu/vars.yaml"
#   }

#   raw_values      = { for k, v in data.http.configs : k => yamldecode(v.response_body) }
#   rendered_values = yamldecode(templatestring(yamlencode(local.raw_values), local.template_vars))
#   values = {
#     cloudfront = flatten([for v in values(local.rendered_values) : v.cloudfront])
#     s3         = flatten([for v in values(local.rendered_values) : v.s3])
#   }
# }

# output "values" {
#   value = local.values
# }
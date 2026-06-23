module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = local.vars.versions.vpc

  create_vpc = true

  cidr = local.vars.vpc.cidr

  azs                = local.azs
  enable_nat_gateway = local.vars.vpc.nat_gateway.enable
  single_nat_gateway = local.vars.vpc.nat_gateway.single

  private_subnets = [for k in range(0, length(local.azs)) : cidrsubnet(local.vars.vpc.cidr, 8, k + 8)]
  public_subnets  = [for k in range(0, length(local.azs)) : cidrsubnet(local.vars.vpc.cidr, 12, k + 8)]
  intra_subnets   = [for k in range(0, length(local.azs)) : cidrsubnet(local.vars.vpc.cidr, 8, k + 12)]

  enable_ipv6                                   = false
  public_subnet_assign_ipv6_address_on_creation = false

  public_subnet_ipv6_prefixes  = [0, 1, 2]
  private_subnet_ipv6_prefixes = [3, 4, 5]
  intra_subnet_ipv6_prefixes   = [6, 7, 8]

  default_security_group_name = "${terraform.workspace}-default"
  default_security_group_egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
      description = "Allow all outbound traffic"
    }
  ]

  private_subnet_tags = {
    Name = "${terraform.workspace}-private"
  }
  public_subnet_tags = {
    Name = "${terraform.workspace}-public"
  }
  intra_subnet_tags = {
    Name = "${terraform.workspace}-intra"
  }
  private_route_table_tags = {
    Name = "${terraform.workspace}-private"
  }
  public_route_table_tags = {
    Name = "${terraform.workspace}-public"
  }
  intra_route_table_tags = {
    Name = "${terraform.workspace}-intra"
  }

  tags = {
    Name = "${terraform.workspace}"
  }
}
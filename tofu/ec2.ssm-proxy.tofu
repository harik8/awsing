module "ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "v5.8.0"

  create = local.vars.ec2.ssm_proxy.create

  name          = "${terraform.workspace}-ssm-proxy"
  instance_type = "t4g.nano"
  ami           = data.aws_ami.al2023_arm64.id

  subnet_id                   = element(module.vpc.private_subnets, 0)
  create_iam_instance_profile = true


  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  root_block_device = [
    {
      encrypted   = true
      volume_type = "gp3"
      volume_size = 8
    }
  ]

  tags = {
    Name = "${terraform.workspace}-ssm-proxy"
  }
}
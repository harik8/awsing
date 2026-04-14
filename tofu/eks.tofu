module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = local.vars.eks.version

  create = local.vars.eks.create

  cluster_name                             = terraform.workspace
  cluster_version                          = local.vars.eks.cluster_version
  cluster_endpoint_public_access           = local.eks_vars.cluster.endpoint_public_access
  create_kms_key                           = local.eks_vars.cluster.create_kms_key
  enable_cluster_creator_admin_permissions = local.eks_vars.cluster.enable_cluster_creator_admin_permissions
  control_plane_subnet_ids                 = module.vpc.private_subnets
  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets

  access_entries = local.eks_vars.cluster.access_entries

  cluster_addons = {
    coredns = {
      most_recent  = local.eks_vars.cluster.addons.coredns.most_recent
      compute_type = local.eks_vars.cluster.addons.coredns.compute_type
      configuration_values = jsonencode({
        autoScaling = {
          enabled     = local.eks_vars.cluster.addons.coredns.autoscaling.enabled
          minReplicas = local.eks_vars.cluster.addons.coredns.autoscaling.min_replicas
          maxReplicas = local.eks_vars.cluster.addons.coredns.autoscaling.max_replicas
        }
      })
    }
    kube-proxy = {
      most_recent = local.eks_vars.cluster.addons["kube-proxy"].most_recent
    }
    vpc-cni = {
      most_recent = local.eks_vars.cluster.addons["vpc-cni"].most_recent
    }
    aws-efs-csi-driver = {
      most_recent              = local.eks_vars.cluster.addons["aws-efs-csi-driver"].most_recent
      service_account_role_arn = local.eks_vars.cluster.addons["aws-efs-csi-driver"].service_account_role_arn
      replicaCount             = local.eks_vars.cluster.addons["aws-efs-csi-driver"].replica_count
      tolerations              = local.eks_vars.cluster.addons["aws-efs-csi-driver"].tolerations
    }
  }
}

module "fargate_profile" {
  for_each = { for profile in local.eks_vars.fargate_profile : profile.name => profile }

  source  = "terraform-aws-modules/eks/aws//modules/fargate-profile"
  version = local.vars.eks.version
  create  = local.vars.eks.create

  name         = "${module.eks.cluster_name}-${each.value.name}"
  cluster_name = module.eks.cluster_name

  subnet_ids = module.vpc.private_subnets
  selectors  = each.value.selectors
}

resource "aws_security_group_rule" "dns_tcp" {
  count = local.vars.eks.create ? 1 : 0

  description              = "Allow pods to communicate with the CoreDNS on Fargate"
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  source_security_group_id = module.eks.node_security_group_id
  security_group_id        = module.eks.cluster_primary_security_group_id
}

resource "aws_security_group_rule" "dns_udp" {
  count = local.vars.eks.create ? 1 : 0

  description              = "Allow pods to communicate with the CoreDNS on Fargate"
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  source_security_group_id = module.eks.node_security_group_id
  security_group_id        = module.eks.cluster_primary_security_group_id
}

resource "kubernetes_storage_class_v1" "gp3" {
  count = local.eks_vars.sc.gp3 ? 1 : 0

  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = false

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }
}

resource "kubernetes_storage_class_v1" "efs" {
  count = local.eks_vars.sc.efs ? 1 : 0

  metadata {
    name = "efs"
  }

  storage_provisioner = "efs.csi.aws.com"

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = module.efs.id
    directoryPerms   = "700"
  }

  reclaim_policy      = "Delete"
  volume_binding_mode = "Immediate"
}

module "eks_managed_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = local.vars.eks.version

  create = local.vars.eks.create

  name                 = terraform.workspace
  cluster_name         = terraform.workspace
  cluster_version      = local.vars.eks.cluster_version
  cluster_service_cidr = module.eks.cluster_service_cidr

  subnet_ids = module.vpc.private_subnets

  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks.node_security_group_id]

  ami_type       = local.eks_vars.managed_node_group.ami_type
  min_size       = local.eks_vars.managed_node_group.min_size
  max_size       = local.eks_vars.managed_node_group.max_size
  desired_size   = local.eks_vars.managed_node_group.desired_size
  instance_types = local.eks_vars.managed_node_group.instance_types
  capacity_type  = local.eks_vars.managed_node_group.capacity_type

  block_device_mappings        = local.eks_vars.managed_node_group.block_device_mappings
  taints                       = local.eks_vars.managed_node_group.taints
  iam_role_additional_policies = local.eks_vars.managed_node_group.iam_role_additional_policies
}

module "irsa_efs_csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = local.eks_vars.irsa_iam_version

  create_role = local.vars.eks.create && contains(keys(module.eks.cluster_addons), "aws-efs-csi-driver")

  role_name             = "${terraform.workspace}-efs-csi"
  attach_efs_csi_policy = true

  oidc_providers = {
    efs = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }
}

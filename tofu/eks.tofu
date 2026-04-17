module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = local.vars.eks.version

  create = local.vars.eks.create

  cluster_name                             = terraform.workspace
  cluster_version                          = local.vars.eks.cluster_version
  cluster_endpoint_public_access           = true
  create_kms_key                           = true
  enable_cluster_creator_admin_permissions = true
  control_plane_subnet_ids                 = module.vpc.private_subnets
  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets

  access_entries = {
    aws_admin = {
      kubernetes_groups = []
      user_name         = "AWSAdmin"
      principal_arn     = "arn:aws:iam::${var.account_id}:role/${var.pac_role}"

      policy_associations = {
        aws_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  cluster_addons = {
    coredns = {
      most_recent  = true,
      compute_type = "fargate",
      configuration_values = jsonencode({
        autoScaling = {
          enabled     = true
          minReplicas = 2
          maxReplicas = 2
        }
      })
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-efs-csi-driver = {
      most_recent              = true
      service_account_role_arn = "arn:aws:iam::${var.account_id}:role/${terraform.workspace}-efs-csi"
      replicaCount             = 1
      "tolerations" : [
        {
          "key" : "application",
          "effect" : "NO_SCHEDULE",
          "operator" : "Equal",
          "value" : "true"
        }
      ]
    }
  }
}

module "fargate_profile" {
  for_each = { for profile in local.vars.eks.fargate_profile : profile.name => profile }

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

  count = local.vars.eks.sc.gp3 ? 1 : 0

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

  count = local.vars.eks.sc.efs ? 1 : 0

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

  ami_type = "AL2_ARM_64"

  min_size     = 1
  max_size     = 1
  desired_size = 1

  instance_types = ["t4g.small"]
  capacity_type  = "SPOT"


  block_device_mappings = {
    xvda = {
      device_name = "/dev/xvda"
      ebs = {
        volume_type = "gp3"
        encrypted   = true
      }
    }
  }

  taints = {
    dedicated = {
      key    = "application"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  }

  iam_role_additional_policies = {
    AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }
}

module "irsa_efs_csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "v5.60.0"

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
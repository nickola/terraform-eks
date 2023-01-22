module "eks" {
  source  = "terraform-aws-modules/eks/aws" # AWS EKS module (supported by community)
  version = "19.5.1"

  cluster_name    = var.eks_name
  cluster_version = var.eks_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Public API server endpoint is enabled
  cluster_endpoint_public_access = true

  # Node groups
  eks_managed_node_groups = {
    for node_group in var.eks_node_groups:
      node_group.name => {
        instance_types = [node_group.instance_type]
        desired_size   = node_group.desired_size
        min_size       = node_group.min_size
        max_size       = node_group.max_size
      }
  }
}

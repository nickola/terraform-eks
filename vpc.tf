module "vpc" {
  source  = "terraform-aws-modules/vpc/aws" # AWS VPC module (supported by community)
  version = "3.19.0"

  azs  = formatlist("${data.aws_region.current.name}%s", var.vpc_availability_zones)
  name = var.vpc_name
  cidr = var.vpc_cidr

  private_subnets      = var.vpc_private_subnets
  public_subnets       = var.vpc_public_subnets
  enable_dns_hostnames = var.vpc_enable_dns_hostnames

  # One NAT Gateway per availability zone
  # Each private subnet will route Internet traffic through the corresponding NAT gateway in the public subnet
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  # Tags for EKS load balancers
  # See: https://aws.amazon.com/premiumsupport/knowledge-center/eks-vpc-subnet-discovery/
  private_subnet_tags = {
    "kubernetes.io/cluster/${var.eks_name}" = "shared"
    "kubernetes.io/role/internal-elb"       = 1 # Use internal load balancers
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.eks_name}" = "shared"
    "kubernetes.io/role/elb"                = 1 # Use external load balancers
  }
}

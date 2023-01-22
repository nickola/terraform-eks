output "aws_region" {
  description = "AWS region"
  value       = data.aws_region.current.name
}

output "eks_name" {
  description = "EKS Name"
  value       = module.eks.cluster_name
}

output "eks_endpoint" {
  description = "EKS Endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_security_group_id" {
  description = "EKS Security Group ID"
  value       = module.eks.cluster_security_group_id
}

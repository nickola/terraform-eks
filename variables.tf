# AWS (Amazon Web Services) configuration
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# VPC (Virtual Private Cloud) configuration
variable "vpc_name" {
  description = "VPC name"
  type = string
  default = "kubernetes-vpc"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type = string
  default = "10.0.0.0/16"
}

variable "vpc_availability_zones" {
  description = "VPC availability zones"
  type = list(string)
  default = ["a", "b"]
  validation {
    condition     = length(var.vpc_availability_zones) >= 2
    error_message = "At least 2 VPC availability zones are required"
  }
}

variable "vpc_private_subnets" {
  description = "Private subnets (not less than number of 'vpc_availability_zones')"
  type = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "vpc_public_subnets" {
  description = "Public subnets (not less than number of 'vpc_availability_zones')"
  type = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "vpc_enable_dns_hostnames" {
  description = "Public IPs in 'vpc_public_subnets' will have DNS names"
  type = bool
  default = true
}

# EKS (Elastic Kubernetes Service) configuration
variable "eks_name" {
  description = "EKS name"
  type = string
  default = "kubernetes"
}

variable "eks_version" {
  description = "EKS version"
  type = string
  default = "1.24"
}

variable "eks_node_groups" {
  description = "EKS node groups"
  type = list(object({
    name          = string,
    instance_type = string,
    min_size      = number,
    max_size      = number,
    desired_size  = number
  }))
  default = [
    {
      name          = "node-group-1"
      instance_type = "t2.micro"
      min_size      = 2
      max_size      = 3
      desired_size  = 2
    },
    {
      name          = "node-group-2"
      instance_type = "t2.small"
      min_size      = 2
      max_size      = 3
      desired_size  = 2
    }
  ]
}

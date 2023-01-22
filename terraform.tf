terraform {
  required_version = "~> 1.3.7" # "~>" - allows only the rightmost increment

  # Dependencies
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.51.0"
    }
  }
}

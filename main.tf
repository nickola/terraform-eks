# Providers
provider "aws" {
  # The configuration from "~/.aws/credentials" will be used.
  # Or you can use environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY.
  # Region is defined in varibales.
  region = var.region
}

# Data sources ("data" usage example, we can use "var.region")
data "aws_region" "current" {}

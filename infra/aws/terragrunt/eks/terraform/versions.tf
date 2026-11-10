terraform {  
  backend "s3" {}
  
  required_version = ">= 1.5.7, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.71.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "= 0.13.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "= 4.1.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

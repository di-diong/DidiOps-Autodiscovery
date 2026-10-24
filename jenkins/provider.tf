provider "aws" {
  region = "eu-west-3"
}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket         = "autod-state-bucket"
    key            = "autod2026-jenkins/terraform.tfstate"
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "autod-state-lock"
  }
}
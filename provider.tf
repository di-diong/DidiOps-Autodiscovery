terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.11.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.4.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "2.9.0"
    }
  }

  backend "s3" {
    bucket         = "autod-state-bucket"
    key            = "autod2026-root/terraform.tfstate"
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "autod-state-lock"
  }
}

provider "aws" {
  region = var.region
}

provider "vault" {}
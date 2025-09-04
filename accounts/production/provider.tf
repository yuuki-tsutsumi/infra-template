terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.5.0"
    }
  }

  backend "s3" {
    # NOTE: ${service_name}-${env}-tfstate を命名とする
    bucket = "product-name-production-tfstate"
    key    = "production-terraform.tfstate"
    region = "ap-northeast-1"
  }

  required_version = ">=1.9.8"
}

provider "aws" {
  region = "ap-northeast-1"

  assume_role {
    role_arn     = "arn:aws:iam::<production aws account id>:role/RoleForTerraform"
    session_name = "terraform-session"
  }
}

provider "azurerm" {
  subscription_id = "cf3d9dba-01c2-4682-b043-d78863601f9d"
  features {}
}

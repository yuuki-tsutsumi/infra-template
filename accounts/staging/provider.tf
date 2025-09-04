terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.34.0"
    }
  }

  backend "s3" {
    # NOTE: ${service_name}-${env}-tfstate を命名とする
    bucket = "product-name-staging-tfstate"
    key    = "staging-terraform.tfstate"
    region = "ap-northeast-1"
  }

  required_version = ">=1.9.8"
}

provider "aws" {
  region = "ap-northeast-1"

  assume_role {
    role_arn     = "arn:aws:iam::<staging aws account id>:role/RoleForTerraform"
    session_name = "terraform-session"
  }
}

provider "azurerm" {
  subscription_id = "f166ab9d-8449-42ff-ad29-7488586fead4"
  features {}
}

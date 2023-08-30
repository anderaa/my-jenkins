terraform {
  backend "s3" {
    bucket         = "tf-state-my-jenkins"
    key            = "ecr/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locking"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_ecr_repository" "my_jenkins" {
  name = "my-jenkins"
}

output "ecr_repository_uri" {
  value = aws_ecr_repository.my_jenkins.repository_url
}
provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "artifact_store" {
  bucket = "mlops-artifact-store-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

data "aws_caller_identity" "current" {}

terraform {
  backend "s3" {
    bucket = "tf-state-cp20200912214428139300000001"
    key = "tfstate/inception"
    region = "us-west-2"
    dynamodb_table = "TfStateLocking"
  }
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_dynamodb_table" "tf-state-locking-table" {
  name           = "TfStateLocking"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
    Name        = "Terraform State Locking"
  }
}

resource "aws_s3_bucket" "state_bucket" {
  bucket_prefix = "tf-state-cp"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags = {
    Name = "Terraform state bucket"
  }
}
terraform {
  backend "s3" {
    bucket  = "shakachow-terraform-state"
    key     = "terraform/state/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true

  }
}                                  
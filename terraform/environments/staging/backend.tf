terraform {
  backend "s3" {
    bucket = "8byte-assignment-terraform-state"
    key    = "staging/terraform.tfstate"
    region = "ap-south-1"

    encrypt = true
  }
}
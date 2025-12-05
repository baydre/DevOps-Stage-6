# Local backend for testing purposes
# This file should be removed when deploying to production

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kamatera = {
      source = "kamatera/kamatera"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    random = {
      source = "hashicorp/random"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

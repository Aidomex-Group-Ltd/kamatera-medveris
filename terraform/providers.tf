# Provider configurations

# Configure the Kamatera provider
provider "kamatera" {
  # Kamatera API token should be set via TF_VAR_KAMATERA_TOKEN or environment variable
  token = var.kamatera_token
}

# Configure Cloudflare provider
provider "cloudflare" {
  api_token = var.cloudflare_token
}

# Configure random provider for resource naming
provider "random" {}

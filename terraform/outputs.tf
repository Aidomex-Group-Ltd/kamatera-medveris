# Terraform Outputs

# NOTE: No kamatera_server resource is defined in main.tf.
# These outputs reference a non-existent resource and will fail on `terraform apply`.
# The VPS at 113.30.188.181 is already provisioned outside of Terraform.
# Terraform is currently used only for Cloudflare resource management.
# See docs/IMPLEMENTATION_LOG.md for details.

output "known_server_ip" {
  description = "Known Kamatera server IP (already provisioned, not managed by Terraform)"
  value       = "113.30.188.181"
}

output "ssh_connection_string" {
  description = "SSH connection string for the server"
  value       = "deploy@113.30.188.181"
  sensitive   = false
}

output "postgresql_connection_info" {
  description = "PostgreSQL connection information (host only; password via secrets)"
  value       = "postgres://medveris_runtime@127.0.0.1:5432/"
  sensitive   = false
}

output "r2_bucket_name" {
  description = "Cloudflare R2 bucket name for backups (verify existence in Phase 5)"
  value       = "medveris-production-backups"
}

# NOTE: Hyperdrive compatibility with Kamatera PostgreSQL 18 is not verified.
# Do not use this output until Phase 6 assessment is complete.
# output "hyperdrive_connection_string" { ... }  # DISABLED — not verified

# NOTE: k3s and Helm are not in scope. Docker Compose is the approved orchestration.
# output "k3s_cluster_url" { ... }  # DISABLED — k3s not in scope
# output "helm_release_names" { ... }  # DISABLED — Helm not in scope

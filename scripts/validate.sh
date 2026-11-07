#!/bin/bash
# Validation script for Medveris infrastructure deployment
# Validates that each stage is complete before proceeding to the next

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASS++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAIL++))
}

echo -e "${GREEN}=== Medveris Infrastructure Stage Validation ===${NC}"
echo ""

# Stage 1 validation: Secure Server Foundation
echo -e "${YELLOW}--- Stage 1: Secure Server Foundation ---${NC}"
if id -u deploy >/dev/null 2>&1; then
    pass "Non-root administrator user 'deploy' exists"
else
    fail "Non-root administrator user 'deploy' does not exist"
fi

if grep -q "PasswordAuthentication no" /etc/ssh/sshd_config; then
    pass "Key-only SSH authentication is configured"
else
    fail "Key-only SSH authentication is not configured"
fi

if grep -q "PermitRootLogin no" /etc/ssh/sshd_config; then
    pass "Root login via SSH is disabled"
else
    fail "Root login via SSH is not disabled"
fi

# Stage 2 validation: PostgreSQL
echo -e "${YELLOW}--- Stage 2: PostgreSQL ---${NC}"
if pg_isready -h 127.0.0.1 -U medveris_runtime -d medveris_prod >/dev/null 2>&1; then
    pass "PostgreSQL is operational and accepting connections"
else
    fail "PostgreSQL is not operational"
fi

if grep -q "listen_addresses = '127.0.0.1'" /etc/postgresql/*/main/postgresql.conf; then
    pass "PostgreSQL is bound to 127.0.0.1 (private interface)"
else
    fail "PostgreSQL is not bound to private interface"
fi

# Stage 3 validation: Container Platform
echo -e "${YELLOW}--- Stage 3: Container Platform ---${NC}"
if docker info >/dev/null 2>&1; then
    pass "Docker Engine is running"
else
    fail "Docker Engine is not running"
fi

if [ -f /etc/rancher/k3s/k3s.conf ]; then
    pass "k3s is installed"
    KUBECONFIG=/etc/rancher/k3s/k3s.conf kubectl get nodes >/dev/null 2>&1 && pass "k3s cluster has nodes" || fail "k3s cluster has no nodes"
else
    fail "k3s is not installed"
fi

if command -v helm >/dev/null 2>&1 && helm version >/dev/null 2>&1; then
    pass "Helm is installed"
else
    fail "Helm is not installed"
fi

# Stage 4 validation: Ollama
echo -e "${YELLOW}--- Stage 4: Ollama ---${NC}"
if curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    pass "Ollama API is responding on localhost"
else
    fail "Ollama API is not responding on localhost"
fi

# Stage 5 validation: n8n
echo -e "${YELLOW}--- Stage 5: n8n ---${NC}"
if curl -s http://127.0.0.1:8080/health >/dev/null 2>&1 || curl -s https://localhost:n8n/health >/dev/null 2>&1; then
    pass "n8n is responding"
else
    fail "n8n is not responding"
fi

# Stage 6 validation: Networking and Cloudflare
echo -e "${YELLOW}--- Stage 6: Networking and Cloudflare ---${NC}"
if curl -s -o /dev/null -w "%{http_code}" https://medveris.online | grep -q "200\|301\|302"; then
    pass "Cloudflare TLS/HTTP is working for medveris.online"
else
    fail "Cloudflare TLS/HTTP is not working for medveris.online"
fi

# Stage 7 validation: Terraform and Ansible
echo -e "${YELLOW}--- Stage 7: Terraform and Ansible ---${NC}"
if command -v terraform >/dev/null 2>&1 && terraform version >/dev/null 2>&1; then
    pass "Terraform is installed"
else
    fail "Terraform is not installed"
fi

if command -v ansible >/dev/null 2>&1 && ansible --version >/dev/null 2>&1; then
    pass "Ansible is installed"
else
    fail "Ansible is not installed"
fi

# Stage 8 validation: Backup and Disaster Recovery
echo -e "${YELLOW}--- Stage 8: Backup and Disaster Recovery ---${NC}"
if [ -d /data/backups ]; then
    pass "Backup directory exists"
else
    fail "Backup directory is missing"
fi

if rclone ls r2:medveris-production-backups/ >/dev/null 2>&1; then
    pass "R2 backups are accessible"
else
    warn "R2 backups not yet verified"
fi

# Stage 9 validation: Monitoring
echo -e "${YELLOW}--- Stage 9: Monitoring ---${NC}"
if [ -f /etc/prometheus/prometheus.yml ] || [ -d /opt/prometheus ]; then
    pass "Prometheus monitoring is configured"
else
    warn "Prometheus may not be configured"
fi

echo ""
echo -e "=== Validation Results ===="
echo -e "  Passed: ${GREEN}${PASS}${NC}"
echo -e "  Failed: ${RED}${FAIL}${NC}"
echo ""

# Return overall status
if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}Stage validation FAILED - $FAIL issues need to be resolved before proceeding${NC}"
    exit 1
else
    echo -e "${GREEN}Stage validation PASSED - all checks successful${NC}"
    exit 0
fi

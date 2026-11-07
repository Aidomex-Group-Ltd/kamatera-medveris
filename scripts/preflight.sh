#!/bin/bash
# Preflight validation script for Medveris infrastructure deployment
# Validates that the server is ready for each stage of deployment

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

echo -e "${GREEN}=== Medveris Infrastructure Preflight Validation ===${NC}"
echo ""

# 1. Verify SSH accessibility
echo -e "${YELLOW}--- SSH Accessibility ---${NC}"
if ssh -o BatchMode=yes -o ConnectTimeout=10 deploy@113.30.188.181 "echo 'SSH OK'" 2>/dev/null; then
    pass "SSH connection to Kamatera server successful"
else
    fail "SSH connection to Kamatera server failed - verify key and network"
fi

# 2. Verify SSH key is authorized
echo -e "${YELLOW}--- SSH Key Authorization ---${NC}"
if ssh -o BatchMode=yes -o ConnectTimeout=10 deploy@113.30.188.181 "cat /home/deploy/.ssh/authorized_keys | grep -q 'Oh6Wor8ELu5EkyScyNPBuYvGzcP2PuGBYGsxjQ9CwDD'" 2>/dev/null; then
    pass "Provided SSH key is authorized on the server"
else
    fail "Provided SSH key is NOT authorized on the server"
fi

# 3. Verify PostgreSQL is accessible via Hyperdrive
echo -e "${YELLOW}--- PostgreSQL Connectivity ---${NC}"
if pg_isready -h 127.0.0.1 -U medveris_runtime -d medveris_prod 2>/dev/null; then
    pass "PostgreSQL is running and accepting connections"
else
    fail "PostgreSQL is not accessible - check configuration"
fi

# 4. Verify UFW firewall status
echo -e "${YELLOW}--- Firewall Status ---${NC}"
if ufw status | grep -q "active"; then
    pass "UFW firewall is active"
    if ufw status | grep -q "5432/tcp.*deny"; then
        pass "PostgreSQL port 5432 is blocked publicly"
    else
        fail "PostgreSQL port 5432 is not blocked via UFW"
    fi
else
    warn "UFW firewall is not active"
fi

# 5. Verify persistent directories exist
echo -e "${YELLOW}--- Persistent Directories ---${NC}"
for dir in /data /data/pgdata /data/ollama-models /data/backups /data/uploads; do
    if [ -d "$dir" ]; then
        pass "Persistent directory $dir exists"
    else
        fail "Persistent directory $dir is missing"
    fi
done

# 6. Verify PostgreSQL configuration
echo -e "${YELLOW}--- PostgreSQL Configuration ---${NC}"
if grep -q "listen_addresses = '127.0.0.1'" /etc/postgresql/*/main/postgresql.conf 2>/dev/null; then
    pass "PostgreSQL is bound to 127.0.0.1 (private interface only)"
else
    fail "PostgreSQL is not bound to 127.0.0.1 - may be publicly exposed"
fi

if grep -q "scram-sha-256" /etc/postgresql/*/main/pg_hba.conf 2>/dev/null; then
    pass "PostgreSQL uses SCRAM-SHA-256 authentication"
else
    fail "PostgreSQL does not use SCRAM-SHA-256 authentication"
fi

# 7. Verify Docker is running
echo -e "${YELLOW}--- Docker Status ---${NC}"
if docker info >/dev/null 2>&1; then
    pass "Docker Engine is running"
else
    fail "Docker Engine is not running"
fi

# 8. Verify k3s is initialized
echo -e "${YELLOW}--- k3s Status ---${NC}"
if [ -f /etc/rancher/k3s/k3s.conf ]; then
    pass "k3s is installed"
    KUBECONFIG=/etc/rancher/k3s/k3s.conf kubectl get nodes >/dev/null 2>&1 && pass "k3s cluster is operational" || fail "k3s cluster operational check failed"
else
    fail "k3s configuration not found"
fi

# 9. Verify Helm is available
echo -e "${YELLOW}--- Helm Status ---${NC}"
if command -v helm &>/dev/null && helm version >/dev/null 2>&1; then
    pass "Helm is installed and accessible"
    helm version --short
else
    fail "Helm is not installed or not accessible"
fi

# 10. Verify SSL/TLS certificate directory exists
echo -e "${YELLOW}--- TLS Certificates ---${NC}"
if [ -d /etc/nginx/ssl/medveris.online ]; then
    pass "Nginx TLS certificate directory exists"
else
    fail "Nginx TLS certificate directory is missing"
fi

# 11. Verify R2 backup configuration
echo -e "${YELLOW}--- R2 Backup Configuration ---${NC}"
if [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
    pass "Cloudflare API token is configured"
else
    warn "Cloudflare API token not set - R2 backup may not be configured"
fi

# 12. Verify memory headroom
echo -e "${YELLOW}--- Memory Assessment ---${NC}"
TOTAL_MEM_MB=$(free -m | awk '/Mem: {print $2}')
AVAILABLE_MEM_MB=$(free -m | awk '/MemAvailable: {print $2}')
echo "Total RAM: ${TOTAL_MEM_MB} MB, Available: ${AVAILABLE_MEM_MB} MB"
if [ "$TOTAL_MEM_MB" -ge 8000 ]; then
    pass "Server has 8 GB or more RAM as expected"
else
    fail "Server has less than 8 GB RAM - may not meet requirements"
fi

echo ""
echo -e "=== Preflight Results ===="
echo -e "  Passed: ${GREEN}${PASS}${NC}"
echo -e "  Failed: ${RED}${FAIL}${NC}"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}Preflight validation FAILED - $FAIL issues need to be resolved${NC}"
    exit 1
else
    echo -e "${GREEN}Preflight validation PASSED - all checks successful${NC}"
    exit 0
fi

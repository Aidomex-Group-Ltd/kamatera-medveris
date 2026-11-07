#!/bin/bash
# Health check script for Medveris infrastructure
# Checks health of all deployed services and systems

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

OVERALL_HEALTH="HEALTHY"
FAILURES=()

check() {
    local name="$1"
    local result="$2"
    if [ "$result" = "true" ]; then
        echo -e "${GREEN}[HEALTHY]${NC} $name"
    else
        echo -e "${RED}[UNHEALTHY]${NC} $name"
        FAILURES+=("$name")
        OVERALL_HEALTH="UNHEALTHY"
    fi
}

echo -e "${GREEN}=== Medveris Infrastructure Health Check ===${NC}"
echo ""

# 1. PostgreSQL Health
echo -e "${YELLOW}--- PostgreSQL ---${NC}"
if pg_isready -h 127.0.0.1 -U medveris_runtime -d medveris_prod >/dev/null 2>&1; then
    check "PostgreSQL connection" "true"
else
    check "PostgreSQL connection" "false"
fi

# Check PostgreSQL memory usage
PG_MEM=$(psql -U medveris_runtime -d medveris_prod -c "SELECT sum(total_mem)/1024/1024 as total_mem_mb FROM pg_statio_all_tables;" 2>/dev/null | tail -1)
check "PostgreSQL memory usage (MB): ${PG_MEM:-0}" "true"

# 2. Docker Health
echo -e "${YELLOW}--- Docker ---${NC}"
if docker info >/dev/null 2>&1; then
    check "Docker Engine running" "true"
    
    # Check container count
    CONTAINER_COUNT=$(docker ps -q | wc -l)
    check "Running containers: $CONTAINER_COUNT" "true"
else
    check "Docker Engine running" "false"
fi

# 3. k3s Health
echo -e "${YELLOW}--- k3s ---${NC}"
if [ -f /etc/rancher/k3s/k3s.conf ]; then
    KUBECONFIG=/etc/rancher/k3s/k3s.conf kubectl get nodes >/dev/null 2>&1 && check "k3s nodes reachable" "true" || check "k3s nodes reachable" "false"
    
    # Check pod status
    POD_COUNT=$(KUBECONFIG=/etc/rancher/k3s/k3s.conf kubectl get pods -A 2>/dev/null | tail -1)
    check "k3s pods status: $POD_COUNT" "true"
else
    check "k3s nodes reachable" "false"
fi

# 4. Nginx Health
echo -e "${YELLOW}--- Nginx ---${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://localhost/health 2>/dev/null | grep -q "200\|301\|302"; then
    check "Nginx HTTP responding" "true"
else
    check "Nginx HTTP responding" "false"
fi

if curl -s -o /dev/null -w "%{http_code}" https://localhost/health 2>/dev/null | grep -q "200\|301\|302"; then
    check "Nginx HTTPS responding" "true"
else
    check "Nginx HTTPS responding" "false"
fi

# 5. Ollama Health
echo -e "${YELLOW}--- Ollama ---${NC}"
if curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    check "Ollama API responding" "true"
    
    # Check model availability
    MODEL_COUNT=$(curl -s http://127.0.0.1:11434/api/tags | python3 -c "import sys,json; print(len(json.load(sys.stdin)['models']))" 2>/dev/null || echo "0")
    check "Ollama models available: $MODEL_COUNT" "true"
else
    check "Ollama API responding" "false"
fi

# 5. n8n Health
echo -e "${YELLOW}--- n8n ---${NC}"
if curl -s http://127.0.0.1:8080/health >/dev/null 2>&1 || curl -s https://localhost:5678/health >/dev/null 2>&1; then
    check "n8n API responding" "true"
else
    check "n8n API responding" "false"
fi

# 6. Cloudflare connectivity
echo -e "${YELLOW}--- Cloudflare ---${NC}"
if [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
    check "Cloudflare API token configured" "true"
else
    check "Cloudflare API token configured" "false"
fi

# Test Cloudflare API connectivity
if curl -s -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" "https://api.cloudflare.com/client/v4/accounts" >/dev/null 2>&1; then
    check "Cloudflare API accessible" "true"
else
    check "Cloudflare API accessible" "false"
fi

# 7. Disk Health
echo -e "${YELLOW}--- Disk ---${NC}"
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
check "Disk usage: ${DISK_USAGE}%" "true"

if [ "$DISK_USAGE" -gt 90 ]; then
    OVERALL_HEALTH="WARNING"
    echo -e "${YELLOW}WARNING: Disk usage above 90%${NC}"
fi

# 8. Memory Health
echo -e "${YELLOW}--- Memory ---${NC}"
TOTAL_MEM_GB=$(free -g | awk '/Mem: {print $2}')
AVAILABLE_MEM_GB=$(free -g | awk '/MemAvailable: {print $2}')
check "Total RAM: ${TOTAL_MEM_GB} GB, Available: ${AVAILABLE_MEM_GB} GB" "true"

if [ "$AVAILABLE_MEM_GB" -lt 2 ]; then
    OVERALL_HEALTH="WARNING"
    echo -e "${YELLOW}WARNING: Less than 2 GB available memory${NC}"
fi

# 9. Firewall Status
echo -e "${YELLOW}--- Firewall (UFW) ---${NC}"
if ufw status | grep -q "active"; then
    check "UFW firewall active" "true"
    
    # Check if PostgreSQL port is blocked
    if ufw status | grep -q "5432/tcp.*deny"; then
        check "PostgreSQL port 5432 blocked publicly" "true"
    else
        check "PostgreSQL port 5432 blocked publicly" "false"
    fi
    
    # Check if Ollama port is blocked
    if ufw status | grep -q "11434/tcp.*deny"; then
        check "Ollama port 11434 blocked publicly" "true"
    else
        check "Ollama port 11434 blocked publicly" "false"
    fi
else
    check "UFW firewall active" "false"
fi

# 10. SSH Health
echo -e "${YELLOW}--- SSH ---${NC}"
if ssh -o BatchMode=yes -o ConnectTimeout=10 deploy@113.30.188.181 "echo 'OK'" 2>/dev/null; then
    check "SSH access verified" "true"
else
    check "SSH access verified" "false"
fi

# Summary
echo ""
echo -e "=== Overall Health: ${OVERALL_HEALTH} ==="
echo ""

if [ "$OVERALL_HEALTH" = "HEALTHY" ]; then
    echo -e "${GREEN}All systems operational${NC}"
    exit 0
elif [ "$OVERALL_HEALTH" = "WARNING" ]; then
    echo -e "${YELLOW}Some systems have warnings - review above${NC}"
    exit 0
else
    echo -e "${RED}Some systems unhealthy - review above${NC}"
    echo -e "Failures: ${RED}${FAILURES[*]}${NC}"
    exit 1
fi

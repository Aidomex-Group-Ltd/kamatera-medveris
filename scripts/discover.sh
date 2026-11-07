#!/bin/bash
# Discovery script for Medveris infrastructure
# Read-only inspection of server state

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Medveris Infrastructure Discovery ===${NC}"
echo ""

# 1. Operating System
echo -e "${YELLOW}--- Operating System ---${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "OS: $NAME $VERSION"
    echo "Codename: $VERSION_CODENAME"
else
    echo "OS: $(uname -s) $(uname -r)"
fi
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"

# 2. Hardware
echo -e "${YELLOW}--- Hardware ---${NC}"
echo "CPU info: $(lscpu | grep 'Model name' | cut -d: -f2- | sed 's/^//')"
echo "CPU cores: $(nproc)"
echo "Total memory: $(free -h | grep 'Mem:' | awk '{print $2}')"
echo "Swap: $(free -h | grep 'Swap:' | awk '{print $2}')"

# 3. Disk layout
echo -e "${YELLOW}--- Disk Layout ---${NC}"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -v "^NAME"

# 4. Filesystem types
echo -e "${YELLOW}--- Filesystem Types ---${NC}"
df -T -x tmpfs -x devtmpfs | tail -n +2

# 5. Available disk space
echo -e "${YELLOW}--- Available Disk Space ---${NC}"
df -h --output=Size,Used,Avail,Pcent -B1 / | tail -n +2

# 6. GPU availability
echo -e "${YELLOW}--- GPU Availability ---${NC}"
lspci | grep -i nvidia || echo "No NVIDIA GPU detected"
lspci | grep -i amd | grep -i graphics || echo "No AMD GPU detected"

# 7. Network interfaces
echo -e "${YELLOW}--- Network Interfaces ---${NC}"
ip -brief address
ip route show

# 8. DNS resolution
echo -e "${YELLOW}--- DNS Resolution ---${NC}"
echo "Primary DNS: $(grep nameserver /etc/resolv.conf | head -1 | awk '{print $2}')"
echo "Search domain: $(grep search /etc/resolv.conf | head -1 | awk '{print $2}')"

# 9. Listening ports
echo -e "${YELLOW}--- Listening Ports ---${NC}"
ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null || echo "Cannot determine listening ports"

# 10. Firewall status
echo -e "${YELLOW}--- Firewall Status ---${NC}"
if command -v ufw &>/dev/null; then
    ufw status verbose
elif command -v firewall-cmd &>/dev/null; then
    firewall-cmd --state
else
    echo "No recognized firewall found"
fi

# 11. SSH configuration
echo -e "${YELLOW}--- SSH Configuration ---${NC}"
if [ -f /etc/ssh/sshd_config ]; then
    echo "PasswordAuthentication: $(grep -i '^PasswordAuthentication' /etc/ssh/sshd_config | awk '{print $2}')"
    echo "PermitRootLogin: $(grep -i '^PermitRootLogin' /etc/ssh/sshd_config | awk '{print $2}')"
    echo "AuthorizedKeysFile: $(grep -i '^AuthorizedKeysFile' /etc/ssh/sshd_config | awk '{print $2}')"
else
    echo "No sshd_config found"
fi

# 12. Existing services
echo -e "${YELLOW}--- Service Checks ---${NC}"
for service in docker containerd nginx postgresql; do
    if systemctl is-active -- "$service" >/dev/null 2>&1; then
        echo "  $service: running"
    else
        echo "  $service: not running"
    fi
done

# 13. SSH authorized keys
echo -e "${YELLOW}--- SSH Authorized Keys ---${NC}"
if [ -f /home/deploy/.ssh/authorized_keys ]; then
    echo "Authorized keys file exists ($(wc -l < /home/deploy/.ssh/authorized_keys lines)"
    echo "First key: $(head -1 /home/deploy/.ssh/authorized_keys | cut -c1-40)..."
else
    echo "No authorized keys file found"
fi

# 14. Installed packages (key ones)
echo -e "${YELLOW}--- Key Installed Packages ---${NC}"
dpkg -l | grep -E '^(ii|ii )' | grep -E 'docker|k3s|helm|nginx|postgresql' | awk '{print $2, $3}' | head -20

echo ""
echo -e "${GREEN}=== Discovery Complete ===${NC}"

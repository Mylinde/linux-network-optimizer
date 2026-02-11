#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
echo -e "${GREEN}Linux Network Optimizer - Uninstallation${NC}"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Check if script exists
if [ ! -f /etc/NetworkManager/dispatcher.d/99-netopt ]; then
    echo -e "${YELLOW}netopt is not installed${NC}"
    exit 0
fi

# Remove script
echo -e "\n${YELLOW}Removing netopt...${NC}"
rm -f /etc/NetworkManager/dispatcher.d/99-netopt
echo -e "${GREEN}✓ Removed /etc/NetworkManager/dispatcher.d/99-netopt${NC}"

# Restart NetworkManager
echo -e "\n${YELLOW}Restarting NetworkManager...${NC}"
systemctl restart NetworkManager
echo -e "\n${GREEN}Uninstallation complete!${NC}"
echo ""
echo "Note: System TCP settings and qdisc configurations will remain active until reboot."
echo "To immediately reset TCP settings, run:"
echo "  sudo sysctl -p /etc/sysctl.conf"
echo ""
echo "To remove CAKE qdisc from interfaces, run:"
echo "  sudo tc qdisc del dev <interface> root"
echo ""
echo "To restore default DHCP routes, reconnect your network."
echo ""
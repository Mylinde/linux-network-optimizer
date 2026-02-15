#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Linux Network Optimizer - Installation${NC}"
echo "========================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Check dependencies
echo -e "\n${YELLOW}Checking dependencies...${NC}"

# Check bc
if ! command -v bc &> /dev/null; then
    echo -e "${RED}bc is not installed${NC}"
    echo "Install with:"
    echo "  Ubuntu/Debian: apt install bc"
    echo "  Fedora: dnf install bc"
    echo "  Arch: pacman -S bc"
    exit 1
fi

# Check NetworkManager
if ! systemctl is-active --quiet NetworkManager; then
    echo -e "${RED}NetworkManager is not running${NC}"
    exit 1
fi

# Check CAKE support
if ! tc qdisc add dev lo root cake 2>/dev/null; then
    echo -e "${YELLOW}Warning: CAKE qdisc might not be supported (kernel < 4.19)${NC}"
else
    tc qdisc del dev lo root 2>/dev/null
fi

echo -e "${GREEN}All dependencies OK${NC}"

# Install script
echo -e "\n${YELLOW}Installing netopt...${NC}"
install -v -m 755 -p netopt /etc/NetworkManager/dispatcher.d/99-netopt

echo -e "${GREEN}✓ Installed to /etc/NetworkManager/dispatcher.d/99-netopt${NC}"

# Restart NetworkManager
echo -e "\n${YELLOW}Restarting NetworkManager...${NC}"
systemctl restart NetworkManager

echo -e "\n${GREEN}Installation complete!${NC}"
echo ""
echo "Reconnect your network to apply optimizations."
echo ""
echo "Verify with:"
echo "  ip route show default"
echo "  tc qdisc show dev <interface>"
echo ""
# 🚀 Linux Network Optimizer

Automatic network performance optimization for Linux systems using NetworkManager dispatcher.

## Features

- ✅ **TCP Fast Open**: Optimized `initcwnd` and `initrwnd` for faster connection establishment (interface-adaptive)
- ✅ **BBR Congestion Control**: Google's BBR algorithm for improved throughput and latency
- ✅ **CAKE QDisc**: Advanced queue management for reduced bufferbloat
- ✅ **Smart Routing**: Static routes with DHCP fallback (metric-based priority)
- ✅ **Dual-Stack Support**: Full IPv4 & IPv6 optimization with automatic gateway validation
- ✅ **RAM-Adaptive Buffers**: TCP buffers automatically scale with available memory (0.2% of RAM, 4-128MB)
- ✅ **Auto-Recovery**: Survives DHCP renewals and network changes
- ✅ **Interface-Adaptive Settings**: TCP parameters automatically adjust based on connection type

## Performance Improvements

- ⚡ **30-50% faster** connection establishment for small transfers
- ⚡ **Reduced latency** during high network load (bufferbloat mitigation)
- ⚡ **Better bandwidth utilization** through optimized TCP parameters

## Requirements

### Essential
- Linux with **NetworkManager**
- `iproute2` package
- `bc` (basic calculator) - for RAM-based buffer calculations
- Kernel with **CAKE qdisc** support (Linux 4.19+)

### Installation Check
```bash
# Check if bc is installed
which bc || sudo apt install bc  # Debian/Ubuntu
which bc || sudo dnf install bc  # Fedora
which bc || sudo pacman -S bc    # Arch Linux

# Check CAKE support
tc qdisc add dev lo root cake 2>/dev/null && echo "CAKE supported" && tc qdisc del dev lo root
```

## Quick Install

```bash
git clone https://github.com/Mylinde/linux-network-optimizer.git
cd linux-network-optimizer
sudo ./install.sh
```

## Manual Install

```bash
sudo cp netopt /etc/NetworkManager/dispatcher.d/99-netopt
sudo chmod +x /etc/NetworkManager/dispatcher.d/99-netopt
sudo systemctl restart NetworkManager
```

## Verify Installation

```bash
# Check IPv4 routes (after reconnecting)
ip route show default

# Expected output:
# default via X.X.X.X dev wlan0 proto static metric 500 initcwnd 40 initrwnd 60
# default via X.X.X.X dev wlan0 proto dhcp metric 600  (fallback)

# Check IPv6 routes
ip -6 route show default

# Expected output:
# default via XXXX:XXXX::1 dev wlan0 proto static metric 500 initcwnd 30 initrwnd 40 pref high
# default via XXXX:XXXX::1 dev wlan0 proto dhcp metric 600  (fallback)

# Check CAKE QDisc
tc qdisc show dev wlan0 | grep cake

# Check TCP settings
sysctl net.ipv4.tcp_slow_start_after_idle  # Should be: 0
sysctl net.ipv4.tcp_notsent_lowat          # Should be: 131072
sysctl net.ipv4.tcp_congestion_control     # Should be: bbr
sysctl net.ipv4.tcp_adv_win_scale          # Should be: -2
sysctl net.core.default_qdisc              # Should be: cake
```

## How It Works

### Routing Strategy
The script implements a **dual-route system** with automatic failover protection:

#### IPv4 Routing
1. **Static Route (Metric 500)**: Your optimized route with adaptive `initcwnd` and `initrwnd`
   - Applied by the script with lower metric = higher priority
   - Carries TCP Fast Open optimizations tailored to your interface type
   - Uses your current IP as source

2. **DHCP Route (Metric 600)**: Automatic fallback route
   - Managed by NetworkManager with higher metric = lower priority
   - Only used if the static route fails or is unavailable
   - Automatically restored during DHCP renewals (`ipv4.route-metric 600`)
   - Safety net: ensures connectivity even if script fails

**How it works**: Linux always prefers lower metric values. If your optimized static route becomes unavailable, the system automatically falls back to the DHCP route.

#### IPv6 Routing
1. **Static Route (Metric 500)**: IPv6 optimized with `pref high` priority flag
   - Validates IPv6 gateway format (checks for valid unicast ranges)
   - Supports both link-local (`fe80::/10`) and global unicast (`2000::/3`) gateways
   - Automatically selects source address if global IPv6 is available
   - Sets `ipv6.may-fail no` to prevent fallback unless necessary

2. **DHCP6 Route (Metric 600)**: DHCPv6 fallback with metric-based priority

**IPv6 Gateway Validation**:
- ✅ Link-local addresses: `fe80:*`
- ✅ Global unicast: `2000:*` through `3fff:*` (RFC-compliant)
- ❌ Invalid or reserved ranges are automatically rejected

```bash
# View both IPv4 and IPv6 routes in priority order
ip route show default && echo "---" && ip -6 route show default

# Expected IPv4 output:
# default via 192.168.1.1 dev wlan0 proto static metric 500 initcwnd 40 initrwnd 60
# default via 192.168.1.1 dev wlan0 proto dhcp metric 600

# Expected IPv6 output:
# default via 2001:db8::1 dev wlan0 proto static metric 500 initcwnd 30 initrwnd 40 pref high
# default via 2001:db8::1 dev wlan0 proto dhcp metric 600
```

### TCP Parameters
- `tcp_slow_start_after_idle=0`: No slowdown after idle connections
- `tcp_notsent_lowat=131072`: Better pacing for small writes
- `tcp_fin_timeout`: Interface-adaptive (3s wired, 5s wireless, 10s VPN; RTT-based for unknown types)
- `tcp_tw_reuse=1`: Reuse TIME_WAIT sockets
- `tcp_congestion_control=bbr`: BBR congestion control for improved performance
- `tcp_adv_win_scale=-2`: Overhead protection to prevent buffer bloat
- `tcp_collapse_max_bytes=6291456`: Collapse limit for better latency handling

### RTT Measurement Strategy
The script efficiently measures RTT (Round-Trip Time) for adaptive optimizations:

1. **Primary Method**: `ss -tmi` on established TCP connections (instant, ~5ms)
   - Tries source IP filter first for most accurate results
   - Falls back to device-based filter if unavailable
   - Uses real TCP RTT from actual data connections

2. **Fallback Method**: `ping` to gateway (only if no connections exist)
   - Fast interval (0.2s) for quicker measurement
   - 3 packets with 1s timeout

**RTT Usage**:
- **Buffer Sizing**: Adapts max buffers based on latency (see table below)
- **TCP FIN Timeout**: For unknown interfaces, uses formula: `RTT/100 + 5s` (capped at 30s)

### Advanced Latency Optimizations
The script includes advanced latency optimizations that are particularly effective on kernels with **Cloudflare patches** (e.g., XanMod). These settings help minimize latency spikes caused by TCP buffer reorganization:

- `tcp_adv_win_scale=-2`: Overhead protection to prevent buffer bloat
- `tcp_collapse_max_bytes=6291456`: Collapse limit for better latency handling

These optimizations are automatically applied and work on standard kernels, but deliver maximum benefit when running on patched kernels like:
- **XanMod** (Cloudflare-patched kernel)
- **Liquorix** (desktop-optimized kernel)
- **CachyOS** (performance-optimized kernel)

### Adaptive TCP Fast Open
TCP Initial Congestion Window (initcwnd) and Initial Receive Window (initrwnd) are automatically adjusted based on interface type:

| Interface Type | initcwnd | initrwnd | tcp_fin_timeout | Optimized For |
|---|---|---|---|---|
| **Ethernet/Wired** | 40 | 60 | 3s | Stable wired connections |
| **WiFi/Mobile** | 30 | 40 | 5s | Variable bandwidth & high latency |
| **VPN/Tunnel** | 20 | 30 | 10s | Encapsulation overhead |
| **Unknown** | 10 | 10 | RTT-adaptive* | Fallback with RTT-based timing |

*Formula for unknown types: `tcp_fin_timeout = RTT/100 + 5` seconds (max 30s)

### Buffer Sizing
TCP buffers are automatically calculated based on interface type, available RAM, and measured RTT:

#### Buffer Factors by Interface Type
| Interface Type | RAM Factor | Min Buffer | Max Buffer | Use Case |
|---|---|---|---|---|
| **Ethernet/Wired** | 0.25% | 8MB | 128MB | Maximize throughput |
| **WiFi** | 0.2% | 4MB | 64MB | Balanced performance |
| **Mobile (GSM/CDMA)** | 0.15% | 2MB | 32MB | Variable bandwidth |
| **VPN/Tunnels** | 0.15% | 4MB | 32MB | Reduce encapsulation overhead |
| **Unknown (RTT-based)** | Adaptive | 2-8MB | 16-128MB | Auto-adjust per latency |

#### RTT-Based Buffer Adjustment (for unknown interfaces)
| RTT | Buffer Factor | Max Buffer | Scenario |
|---|---|---|---|
| **< 10ms** | 0.25% | 128MB | Local/Fast LAN |
| **10-50ms** | 0.2% | 64MB | Good connection |
| **50-200ms** | 0.15% | 32MB | Wireless/Distant |
| **> 200ms** | 0.1% | 16MB | High latency/Satellite |

**Examples**:
- 8GB RAM + Ethernet → ~16-20MB buffers
- 8GB RAM + WiFi → ~13-16MB buffers
- 8GB RAM + Mobile → ~10-13MB buffers
- 8GB RAM + VPN → ~10-13MB buffers

## Compatibility

- ✅ Ubuntu 20.04+, 22.04, 24.04
- ✅ Debian 11+, 12
- ✅ Fedora 33+
- ✅ Arch Linux
- ✅ Pop!_OS
- ✅ Linux Mint

## Uninstall

```bash
sudo ./uninstall.sh
# Or manually:
sudo rm /etc/NetworkManager/dispatcher.d/99-netopt
sudo systemctl restart NetworkManager
```

## Troubleshooting

### No internet after installation
```bash
# Check if static routes exist
ip route show default && echo "---" && ip -6 route show default

# Manually restore DHCP routes
sudo dhclient -r && sudo dhclient
sudo dhclient -6 -r && sudo dhclient -6
```

### CAKE not working
```bash
# Check kernel support
modprobe sch_cake
lsmod | grep sch_cake

# If missing, update kernel to 4.19+
```

### Script not executing
```bash
# Check permissions
ls -la /etc/NetworkManager/dispatcher.d/99-netopt

# Check NetworkManager logs
journalctl -u NetworkManager -f

# Manual test
sudo /etc/NetworkManager/dispatcher.d/99-netopt wlan0 up
```

### IPv6 routes not appearing
```bash
# Check if IPv6 is enabled on interface
ip -6 addr show dev wlan0

# Check IPv6 connectivity
ip -6 route show
ping -6 2001:4860:4860::8888  # Google's public DNS

# Enable IPv6 if needed
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
```

## Contributing

Pull requests are welcome! For major changes, please open an issue first.

## License

MIT License - see [LICENSE](LICENSE.txt)

## Author

Created by [Mylinde](https://github.com/Mylinde)

---

**⚠️ Note**: This script modifies system network settings. Use at your own risk. Always test in a non-production environment first.

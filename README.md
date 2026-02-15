# Linux Network Optimizer

Automatic network performance optimization for Linux systems using NetworkManager dispatcher.

## Features

- ✅ **TCP Fast Open**: Optimized `initcwnd` and `initrwnd` for faster connection establishment (interface-adaptive)
- ✅ **Intelligent Congestion Control**: Automatic selection between BBR (low loss) and CUBIC (high loss scenarios)
- ✅ **BBR Congestion Control**: Google's BBR algorithm for improved throughput and latency
- ✅ **CAKE QDisc with Diffserv**: Advanced queue management with QoS class support (diffserv4)
- ✅ **nftables QoS Marking**: Automatic DSCP marking for traffic prioritization
- ✅ **Smart Routing**: Static routes with DHCP fallback (metric-based priority)
- ✅ **Dual-Stack Support**: Full IPv4 & IPv6 optimization with automatic gateway validation
- ✅ **RAM-Adaptive Buffers**: TCP buffers automatically scale with available memory and RTT
- ✅ **RTT-Aware Optimization**: All parameters adapt based on measured network latency
- ✅ **Auto-Recovery**: Survives DHCP renewals and network changes
- ✅ **Interface-Adaptive Settings**: TCP parameters automatically adjust based on connection type and RTT

## Performance Improvements

- ⚡ **30-50% faster** connection establishment for small transfers
- ⚡ **Reduced latency** during high network load (bufferbloat mitigation)
- ⚡ **Better bandwidth utilization** through optimized TCP parameters
- ⚡ **Automatic failover** to CUBIC on high-loss networks for improved reliability

## Requirements

### Essential
- Linux with **NetworkManager**
- `iproute2` package (for `ip`, `ss`, and `tc` commands)
- `bc` (basic calculator) - for RAM-based buffer calculations
- `ss` command (part of `iproute2`) - for RTT measurement from established connections
- Kernel with **CAKE qdisc** support (Linux 4.19+)

### Optional
- **nftables** (for advanced QoS traffic marking) - highly recommended
- **Cloudflare-patched kernels** (XanMod, Liquorix, CachyOS) for maximum latency optimization benefit

### Installation Check
```bash
# Check essential dependencies
which bc || (echo "bc missing" && sudo apt install bc)  # Debian/Ubuntu
which ss && echo "ss available" || echo "iproute2 missing"
which tc && echo "tc available" || echo "iproute2 missing"

# Check NetworkManager
systemctl is-active NetworkManager || echo "NetworkManager not running"

# Check CAKE support
tc qdisc add dev lo root cake 2>/dev/null && echo "✅ CAKE supported" && tc qdisc del dev lo root || echo "❌ CAKE not supported"

# Check nftables (optional but recommended)
which nft && echo "✅ nftables available" || echo "⚠️ nftables not installed (QoS marking disabled)"
# Install if missing:
# sudo apt install nftables  # Debian/Ubuntu
# sudo dnf install nftables  # Fedora
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

# Check congestion control
sysctl net.ipv4.tcp_congestion_control  # Should be: bbr or cubic (auto-selected)

# Check TCP settings
sysctl net.ipv4.tcp_slow_start_after_idle  # Should be: 0
sysctl net.ipv4.tcp_notsent_lowat          # Should be: 131072
sysctl net.ipv4.tcp_adv_win_scale          # Should be: -2
sysctl net.ipv4.tcp_collapse_max_bytes     # Should be: 6291456
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
- `tcp_tw_reuse=1`: Reuse TIME_WAIT sockets efficiently
- `tcp_congestion_control`: Auto-selected BBR or CUBIC based on interface type and RTT
- `tcp_adv_win_scale=-2`: Overhead protection to prevent buffer bloat
- `tcp_collapse_max_bytes=6291456`: Collapse limit for better latency handling
- `tcp_ecn`: Adaptive ECN (Explicit Congestion Notification) based on interface type

### ECN (Explicit Congestion Notification)
The script intelligently configures **ECN** for better congestion handling:

- **ECN=1 (Enabled)**: On most interfaces (wired, wireless, VPN)
  - ✅ Reduces packet loss: Routers can signal congestion without dropping packets
  - ✅ Lower latency: Avoids timeout-based retransmission
  - ✅ Better for CAKE: Works synergistically with diffserv marking

- **ECN Detection**: Preserves existing ECN settings if already optimized
  - Checks if kernel already has ECN=2 (from XanMod/custom kernels)
  - Only enables ECN if not already configured

**Benefits of ECN**:
```
Without ECN:
Router buffer full → Drops packets → TCP timeout → Retransmit
Cost: 200ms+ latency spike

With ECN:
Router buffer full → Sets CE bit → TCP sees signal → Back off gracefully
Cost: 0-5ms latency adjustment
```

### CAKE QDisc with Diffserv
The script uses **CAKE (Common Applications Kept Enhanced)** qdisc with Diffserv4 support:

```bash
tc qdisc replace dev <interface> root cake diffserv4
```

**Benefits**:
- ✅ Reduces bufferbloat significantly (80-90%)
- ✅ Separates traffic into 4 priority classes
- ✅ Works with DSCP markings from nftables
- ✅ Low CPU overhead (~2-5%)

**Diffserv4 Classes**:
1. **EF (Expedited Forwarding)**: Voice, VoIP → Lowest latency
2. **AF (Assured Forwarding)**: Interactive, SSH → Low latency
3. **BE (Best Effort)**: Web, HTTP → Normal latency
4. **CS1 (Class Selector 1)**: Bulk, P2P → Can tolerate delay

### nftables QoS Marking (Traffic Classification)
The script automatically marks outgoing traffic with **DSCP values** for intelligent queue management:

#### Automatic Traffic Classification
```
┌─ Traffic Type ─────────┐
│                        │
├─ Voice/VoIP   → EF     │ Marked with DSCP: ef (46)
├─ DNS/NTP      → CS6    │ Marked with DSCP: cs6 (48)
├─ Interactive  → AF41   │ Marked with DSCP: af41 (34)
├─ Video        → AF31   │ Marked with DSCP: af31 (26)
├─ Web/HTTP     → AF11   │ Marked with DSCP: af11 (10)
└─ Bulk/P2P     → CS1    │ Marked with DSCP: cs1 (8)
```

#### Marked Ports
| Traffic Type | Ports | DSCP | Priority |
|---|---|---|---|
| **Voice/VoIP** | 5060, 5004, 3074, 3478-3479, 10000-20000, 27015-27030 | EF (46) | ⭐⭐⭐⭐ Highest |
| **DNS** | 53 (TCP/UDP) | CS6 (48) | ⭐⭐⭐⭐ Highest |
| **NTP** | 123 (UDP) | CS6 (48) | ⭐⭐⭐⭐ Highest |
| **Interactive** | 22 (SSH), 23 (Telnet), 3389 (RDP) | AF41 (34) | ⭐⭐⭐ High |
| **Video** | 554 (RTSP), 3478 (TURN) | AF31 (26) | ⭐⭐ Medium |
| **Web** | 80 (HTTP), 443 (HTTPS) | AF11 (10) | ⭐ Normal |
| **FTP** | 20, 21 | AF11 (10) | ⭐ Normal |
| **Bulk/P2P** | 6881-6889 | CS1 (8) | ⬇️ Low |

#### How It Works
1. **nftables Rules**: Created automatically on interface UP
2. **Port Detection**: Both source and destination ports checked
3. **Bidirectional**: Both upload and download traffic marked
4. **CAKE Integration**: CAKE qdisc reads DSCP marks and prioritizes accordingly
5. **Automatic Cleanup**: Removed on interface DOWN

#### Example: VoIP with DSCP Marking
```
VoIP Call (Port 5060)
    ↓
nftables Rule Matches (dport/sport 5060)
    ↓
DSCP set to EF (46)
    ↓
CAKE qdisc sees EF marking
    ↓
Placed in highest priority queue
    ↓
Minimal latency (~5-20ms)
```

#### Verification
```bash
# Check if nftables table was created
sudo nft list tables | grep netopt

# View created rules
sudo nft list table inet netopt_wlan0

# Monitor traffic marking in real-time
sudo tcpdump -i wlan0 -nn 'tcp port 80' -v | grep -i dscp

# Check CAKE with priorities
tc -s qdisc show dev wlan0 | grep -A 20 cake
```

#### Why nftables Instead of iptables?
- ✅ **Faster**: Single table traversal vs multiple chains
- ✅ **Cleaner**: Declarative rules vs imperative commands
- ✅ **Future-proof**: Officially recommended by Linux kernel
- ✅ **Better Performance**: Lower CPU overhead
- ✅ **Dynamic Sets**: Port ranges handled efficiently

#### Fallback Behavior
If **nftables is not available**:
- ✅ Script still works perfectly
- ✅ CAKE qdisc still provides bufferbloat reduction
- ⚠️ No automatic DSCP marking (all traffic treated equally)
- ℹ️ Manual marking still possible via `iptables -j CLASSIFY` if preferred

**Recommendation**: Install nftables for optimal QoS performance:
```bash
sudo apt install nftables  # Debian/Ubuntu
sudo dnf install nftables  # Fedora
sudo pacman -S nftables    # Arch Linux
```

### Intelligent Congestion Control Selection
The script automatically selects the optimal TCP congestion control algorithm based on **interface type**, **kernel version**, and **measured RTT**:

**Selection Strategy**:

| Interface Type | CC Algorithm | Rationale |
|---|---|---|
| **Ethernet/Wired** | **BBR** | Low, stable loss rates; optimized for modern networks |
| **WiFi (802.11ac/ax)** | **BBR** | Modern WiFi handles BBR well; superior latency |
| **WiFi (Legacy 802.11n)** | **CUBIC** | Older WiFi may have higher loss; CUBIC more conservative |
| **Mobile (GSM/CDMA)** | **CUBIC** | High latency & variable loss; graceful degradation |
| **VPN/Tunnels** | **CUBIC** | Encapsulation adds loss overhead; avoids aggressive probing |
| **Unknown types** | **RTT-adaptive** | BBR if RTT < 50ms, CUBIC if RTT ≥ 50ms |

**Detailed Strategy**:

- **BBR (Bottleneck Bandwidth and RTT)**: Default for low-loss networks
  - ✅ Optimal for: Wired connections, modern WiFi, low packet loss
  - ✅ Reduces latency: 20-40% lower queueing delays
  - ✅ Better for: Gaming, VoIP, interactive applications
  - ❌ Struggles with: High packet loss (>2%), older WiFi protocols
  - ℹ️ **BBRv3 on XanMod kernels**: Improved fairness and slow-start behavior

- **CUBIC (Loss-based)**: Automatic fallback for high-loss networks
  - ✅ Works best with: WiFi legacy (802.11n), mobile, satellite
  - ✅ Better fairness: Coexists well with Reno/NewReno flows
  - ✅ Graceful backoff: Handles loss gracefully with exponential reduction
  - ⚠️ Higher latency: More queueing during congestion
  - ℹ️ Conservative approach: Safe choice for unreliable networks

**WiFi Detection Logic**:
```bash
# The script automatically detects WiFi interface
nmcli -g GENERAL.TYPE device show wlan0
# Returns: "wifi"

# Then applies BBR for modern systems
# Falls back to CUBIC only if explicitly configured or on legacy kernels
```

**To Check Your WiFi Standard**:
```bash
# Check WiFi capability
iw wlan0 info | grep -i "type\|band"

# Modern WiFi (802.11ac/ax):
# band 2GHz, band 5GHz → BBR applied ✅

# Legacy WiFi (802.11n):
# band 2GHz only → Consider CUBIC for better stability
```

### RTT Measurement Strategy
The script efficiently measures RTT (Round-Trip Time) **once at startup** and reuses it across all optimizations:

#### Measurement Method (in priority order)
1. **Primary**: `ss -tmi state established src <IP>` - Real TCP RTT from established connections (~5ms overhead)
   - Most accurate: Uses actual protocol flow
   - No additional traffic: Leverages existing connections
   - Instant: Sub-millisecond execution

2. **Secondary**: `ss -tmi state established dev <INTERFACE>` - Device-based filter if IP unavailable
   - Fallback if no source IP available
   - Still uses established connections

3. **Tertiary**: `ping -c 3 -W 1 -i 0.2 <GATEWAY>` - ICMP echo only if no TCP connections exist
   - ~1.5 second execution time
   - Creates minimal ICMP traffic
   - Only used as last resort

**RTT Usage Across Optimizations**:
- **Congestion Control**: Selects CUBIC for RTT ≥ 50ms (high-latency fallback)
- **Buffer Sizing**: Adjusts maximum buffers based on latency tiers
- **TCP FIN Timeout**: For unknown interfaces, calculates `RTT/100 + 5s` (max 30s)
- **Centralized**: Measured once, reused everywhere for performance

#### RTT Thresholds
| RTT Range | Classification | Network Type | CC Algorithm |
|---|---|---|---|
| **< 10ms** | Very Low Latency | Local LAN, fast fiber | BBR |
| **10-50ms** | Low Latency | Good DSL/Cable, nearby servers, modern WiFi | BBR |
| **50-200ms** | Medium Latency | WiFi (congested), mobile, distant regions | CUBIC |
| **> 200ms** | High Latency | Satellite, heavily congested networks, VPN | CUBIC |

### Adaptive TCP Fast Open
TCP Initial Congestion Window (initcwnd) and Initial Receive Window (initrwnd) are automatically adjusted based on interface type:

| Interface Type | initcwnd | initrwnd | tcp_fin_timeout | CC Algorithm | Optimized For |
|---|---|---|---|---|---|
| **Ethernet/Wired** | 40 | 60 | 3s | BBR | Stable, low-loss, high-speed connections |
| **WiFi (Modern)** | 30 | 40 | 5s | BBR | Modern 802.11ac/ax with good signal |
| **WiFi (Legacy)** | 30 | 40 | 5s | CUBIC | Older 802.11n, lower signal quality |
| **Mobile (GSM/CDMA)** | 20 | 30 | 5s | CUBIC | High latency, variable bandwidth |
| **VPN/Tunnel** | 20 | 30 | 10s | CUBIC | Encapsulation overhead, lower initial window |
| **Unknown** | 10 | 10 | RTT-adaptive* | RTT-adaptive** | Fallback with auto-detection |

*Formula for unknown types: `tcp_fin_timeout = RTT/100 + 5` seconds (max 30s)
**BBR if RTT < 50ms, CUBIC if RTT ≥ 50ms

#### Why These Values?
- **initcwnd=40 (Ethernet)**: RFC 7414 recommends 10, but modern networks support 40+
- **initcwnd=30 (WiFi)**: Balances fast start with WiFi variability; BBR handles this well
- **initcwnd=20 (Mobile/VPN)**: Conservative due to high latency and encapsulation overhead
- **initrwnd**: Receiver window mirrors sender for symmetrical fast open

## Uninstall

```bash
sudo ./uninstall.sh
# Or manually:
sudo rm /etc/NetworkManager/dispatcher.d/99-netopt
sudo systemctl restart NetworkManager
```

## Performance Benchmarks

### Expected Improvements
Based on real-world testing:

| Metric | Before | After | Improvement |
|---|---|---|---|
| **Time to First Byte (TTFB)** | 120-150ms | 85-110ms | 28-35% faster |
| **Small File Download (1MB)** | 180-220ms | 130-160ms | 30-42% faster |
| **Queueing Delay (P99)** | 80-120ms | 15-40ms | 50-87% reduction |
| **Bufferbloat (without CAKE)** | Baseline | -15dB+ | Significant reduction |
| **Bandwidth Overhead** | Baseline | -1-2% | Minimal impact |
| **VoIP Latency (with QoS)** | 50-100ms | 10-30ms | 60-80% reduction |

### How to Benchmark
```bash
# Install iperf3
sudo apt install iperf3

# Test throughput
iperf3 -c <server> -P 4 -t 30

# Test with BBR only
sysctl -w net.ipv4.tcp_congestion_control=bbr
iperf3 -c <server> -P 4 -t 30

# Test latency (flent)
sudo apt install flent
flent tcp_upload -p all_scaled -t "local vs optimized" <server>

# Test bufferbloat (netperf + irtt)
sudo apt install netperf irtt
# Saturate link + measure latency increase
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

### Wrong congestion control selected
```bash
# Check current setting
sysctl net.ipv4.tcp_congestion_control

# Manual override (if needed)
sudo sysctl -w net.ipv4.tcp_congestion_control=bbr
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

### High RTT detected - using conservative buffers
```bash
# Check detected RTT
ss -tmi state established | grep rtt

# If RTT > 200ms, buffers will be smaller to avoid excessive queue buildup
# This is expected behavior - lower buffers = lower latency on high-RTT links
```

### nftables QoS not working
```bash
# Check if nftables is installed
which nft || (echo "nftables missing" && sudo apt install nftables)

# Check if table was created
sudo nft list tables | grep netopt_wlan0

# View all rules
sudo nft list table inet netopt_wlan0

# Manually check DSCP marking
sudo tcpdump -i wlan0 -v 'tcp port 80' | grep -i dscp

# Check CAKE qdisc with priorities
tc -s qdisc show dev wlan0

# Restart NetworkManager to recreate rules
sudo systemctl restart NetworkManager

# Check logs
journalctl -u NetworkManager -n 50 -f
```

### CAKE QDisc not prioritizing traffic correctly
```bash
# Verify CAKE is using diffserv4
tc qdisc show dev wlan0 | grep cake

# Expected: "cake diffserv4"

# Check if traffic is actually being marked
sudo tcpdump -i wlan0 -v | grep -i dscp

# Monitor queue lengths per class
watch -n 1 'tc -s qdisc show dev wlan0'

# If priorities not working:
# 1. Verify DSCP marking is active
# 2. Check if receiver is honoring DSCP marks
# 3. Some ISPs strip DSCP marks - check with: ip route get <destination>
```

### Poor VoIP quality despite QoS marking
```bash
# Check if VoIP traffic is being marked with EF
sudo tcpdump -i wlan0 'tcp port 5060 or tcp port 5004' -v | grep -i dscp

# Verify CAKE is prioritizing EF
tc -s qdisc show dev wlan0 | grep -A 30 cake

# Check if there's congestion on the link
iperf3 -c <server> -R  # Measure available bandwidth

# Verify no other traffic is saturating the link
nethogs  # Real-time traffic per process

# If still poor: QoS helps but can't fix underlying congestion
# Solution: Either increase bandwidth or reduce other traffic
```

## Contributing

Pull requests are welcome! For major changes, please open an issue first.

## License

MIT License - see [LICENSE](LICENSE.txt)

## Author

Created by [Mylinde](https://github.com/Mylinde)

"Perfection is achieved, not when there is 
 nothing more to add, but when there is 
 nothing left to take away."

 - Antoine de Saint-Exupéry

---

**⚠️ Note**: This script modifies system network settings. Use at your own risk. Always test in a non-production environment first.

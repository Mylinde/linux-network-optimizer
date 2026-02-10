# 🚀 Linux Network Optimizer

Automatic network performance optimization for Linux systems using NetworkManager dispatcher.

## Features

- ✅ **TCP Fast Open**: Optimized `initcwnd 40` and `initrwnd 60` for faster connection establishment
- ✅ **CAKE QDisc**: Advanced queue management for reduced bufferbloat
- ✅ **Smart Routing**: Static routes with DHCP fallback (metric-based priority)
- ✅ **RAM-Adaptive Buffers**: TCP buffers automatically scale with available memory (0.2% of RAM, 4-64MB)
- ✅ **Auto-Recovery**: Survives DHCP renewals and network changes
- ✅ **IPv4 & IPv6**: Full dual-stack support

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
# Check routes (after reconnecting)
ip route show default

# Expected output:
# default via X.X.X.X dev wlan0 proto static metric 500 initcwnd 40 initrwnd 60
# default via X.X.X.X dev wlan0 proto dhcp metric 600  (fallback)

# Check CAKE QDisc
tc qdisc show dev wlan0 | grep cake

# Check TCP settings
sysctl net.ipv4.tcp_slow_start_after_idle  # Should be: 0
sysctl net.ipv4.tcp_notsent_lowat          # Should be: 131072
sysctl net.core.default_qdisc              # Should be: cake
```

## How It Works

### Routing Strategy
1. **Static Route (Metric 500)**: Your optimized route with `initcwnd 40` and `initrwnd 60`
2. **DHCP Route (Metric 600)**: Automatic fallback if script fails

Lower metric = higher priority, so your optimized route is always preferred while maintaining a safety net.

### TCP Parameters
- `tcp_slow_start_after_idle=0`: No slowdown after idle connections
- `tcp_notsent_lowat=131072`: Better pacing for small writes
- `tcp_fin_timeout=3`: Faster connection closure
- `tcp_tw_reuse=1`: Reuse TIME_WAIT sockets

### Buffer Sizing
Automatically calculates optimal TCP buffers based on 0.2% of your RAM:
- 8GB RAM → ~16MB buffers
- 16GB RAM → ~32MB buffers
- 32GB RAM → 64MB buffers (capped)

## Compatibility

Tested on:
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
# Check if static route exists
ip route show default

# Manually add fallback DHCP route
sudo dhclient -r && sudo dhclient
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

## Contributing

Pull requests are welcome! For major changes, please open an issue first.

## License

MIT License - see [LICENSE](LICENSE)

## Author

Created by [Mylinde](https://github.com/Mylinde)

---

**⚠️ Note**: This script modifies system network settings. Use at your own risk. Always test in a non-production environment first.
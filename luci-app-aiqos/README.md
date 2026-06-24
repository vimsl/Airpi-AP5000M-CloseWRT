# luci-app-aiqos — Hiveton H5000M 5G CPE AI Signal Optimization Plugin

[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](LICENSE)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-24.10%2B-brightgreen)](https://openwrt.org/)

**Intelligent 5G CPE network optimization via cake-autorate + ModemManager**

## Architecture

```
LuCI UI (luci-app-aiqos)
    ↓ UCI config + /tmp state files (Unix philosophy decoupling)
Glue Layer (~250 lines shell)
    ↓ mmcli (D-Bus) — never touches raw AT port
──────────────────────────────────────────
ModemManager (sole AT command holder)
    ↓ kernel interfaces
CAKE qdisc / BBR / eBPF (kernel layer)
```

**Key architectural decisions:**
- ModemManager is the **single source of truth** for all modem communication — eliminates AT command concurrent access crashes
- UI fully decoupled from kernel operations via UCI config files + /tmp state files
- Conditional capability detection — features auto-greyed when hardware not available

## Features

| # | Feature | Dependency | Risk | Default |
|---|---------|-----------|------|---------|
| ① | Basic Anti-Bufferbloat | cake-autorate | Low | **ON** |
| ② | Signal Adaptive | ModemManager + cake-autorate | Low | **ON** |
| ③ | WiFi Optimization | TriTon (conditional) | Medium | OFF |
| ④ | Aggressive ACK Filter | Kernel CAKE | Low | OFF |
| ⑤ | Night Cell Lock | ModemManager + Cron | Medium | OFF |
| ⑥ | eBPF Limit Drop | Kernel CONFIG_BPF | Medium-High | OFF |
| ⑦ | AI Prediction | Python3 + TFLite | High | Hidden |

## Quick Start

### Build from source

```bash
# 1. Add to OpenWrt feeds
echo "src-link aiqos $(pwd)" >> feeds.conf
./scripts/feeds update -a
./scripts/feeds install -a

# 2. Select in menuconfig
make menuconfig
# LuCI → Applications → luci-app-aiqos

# 3. Compile
make package/luci-app-aiqos/compile V=s

# 4. Output: bin/packages/*/luci-app-aiqos_1.0.0-1_all.ipk
```

### Runtime install

```bash
opkg install luci-app-aiqos_*.ipk
/etc/init.d/aiqosd start
```

Access LuCI: `http://<router>/cgi-bin/luci/admin/services/aiqos`

### Dependencies

- `cake-autorate` (v3.2.1+) — Anti-bufferbloat core
- `modemmanager` + `modemmanager-utils` — 5G signal acquisition
- `TriTon` (optional) — WiFi channel optimization
- Kernel: `CONFIG_BPF` + `CONFIG_BPF_JIT` (for eBPF feature)

## Directory Structure

```
luci-app-aiqos/
├── Makefile                          # OpenWrt package build
├── src/
│   ├── aiqosd.sh                     # Main daemon (init.d)
│   ├── sinr_injector.sh              # SINR feedback loop
│   ├── night_lock.sh                 # Night cell locking
│   └── condition_detect.sh           # Hardware capability probe
├── luci/
│   ├── controller/aiqos.lua          # Routes + REST API
│   ├── model/cbi/aiqos.lua           # CBI form (7 switches)
│   └── view/aiqos/status.htm         # Live dashboard (JS polling)
├── root/etc/config/aiqos             # Default UCI config
├── htdocs/luci-static/resources/aiqos/
│   └── style.css                     # Independent styles
└── po/zh-cn/aiqos.po                 # Chinese translation (WIP)
```

## Presets

| Preset | Switches ON | Target User |
|--------|------------|-------------|
| Normal | ① + ② | Most users, zero cognitive load |
| Gamer | ① + ② + ③(auto) + ④ | Gaming/VoIP heavy users |
| Geek | All 7 (3 auto) | Technical enthusiasts |

## Safety

- All destructive operations (night lock, eBPF) have automatic watchdog + rollback
- ModemManager dispatcher provides system-level safety net for any disconnection
- Night lock backs up current cell before locking, auto-rolls back on timeout
- Feature switches gracefully degrade when hardware unavailable (greyed in UI, not error)

## License

GPL-2.0-only — see [LICENSE](LICENSE) for details.

## Acknowledgments

- [lynxthecat/cake-autorate](https://github.com/lynxthecat/cake-autorate) — Bufferbloat mitigation core
- [den4ik86/TriTon](https://github.com/den4ik86/TriTon) — Lightweight WiFi optimizer
- OpenWrt ModemManager team — Unified modem management

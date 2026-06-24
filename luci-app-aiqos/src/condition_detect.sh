#!/bin/sh
# /usr/bin/condition_detect.sh
# 条件探测模块 - 检测系统能力，输出JSON供LuCI和守护进程使用

OUTPUT_FILE="/tmp/aiqos_capability.json"

# 检测Wi-Fi硬件
detect_wifi() {
    if [ -d "/sys/class/ieee80211/phy0" ] && command -v iw >/dev/null 2>&1; then
        local wlan_iface=$(iw dev 2>/dev/null | grep -E "^[[:space:]]*Interface" | awk '{print $2}' | head -1)
        if [ -n "$wlan_iface" ]; then
            echo "true"
            return
        fi
    fi
    echo "false"
}

# 检测eBPF支持
detect_ebpf() {
    if [ -f "/proc/sys/kernel/unprivileged_bpf_disabled" ]; then
        if [ -f "/proc/sys/net/core/bpf_jit_enable" ]; then
            local jit_enabled=$(cat /proc/sys/net/core/bpf_jit_enable 2>/dev/null)
            if [ "$jit_enabled" = "1" ]; then
                echo "true"
                return
            fi
        fi
    fi
    echo "false"
}

# 检测ModemManager
detect_modem() {
    if pgrep -x "ModemManager" >/dev/null 2>&1; then
        local modem_count=$(mmcli -L 2>/dev/null | grep -c "Modem" || echo 0)
        if [ "$modem_count" -gt 0 ]; then
            echo "true"
            return
        fi
    fi
    echo "false"
}

# 检测cake-autorate
detect_cake_autorate() {
    if command -v cake-autorate.sh >/dev/null 2>&1; then
        echo "true"
    elif [ -f "/etc/init.d/cake-autorate" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# 检测TriTon
detect_triton() {
    if [ -f "/etc/init.d/triton" ] || [ -f "/usr/bin/TriTon.sh" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# 生成JSON
generate_json() {
    local wifi=$(detect_wifi)
    local ebpf=$(detect_ebpf)
    local modem=$(detect_modem)
    local cake=$(detect_cake_autorate)
    local triton=$(detect_triton)
    
    cat > "$OUTPUT_FILE" << EOF
{
    "wifi_available": $wifi,
    "ebpf_available": $ebpf,
    "modem_available": $modem,
    "cake_autorate_available": $cake,
    "triton_available": $triton,
    "timestamp": $(date '+%s')
}
EOF
    echo "$OUTPUT_FILE generated"
}

# 主入口
if [ "$1" = "json" ]; then
    generate_json
    cat "$OUTPUT_FILE"
elif [ "$1" = "wifi" ]; then
    detect_wifi
elif [ "$1" = "ebpf" ]; then
    detect_ebpf
elif [ "$1" = "modem" ]; then
    detect_modem
else
    generate_json
fi

#!/bin/sh
# /usr/bin/condition_detect.sh
# 能力探测模块 - 检测系统硬件能力，输出JSON供LuCI前端和后端使用
# 兼容: qmodem + uqmi 生态 (ImmortalWrt 24.10)

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

# 检测Modem (兼容 qmodem/uqmi/ModemManager)
detect_modem() {
    # 方式1: 检查 uqmi 设备
    for dev in /dev/cdc-wdm0 /dev/cdc-wdm1 /dev/cdc-wdm2; do
        if [ -c "$dev" ]; then
            echo "true"
            return
        fi
    done

    # 方式2: 检查 qmodem 命令
    if command -v qmodem >/dev/null 2>&1; then
        local info=$(qmodem status 2>/dev/null)
        if [ -n "$info" ]; then
            echo "true"
            return
        fi
    fi

    # 方式3: 检查 ModemManager (向后兼容)
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

# 检测CAKE qdisc支持
detect_cake_qdisc() {
    if tc qdisc add dev lo root cake 2>/dev/null; then
        tc qdisc del dev lo root cake 2>/dev/null
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
    local cake_qdisc=$(detect_cake_qdisc)
    local triton=$(detect_triton)

    cat > "$OUTPUT_FILE" << EOF
{
    "wifi_available": $wifi,
    "ebpf_available": $ebpf,
    "modem_available": $modem,
    "cake_autorate_available": $cake,
    "cake_qdisc_available": $cake_qdisc,
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
elif [ "$1" = "cake" ]; then
    detect_cake_qdisc
else
    generate_json
fi

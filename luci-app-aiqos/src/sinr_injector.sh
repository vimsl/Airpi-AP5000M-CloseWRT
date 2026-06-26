#!/bin/sh
# /usr/bin/sinr_injector.sh
# SINR注入守护进程 - 从uqmi/qmodem读取5G信号质量，输出系数供cake-autorate使用
# 启动: /etc/init.d/aiqosd start
# 兼容: qmodem + uqmi 生态 (ImmortalWrt 24.10)

SINR_FILE="/tmp/aiqos_sinr_coeff"
LOG_FILE="/var/log/sinr_injector.log"
INTERVAL=${SINR_INJECTOR_INTERVAL:-2}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 检测 modem 设备路径
detect_modem() {
    for dev in /dev/cdc-wdm0 /dev/cdc-wdm1 /dev/cdc-wdm2; do
        if [ -c "$dev" ]; then
            echo "$dev"
            return 0
        fi
    done
    return 1
}

# 通过 uqmi 获取 SINR
get_sinr_uqmi() {
    local dev=$(detect_modem)
    [ -z "$dev" ] && return 1

    local info=$(uqmi -d "$dev" --get-signal-info 2>/dev/null)
    [ -z "$info" ] && return 1

    # 尝试解析 5G NR SINR
    local sinr=$(echo "$info" | grep -o '"sinr":[0-9.e+-]*' | head -1 | cut -d: -f2)

    # 如果没有 5G，尝试 LTE
    if [ -z "$sinr" ] || [ "$sinr" = "null" ]; then
        sinr=$(echo "$info" | grep -o '"sinr":[0-9.e+-]*' | tail -1 | cut -d: -f2)
    fi

    # 从 RSRP 估算 SINR (备用方案)
    if [ -z "$sinr" ] || [ "$sinr" = "null" ]; then
        local rsrp=$(echo "$info" | grep -o '"rsrp":-*[0-9]*' | head -1 | cut -d: -f2)
        if [ -n "$rsrp" ] && [ "$rsrp" != "null" ]; then
            sinr=$(echo "scale=1; ($rsrp + 140) / 5" | bc 2>/dev/null)
        fi
    fi

    echo "$sinr" | sed 's/[^0-9.-]//g'
}

# 通过 qmodem 获取 SINR (备用)
get_sinr_qmodem() {
    if command -v qmodem >/dev/null 2>&1; then
        local info=$(qmodem signal 2>/dev/null)
        local sinr=$(echo "$info" | grep -i "sinr" | awk '{print $NF}' | sed 's/[^0-9.-]//g')
        echo "$sinr"
    fi
}

# 通过 sysfs 获取信号信息 (最后备用)
get_sinr_sysfs() {
    # 尝试从 /sys/class/net/wwan0 读取
    if [ -f /sys/class/net/wwan0/carrier ]; then
        local rssi=$(cat /sys/class/net/wwan0/rssi 2>/dev/null)
        if [ -n "$rssi" ]; then
            echo "scale=1; ($rssi + 140) / 5" | bc 2>/dev/null
        fi
    fi
}

# 综合获取 SINR
get_sinr() {
    local sinr=$(get_sinr_uqmi)
    if [ -z "$sinr" ] || [ "$sinr" = "null" ]; then
        sinr=$(get_sinr_qmodem)
    fi
    if [ -z "$sinr" ] || [ "$sinr" = "null" ]; then
        sinr=$(get_sinr_sysfs)
    fi
    echo "$sinr"
}

# SINR -> 系数映射 (0.1 ~ 1.0)
sinr_to_coeff() {
    local sinr=$1
    if [ -z "$sinr" ] || [ "$sinr" = "null" ] || [ -z "$(echo "$sinr" | grep -E '^[0-9.+-]+$')" ]; then
        echo "1.0"
        return
    fi

    local sinr_int=$(printf "%.0f" "$sinr" 2>/dev/null)
    [ -z "$sinr_int" ] && { echo "1.0"; return; }

    if [ "$sinr_int" -ge 20 ]; then
        echo "1.0"
    elif [ "$sinr_int" -ge 15 ]; then
        echo "0.8"
    elif [ "$sinr_int" -ge 10 ]; then
        echo "0.6"
    elif [ "$sinr_int" -ge 5 ]; then
        echo "0.4"
    elif [ "$sinr_int" -ge 0 ]; then
        echo "0.2"
    else
        echo "0.1"
    fi
}

# EWMA平滑滤波
ewma_filter() {
    local current=$1
    local alpha=0.3

    local last=""
    if [ -f "$SINR_FILE" ]; then
        last=$(cat "$SINR_FILE" 2>/dev/null | head -1)
    fi

    if [ -z "$last" ] || [ -z "$(echo "$last" | grep -E '^[0-9.]+$')" ]; then
        echo "$current"
        return
    fi

    echo "scale=3; $alpha * $current + (1-$alpha) * $last" | bc 2>/dev/null || echo "$current"
}

main() {
    log "SINR Injector started (interval=${INTERVAL}s, method=uqmi/sysfs)"

    local dev=$(detect_modem)
    if [ -z "$dev" ]; then
        log "WARNING: No modem device found (/dev/cdc-wdm*), will retry..."
    else
        log "Modem device: $dev"
    fi

    local counter=0
    while true; do
        local raw_sinr=$(get_sinr)
        local coeff=$(sinr_to_coeff "$raw_sinr")
        local smoothed=$(ewma_filter "$coeff")
        local timestamp=$(date '+%s')
        echo "$smoothed $raw_sinr $timestamp" > "$SINR_FILE"

        counter=$((counter + 1))
        if [ $((counter % 5)) -eq 0 ]; then
            log "SINR=${raw_sinr}dB -> coeff=${smoothed}"
        fi

        sleep "$INTERVAL"
    done
}

trap 'log "SINR Injector stopped"; exit 0' INT TERM

main

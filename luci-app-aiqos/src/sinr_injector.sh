#!/bin/sh
# /usr/bin/sinr_injector.sh
# SINR注入守护进程 - 从ModemManager读取5G信号质量，输出系数供cake-autorate使用
# 启动: /etc/init.d/aiqosd start

SINR_FILE="/tmp/aiqos_sinr_coeff"
LOG_FILE="/var/log/sinr_injector.log"
INTERVAL=${SINR_INJECTOR_INTERVAL:-2}  # 默认2秒

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 获取SINR值 (通过ModemManager)
get_sinr() {
    local sinr=$(mmcli -m 0 --signal-get 2>/dev/null | \
                 grep -E "^[[:space:]]*5g[0-9]*.*sinr:" | \
                 head -1 | awk '{print $NF}')
    
    if [ -z "$sinr" ] || [ "$sinr" = "--" ]; then
        sinr=$(mmcli -m 0 --signal-get 2>/dev/null | \
               grep -E "^[[:space:]]*lte.*sinr:" | \
               head -1 | awk '{print $NF}')
    fi
    
    if [ -z "$sinr" ] || [ "$sinr" = "--" ]; then
        local rsrp=$(mmcli -m 0 --signal-get 2>/dev/null | \
                     grep -E "rsrp:" | head -1 | awk '{print $NF}')
        if [ -n "$rsrp" ] && [ "$rsrp" != "--" ]; then
            rsrp=$(echo "$rsrp" | sed 's/dBm//')
            sinr=$(echo "scale=1; -($rsrp)/5 + 5" | bc 2>/dev/null)
        fi
    fi
    
    echo "$sinr" | sed 's/[^0-9.-]//g'
}

# SINR -> 系数映射 (0.1 ~ 1.0)
sinr_to_coeff() {
    local sinr=$1
    if [ -z "$sinr" ] || [ "$sinr" = "--" ] || [ -z "$(echo "$sinr" | grep -E '^[0-9.]+$')" ]; then
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
    log "SINR Injector started (interval=${INTERVAL}s)"
    
    if ! pgrep -x "ModemManager" >/dev/null 2>&1; then
        log "WARNING: ModemManager not running, attempting to start..."
        /etc/init.d/modemmanager start 2>/dev/null
        sleep 3
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
            log "SINR=${raw_sinr}dB → coeff=${smoothed}"
        fi
        
        sleep "$INTERVAL"
    done
}

trap 'log "SINR Injector stopped"; exit 0' INT TERM

main

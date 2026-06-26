#!/bin/sh
# /usr/bin/night_lock.sh
# 夜间锁频脚本 - 凌晨扫描并锁定最佳小区
# Cron: 0 3 * * * /usr/bin/night_lock.sh
# 兼容: qmodem/uqmi + ModemManager 向后兼容

LOCK_FILE="/tmp/night_lock.lock"
LOG_FILE="/var/log/night_lock.log"
BACKUP_DIR="/tmp/night_lock_backup"
TIMEOUT=30
MODEM_DEV=""
AT_PORT=""

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    logger -t night_lock "$1"
}

cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

# ====== 检测 modem 和 AT 端口 ======
detect_modem() {
    # 方式1: uqmi 设备
    for dev in /dev/cdc-wdm0 /dev/cdc-wdm1 /dev/cdc-wdm2; do
        if [ -c "$dev" ]; then
            MODEM_DEV="$dev"
            log "Found uqmi device: $dev"
            break
        fi
    done

    # 方式2: AT 串口 (FM170 通常是 ttyUSB2 或 ttyUSB3)
    for port in /dev/ttyUSB2 /dev/ttyUSB3 /dev/ttyUSB0; do
        if [ -c "$port" ]; then
            AT_PORT="$port"
            log "Found AT port: $port"
            break
        fi
    done

    # 方式3: ModemManager fallback
    if [ -z "$MODEM_DEV" ] && pgrep -x "ModemManager" >/dev/null 2>&1; then
        log "Using ModemManager fallback"
        return 0
    fi

    if [ -z "$MODEM_DEV" ] && [ -z "$AT_PORT" ]; then
        log "ERROR: No modem device or AT port found"
        return 1
    fi
    return 0
}

# ====== 发送 AT 命令 ======
send_at() {
    local cmd="$1"
    if [ -n "$AT_PORT" ]; then
        echo -e "${cmd}\r" > "$AT_PORT" 2>/dev/null
        sleep 1
        cat "$AT_PORT" 2>/dev/null | head -5
    elif [ -n "$MODEM_DEV" ]; then
        uqmi -d "$MODEM_DEV" --send-at "$cmd" 2>/dev/null
    elif pgrep -x "ModemManager" >/dev/null 2>&1; then
        mmcli -m 0 --command="$cmd" 2>/dev/null
    fi
}

# ====== 获取信号信息 ======
get_signal() {
    if [ -n "$MODEM_DEV" ]; then
        local info=$(uqmi -d "$MODEM_DEV" --get-signal-info 2>/dev/null)
        local sinr=$(echo "$info" | grep -o '"sinr":[0-9.e+-]*' | head -1 | cut -d: -f2)
        local rsrp=$(echo "$info" | grep -o '"rsrp":-*[0-9]*' | head -1 | cut -d: -f2)
        echo "sinr=${sinr:-0} rsrp=${rsrp:-0}"
    elif pgrep -x "ModemManager" >/dev/null 2>&1; then
        local sinr=$(mmcli -m 0 --signal-get 2>/dev/null | grep -E "sinr:" | head -1 | awk '{print $NF}')
        local rsrp=$(mmcli -m 0 --signal-get 2>/dev/null | grep -E "rsrp:" | head -1 | awk '{print $NF}')
        echo "sinr=${sinr:-0} rsrp=${rsrp:-0}"
    fi
}

# ====== 备份当前配置 ======
backup_current() {
    mkdir -p "$BACKUP_DIR"
    get_signal > "$BACKUP_DIR/signal_before.txt" 2>/dev/null
    send_at "AT+COPS?" > "$BACKUP_DIR/cops_before.txt" 2>/dev/null
    send_at "AT+GTCELLLOCK?" > "$BACKUP_DIR/lock_before.txt" 2>/dev/null
    log "Backup completed"
}

# ====== 扫描最佳小区 ======
scan_cells() {
    log "Scanning cells..."
    local cell_info=$(send_at "AT+GTCCINFO?")

    if [ -z "$cell_info" ] || echo "$cell_info" | grep -q "ERROR"; then
        log "Cell scan failed, using default target"
        echo "312 5078 78"
        return
    fi

    # 解析扫描结果，找到信号最好的小区
    # AT+GTCCINFO? 返回格式: +GTCCINFO: <rat>,<pci>,<freq>,<band>,<rsrp>,<rsrq>,<sinr>
    local best_pci=""
    local best_freq=""
    local best_band=""
    local best_sinr=-999

    echo "$cell_info" | grep "+GTCCINFO:" | while IFS=, read -r rat pci freq band rsrp rsrq sinr; do
        sinr=$(echo "$sinr" | sed 's/[^0-9.-]//g')
        if [ -n "$sinr" ] && [ "$(echo "$sinr > $best_sinr" | bc 2>/dev/null)" = "1" ]; then
            best_sinr="$sinr"
            best_pci="$pci"
            best_freq="$freq"
            best_band="$band"
        fi
    done

    if [ -n "$best_pci" ]; then
        log "Best cell: PCI=$best_pci Freq=$best_freq Band=$best_band SINR=$best_sinr"
        echo "$best_pci $best_freq $best_band"
    else
        log "No valid cell found, using default"
        echo "312 5078 78"
    fi
}

# ====== 锁定小区 ======
lock_cell() {
    local target_pci="$1"
    local target_freq="$2"
    local target_band="$3"

    log "Locking to PCI=${target_pci}, Freq=${target_freq}, Band=${target_band}"

    # 断开数据连接
    send_at "AT+GTRNDIS=0,1"
    sleep 2

    # 执行锁频
    local cmd="AT+GTCELLLOCK=1,1,0,${target_freq},${target_pci},1,${target_band}"
    send_at "$cmd"

    # 重启 modem
    send_at "AT+CFUN=15"
    log "Lock command sent, modem rebooting..."
}

# ====== 看门狗: 30秒内检查网络注册 ======
watchdog() {
    local start_time=$(date +%s)
    local success=0

    log "Watchdog started (timeout=${TIMEOUT}s)"

    while [ $(($(date +%s) - start_time)) -lt "$TIMEOUT" ]; do
        local reg=$(send_at "AT+COPS?")
        if echo "$reg" | grep -q "+COPS: 0,0"; then
            sleep 2
            continue
        fi

        if [ -n "$reg" ] && ! echo "$reg" | grep -q "ERROR"; then
            log "Network registered: $reg"
            success=1
            break
        fi
        sleep 2
    done

    if [ "$success" -eq 0 ]; then
        log "ERROR: Network registration timeout!"
        return 1
    fi

    # 重新拨号
    send_at "AT+GTRNDIS=1,1"
    sleep 3

    # 验证信号
    local signal=$(get_signal)
    log "Signal after lock: $signal"

    return 0
}

# ====== 回滚 ======
rollback() {
    log "ROLLBACK: Restoring previous configuration"

    # 解除锁频
    send_at "AT+GTCELLLOCK=0"
    send_at "AT+GTFREQLOCK=0,0"

    # 重启 modem
    send_at "AT+CFUN=15"
    sleep 8

    # 重新拨号
    send_at "AT+GTRNDIS=1,1"
    sleep 3

    # 验证恢复
    local signal=$(get_signal)
    log "Rollback completed, signal: $signal"
}

# ====== 主流程 ======
main() {
    log "========== Night Lock Started =========="

    if ! detect_modem; then
        log "ERROR: Modem not available, exit"
        exit 1
    fi

    backup_current

    local signal=$(get_signal)
    log "Current signal: $signal"

    # 检查信号是否已经足够好
    local sinr=$(echo "$signal" | grep -o "sinr=[0-9.-]*" | cut -d= -f2)
    sinr=$(echo "$sinr" | sed 's/[^0-9.-]//g')
    local sinr_int=$(printf "%.0f" "$sinr" 2>/dev/null || echo 0)

    if [ "$sinr_int" -gt 15 ]; then
        log "Signal already good (SINR=${sinr}dB), skip locking"
        exit 0
    fi

    # 扫描最佳小区
    local cell_info=$(scan_cells)
    local target_pci=$(echo "$cell_info" | awk '{print $1}')
    local target_freq=$(echo "$cell_info" | awk '{print $2}')
    local target_band=$(echo "$cell_info" | awk '{print $3}')

    lock_cell "$target_pci" "$target_freq" "$target_band"

    if watchdog; then
        log "Night lock SUCCESS: PCI=${target_pci}"
    else
        log "Night lock FAILED: rolling back"
        rollback
    fi

    log "========== Night Lock Finished =========="
}

main

#!/bin/sh
# /usr/bin/night_lock.sh
# 夜间锁频脚本 - 凌晨巡检，锁定信号最优小区
# Cron: 0 3 * * * /usr/bin/night_lock.sh

LOCK_FILE="/tmp/night_lock.lock"
LOG_FILE="/var/log/night_lock.log"
BACKUP_DIR="/tmp/night_lock_backup"
TIMEOUT=15

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

if [ -f "$LOCK_FILE" ]; then
    log "Already running, exit."
    exit 0
fi
echo $$ > "$LOCK_FILE"

# ====== 备份当前配置 ======
backup_current() {
    mkdir -p "$BACKUP_DIR"
    mmcli -m 0 --location-get > "$BACKUP_DIR/current_cell.txt" 2>/dev/null
    mmcli -m 0 --command="AT+GTCELLLOCK?" > "$BACKUP_DIR/current_lock.txt" 2>/dev/null
    log "Backup completed"
}

# ====== 获取当前驻留小区评分 ======
get_current_score() {
    local sinr=$(mmcli -m 0 --signal-get 2>/dev/null | \
                 grep -E "^[[:space:]]*5g.*sinr:" | head -1 | awk '{print $NF}')
    [ -z "$sinr" ] && sinr="0"
    sinr=$(echo "$sinr" | sed 's/dBm//' | sed 's/[^0-9.-]//g')
    printf "%.0f" "$(echo "$sinr * 10" | bc 2>/dev/null || echo 0)"
}

# ====== 扫描并获取最优小区 ======
get_best_cell() {
    local cell_info=$(mmcli -m 0 --command="AT+GTCCINFO?" 2>/dev/null)
    if [ -z "$cell_info" ] || echo "$cell_info" | grep -q "ERROR"; then
        cell_info=$(mmcli -m 0 --location-get 2>/dev/null)
    fi
    echo "$cell_info"
}

# ====== 执行锁频 ======
lock_cell() {
    local target_pci="$1"
    local target_freq="$2"
    local target_band="$3"
    
    log "Locking to PCI=${target_pci}, Freq=${target_freq}, Band=${target_band}"
    
    mmcli -m 0 --command="AT+GTRNDIS=0,1" 2>/dev/null
    sleep 1
    
    local cmd="AT+GTCELLLOCK=1,1,0,${target_freq},${target_pci},1,${target_band}"
    mmcli -m 0 --command="$cmd" 2>/dev/null
    
    mmcli -m 0 --command="AT+CFUN=15" 2>/dev/null
    
    log "Lock command sent, modem rebooting..."
}

# ====== 看门狗: 15秒内检测网络恢复 ======
watchdog() {
    local start_time=$(date +%s)
    local success=0
    
    while [ $(($(date +%s) - start_time)) -lt "$TIMEOUT" ]; do
        local reg=$(mmcli -m 0 --command="AT+COPS?" 2>/dev/null | grep "+COPS")
        if echo "$reg" | grep -q "+COPS: 0,0"; then
            sleep 1
            continue
        fi
        
        if [ -n "$reg" ] && ! echo "$reg" | grep -q "ERROR"; then
            log "Network registered successfully"
            success=1
            break
        fi
        sleep 1
    done
    
    if [ "$success" -eq 0 ]; then
        log "WARNING: Network registration timeout! Rolling back..."
        rollback
        return 1
    fi
    
    mmcli -m 0 --command="AT+GTRNDIS=1,1" 2>/dev/null
    sleep 2
    log "Re-dial completed"
    return 0
}

# ====== 回滚 ======
rollback() {
    log "ROLLBACK: Restoring previous configuration"
    
    mmcli -m 0 --command="AT+GTCELLLOCK=0" 2>/dev/null
    mmcli -m 0 --command="AT+GTFREQLOCK=0,0" 2>/dev/null
    
    mmcli -m 0 --command="AT+CFUN=15" 2>/dev/null
    sleep 5
    
    mmcli -m 0 --command="AT+GTRNDIS=1,1" 2>/dev/null
    
    log "Rollback completed"
}

# ====== 主流程 ======
main() {
    log "========== Night Lock Started =========="
    
    backup_current
    
    local current_score=$(get_current_score)
    log "Current cell score: ${current_score}"
    
    if [ "$current_score" -gt 200 ]; then
        log "Signal already good (score=${current_score}), skip locking"
        rm -f "$LOCK_FILE"
        exit 0
    fi
    
    log "Scanning for better cells..."
    
    # 默认锁定目标: n78 频点5078, PCI=312
    # 实际部署时应从 AT+GTCCINFO? 扫描结果中选择最优
    local target_pci="312"
    local target_freq="5078"
    local target_band="78"
    
    lock_cell "$target_pci" "$target_freq" "$target_band"
    
    if watchdog; then
        log "Night lock SUCCESS: PCI=${target_pci}"
    else
        log "Night lock FAILED: rolled back"
    fi
    
    log "========== Night Lock Finished =========="
    rm -f "$LOCK_FILE"
}

main

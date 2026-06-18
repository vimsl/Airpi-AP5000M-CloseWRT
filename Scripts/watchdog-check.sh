#!/bin/sh
# 系统假死检测守护脚本
# 每30秒检测系统健康状态，连续3次失败则自动重启

LOG_TAG="watchdog"
FAIL_COUNT=0
MAX_FAIL=3
CHECK_INTERVAL=30

log_msg() {
    logger -t "$LOG_TAG" -p daemon.warning "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> /tmp/watchdog.log
}

check_system_health() {
    # 1. 检查 /proc 是否可读（最基本的内核响应）
    cat /proc/uptime >/dev/null 2>&1 || return 1

    # 2. 检查系统负载（5分钟平均负载不应超过CPU核心数*4）
    local load=$(cat /proc/loadavg | awk '{print $1}' | cut -d. -f1)
    local cores=$(grep -c ^processor /proc/cpuinfo)
    local max_load=$((cores * 4))
    [ "$load" -gt "$max_load" ] 2>/dev/null && return 1

    # 3. 检查关键进程是否存活
    pgrep -x procd >/dev/null 2>&1 || return 1
    pgrep -x ubusd >/dev/null 2>&1 || return 1

    # 4. 检查内存是否耗尽（可用内存低于10MB）
    local mem_free=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    [ "$mem_free" -lt 10240 ] 2>/dev/null && return 1

    # 5. 检查网络（ping 网关）
    local gw=$(ip route | grep default | awk '{print $3}' | head -1)
    if [ -n "$gw" ]; then
        ping -c 1 -W 2 "$gw" >/dev/null 2>&1 || return 1
    fi

    # 6. 检查 /tmp 是否可写（文件系统是否正常）
    echo "test" > /tmp/.watchdog_test 2>/dev/null || return 1
    rm -f /tmp/.watchdog_test

    return 0
}

log_msg "Watchdog daemon started (interval=${CHECK_INTERVAL}s, max_fail=${MAX_FAIL})"

# 启动时重启 qmodem 确保数据采集正常
if command -v /etc/init.d/qmodem_init >/dev/null 2>&1; then
    /etc/init.d/qmodem_init restart >/dev/null 2>&1
    log_msg "qmodem_init restarted"
fi

while true; do
    if check_system_health; then
        if [ "$FAIL_COUNT" -gt 0 ]; then
            log_msg "System recovered after $FAIL_COUNT failed checks"
            FAIL_COUNT=0
        fi
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        log_msg "Health check FAILED ($FAIL_COUNT/$MAX_FAIL)"

        if [ "$FAIL_COUNT" -ge "$MAX_FAIL" ]; then
            log_msg "System appears hung! Triggering reboot..."
            sync
            reboot -f
        fi
    fi

    sleep "$CHECK_INTERVAL"
done

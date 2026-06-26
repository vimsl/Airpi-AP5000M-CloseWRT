#!/bin/sh /etc/rc.common
# /etc/init.d/aiqosd
# AIQoS主守护进程 - 管理所有子模块的启动、停止和状态监控

START=90
STOP=10
USE_PROCD=1

NAME=aiqosd

. /lib/functions.sh
. /lib/functions/procd.sh

# ====== 读取UCI配置 ======
get_config() {
    config_load aiqos
    config_get enabled switches enable_cake "1"
    config_get sinr_enabled switches enable_sinr "1"
    config_get wifi_enabled switches enable_wifi "0"
    config_get ack_enabled switches enable_ack "0"
    config_get night_lock_enabled switches enable_night_lock "0"
    config_get ebpf_enabled switches enable_ebpf "0"
    config_get ai_enabled switches enable_ai "0"
    config_get poll_interval advanced poll_interval "2"
    config_get min_bandwidth advanced min_bandwidth "5"
}

# ====== 启动子模块 ======
start_cake_autorate() {
    if [ "$enabled" = "1" ]; then
        if [ -f "/etc/init.d/cake-autorate" ]; then
            logger -t aiqos "Starting cake-autorate"
            /etc/init.d/cake-autorate start 2>/dev/null
        elif command -v cake-autorate.sh >/dev/null 2>&1; then
            logger -t aiqos "Starting cake-autorate (direct)"
            cake-autorate.sh start 2>/dev/null
        else
            logger -t aiqos "WARNING: cake-autorate not found"
        fi
    else
        logger -t aiqos "cake-autorate disabled, stopping"
        /etc/init.d/cake-autorate stop 2>/dev/null
    fi
}

start_sinr_injector() {
    if [ "$sinr_enabled" = "1" ]; then
        if [ -f "/usr/bin/sinr_injector.sh" ]; then
            logger -t aiqos "Starting SINR injector"
            start-stop-daemon -S -b -m -p /var/run/sinr_injector.pid \
                -x /usr/bin/sinr_injector.sh
        else
            logger -t aiqos "WARNING: sinr_injector.sh not found"
        fi
    else
        logger -t aiqos "SINR injector disabled"
        start-stop-daemon -K -p /var/run/sinr_injector.pid 2>/dev/null
    fi
}

start_wifi_optimizer() {
    if [ "$wifi_enabled" = "1" ]; then
        if /usr/bin/condition_detect.sh wifi | grep -q "true"; then
            if [ -f "/usr/bin/TriTon.sh" ]; then
                logger -t aiqos "Starting TriTon WiFi optimizer"
                /usr/bin/TriTon.sh start 2>/dev/null
            elif [ -f "/etc/init.d/triton" ]; then
                logger -t aiqos "Starting TriTon (init.d)"
                /etc/init.d/triton start 2>/dev/null
            else
                logger -t aiqos "WARNING: TriTon not found"
            fi
        else
            logger -t aiqos "WiFi optimizer skipped: no WiFi hardware"
        fi
    else
        logger -t aiqos "WiFi optimizer disabled"
        /usr/bin/TriTon.sh stop 2>/dev/null
        /etc/init.d/triton stop 2>/dev/null
    fi
}

start_ack_optimizer() {
    if [ "$ack_enabled" = "1" ]; then
        logger -t aiqos "Enabling aggressive ACK filter"
        local iface=$(tc qdisc show 2>/dev/null | grep -E "cake.*root" | \
                      awk '{print $5}' | head -1)
        if [ -n "$iface" ]; then
            tc qdisc change dev "$iface" root cake ack-filter aggressive 2>/dev/null
            logger -t aiqos "ACK filter set to aggressive on $iface"
        else
            logger -t aiqos "WARNING: No CAKE interface found"
        fi
    else
        logger -t aiqos "ACK filter disabled (using default)"
        local iface=$(tc qdisc show 2>/dev/null | grep -E "cake.*root" | \
                      awk '{print $5}' | head -1)
        if [ -n "$iface" ]; then
            tc qdisc change dev "$iface" root cake ack-filter 2>/dev/null
        fi
    fi
}

start_night_lock() {
    if [ "$night_lock_enabled" = "1" ]; then
        if ! crontab -l 2>/dev/null | grep -q "night_lock.sh"; then
            logger -t aiqos "Installing night lock cron job"
            (crontab -l 2>/dev/null; echo "0 3 * * * /usr/bin/night_lock.sh") | crontab -
        fi
        logger -t aiqos "Night lock enabled"
    else
        if crontab -l 2>/dev/null | grep -q "night_lock.sh"; then
            logger -t aiqos "Removing night lock cron job"
            crontab -l 2>/dev/null | grep -v "night_lock.sh" | crontab -
        fi
        logger -t aiqos "Night lock disabled"
    fi
}

start_ebpf() {
    if [ "$ebpf_enabled" = "1" ]; then
        if /usr/bin/condition_detect.sh ebpf | grep -q "true"; then
            logger -t aiqos "eBPF support detected, loading programs"
            # [PLACEHOLDER] bpftool prog load /usr/lib/bpf/aiqos_drop.o ...
            logger -t aiqos "eBPF loaded (placeholder - need compiled BPF object)"
        else
            logger -t aiqos "eBPF skipped: kernel not supported"
        fi
    else
        logger -t aiqos "eBPF disabled"
    fi
}

start_ai_predictor() {
    if [ "$ai_enabled" = "1" ]; then
        logger -t aiqos "AI predictor enabled (experimental)"
        # [PLACEHOLDER] python3 /usr/bin/ai_predictor.py &
    else
        logger -t aiqos "AI predictor disabled"
    fi
}

# ====== procd启动函数 ======
start_service() {
    logger -t aiqos "========== AIQoS Starting =========="
    
    # 杀掉所有旧的 aiqosd 实例 (防止进程分裂)
    killall -9 aiqosd.sh 2>/dev/null
    killall -9 sinr_injector.sh 2>/dev/null
    rm -f /var/run/aiqosd.pid
    rm -f /tmp/sinr_injector.lock
    sleep 1
    
    get_config
    
    # 按依赖顺序启动
    start_cake_autorate
    sleep 1
    start_sinr_injector
    start_wifi_optimizer
    start_ack_optimizer
    start_night_lock
    start_ebpf
    start_ai_predictor
    
    echo $$ > /var/run/aiqosd.pid
    
    logger -t aiqos "AIQoS started (PID=$$)"
}

# ====== 停止函数 ======
stop_service() {
    logger -t aiqos "========== AIQoS Stopping =========="
    
    # 杀掉所有 aiqosd 和 sinr_injector 实例
    killall -9 aiqosd.sh 2>/dev/null
    killall -9 sinr_injector.sh 2>/dev/null
    start-stop-daemon -K -p /var/run/sinr_injector.pid 2>/dev/null
    start-stop-daemon -K -p /var/run/aiqosd.pid 2>/dev/null
    
    /etc/init.d/cake-autorate stop 2>/dev/null
    killall cake-autorate.sh 2>/dev/null
    
    /usr/bin/TriTon.sh stop 2>/dev/null
    /etc/init.d/triton stop 2>/dev/null
    
    crontab -l 2>/dev/null | grep -v "night_lock.sh" | crontab - 2>/dev/null
    
    # Restore default CAKE ack-filter
    local iface=$(tc qdisc show 2>/dev/null | grep -E "cake.*root" | \
                  awk '{print $5}' | head -1)
    if [ -n "$iface" ]; then
        tc qdisc change dev "$iface" root cake ack-filter 2>/dev/null
    fi
    
    rm -f /var/run/aiqosd.pid
    rm -f /tmp/sinr_injector.lock
    rm -f /tmp/night_lock.lock
    
    logger -t aiqos "AIQoS stopped"
}

# ====== 重启 ======
reload_service() {
    stop
    sleep 1
    start
}


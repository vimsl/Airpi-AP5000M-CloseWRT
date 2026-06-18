#!/bin/sh /etc/rc.common
# 系统假死检测服务

START=99
STOP=10

USE_PROCD=1

PROG=/usr/bin/watchdog-check.sh

start_service() {
    procd_open_instance
    procd_set_param command "$PROG"
    procd_set_param respawn 3600 5 5
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

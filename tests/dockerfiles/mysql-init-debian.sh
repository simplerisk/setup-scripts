#!/bin/bash
### BEGIN INIT INFO
# Provides:          mysql
# Required-Start:    $local_fs $network
# Required-Stop:     $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: MySQL Community Server
# Description:       MySQL Community Server wrapper for non-systemd containers
### END INIT INFO

PIDFILE=/var/run/mysqld/mysqld.pid
MYSQLD=/usr/sbin/mysqld
HELPERS=/usr/share/mysql-8.4/mysql-helpers

do_start() {
    if [ ! -x "$MYSQLD" ]; then
        echo "mysqld not found at $MYSQLD" >&2
        return 1
    fi
    # Source helpers for verify_ready / verify_database / get_running
    . "$HELPERS"
    verify_ready ""
    verify_database ""
    if [ "$(get_running)" = "1" ]; then
        echo "MySQL is already running"
        return 0
    fi
    mkdir -p /var/run/mysqld && chown mysql:mysql /var/run/mysqld
    su -s /bin/bash mysql -c "$MYSQLD --daemonize --pid-file=$PIDFILE" 2>&1
    # Wait for MySQL to accept connections (up to 30s)
    local i=0
    while [ $i -lt 30 ]; do
        mysqladmin ping --silent >/dev/null 2>&1 && return 0
        sleep 1
        i=$((i+1))
    done
    echo "MySQL did not start within 30 seconds" >&2
    return 1
}

do_stop() {
    if [ -f "$PIDFILE" ]; then
        local pid
        pid=$(cat "$PIDFILE" 2>/dev/null) || return 0
        kill "$pid" 2>/dev/null || true
        local i=0
        while [ -d "/proc/$pid" ] && [ $i -lt 20 ]; do
            sleep 1
            i=$((i+1))
        done
        rm -f "$PIDFILE"
    fi
    return 0
}

do_status() {
    if [ ! -x "$MYSQLD" ]; then
        return 3
    fi
    . "$HELPERS"
    if [ "$(get_running)" = "1" ]; then
        return 0
    else
        return 1
    fi
}

case "$1" in
    start)              do_start ;;
    stop)               do_stop ;;
    restart|force-reload) do_stop; sleep 1; do_start ;;
    status)             do_status ;;
    *)  echo "Usage: $0 {start|stop|restart|force-reload|status}"; exit 1 ;;
esac

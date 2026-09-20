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
#
# Unlike Debian 12/13's mysql-server package, Ubuntu 26.04's ships no
# /usr/share/mysql-8.4/mysql-helpers file, so this doesn't use the
# verify_ready/verify_database/get_running helpers mysql-init-debian.sh relies
# on - it drives mysqld directly instead.

PIDFILE=/var/run/mysqld/mysqld.pid
MYSQLD=/usr/sbin/mysqld

do_start() {
    if [ ! -x "$MYSQLD" ]; then
        echo "mysqld not found at $MYSQLD" >&2
        return 1
    fi
    if mysqladmin ping --silent >/dev/null 2>&1; then
        echo "MySQL is already running"
        return 0
    fi
    mkdir -p /var/run/mysqld && chown mysql:mysql /var/run/mysqld
    # apt's mysql-server postinst already initializes /var/lib/mysql at
    # package-install time (unlike the CentOS/SUSE RPM, which needs an
    # explicit --initialize when systemd never ran it), so this only needs
    # to start the daemon.
    su -s /bin/bash mysql -c "$MYSQLD --daemonize --pid-file=$PIDFILE" 2>&1
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
    mysqladmin ping --silent >/dev/null 2>&1
}

case "$1" in
    start)              do_start ;;
    stop)               do_stop ;;
    restart|force-reload) do_stop; sleep 1; do_start ;;
    status)             do_status ;;
    *)  echo "Usage: $0 {start|stop|restart|force-reload|status}"; exit 1 ;;
esac

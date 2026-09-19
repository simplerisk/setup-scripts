#!/bin/bash
# Minimal systemctl shim — handles the subset used by simplerisk-setup.sh's
# setup_suse()/uninstall_suse() without requiring a running systemd PID 1.
# Mirrors systemctl-shim-centos.sh; see that file for the general approach.

args=()
for arg in "$@"; do
    [[ "$arg" == --* ]] && continue
    args+=("$arg")
done
action="${args[0]:-}"
unit="${args[1]%.service}"

start_mysqld() {
    mysqladmin ping --silent >/dev/null 2>&1 && return 0   # already running
    mkdir -p /var/run/mysqld && chown mysql:mysql /var/run/mysqld 2>/dev/null || true
    # setup_suse() passes /var/log/mysql/mysqld.log to set_up_database(),
    # matching the package's own my.cnf `log-error=` directive - the
    # directory doesn't exist without a live systemd-tmpfiles, so mysqld
    # falls back to logging elsewhere and set_up_database's grep for the
    # startup temp-password line fails ("No such file or directory"),
    # aborting the rest of setup_suse. Pre-create it so mysqld logs where
    # the script actually looks.
    mkdir -p /var/log/mysql && chown mysql:mysql /var/log/mysql 2>/dev/null || true
    touch /var/log/mysql/mysqld.log && chown mysql:mysql /var/log/mysql/mysqld.log 2>/dev/null || true
    # The RPM %post scriptlet may leave /var/lib/mysql in a partial state when
    # systemd is unavailable (auto.cnf + binlog.index but no ibdata1).
    if [ ! -f /var/lib/mysql/ibdata1 ]; then
        rm -f /var/lib/mysql/auto.cnf /var/lib/mysql/binlog.index 2>/dev/null || true
        mysqld --initialize --user=mysql >>/var/log/mysql/mysqld.log 2>&1
    fi
    printf "INSTALL COMPONENT 'file://component_validate_password';\n" > /var/lib/mysql/docker-init.sql
    nohup mysqld --user=mysql --init-file=/var/lib/mysql/docker-init.sql >>/var/log/mysql/mysqld.log 2>&1 &
    local i=0
    while [ $i -lt 60 ]; do
        mysqladmin ping --silent >/dev/null 2>&1 && return 0
        sleep 1; i=$((i+1))
    done
    echo "systemctl shim: mysqld did not start within 60s" >&2; return 1
}

stop_mysqld() {
    local pidfile=/var/run/mysqld/mysqld.pid
    if [ -f "$pidfile" ]; then
        local pid
        pid=$(cat "$pidfile" 2>/dev/null)
        [ -n "$pid" ] && kill -TERM "$pid" 2>/dev/null || true
    else
        pkill -TERM mysqld 2>/dev/null || true
    fi
    local i=0
    while mysqladmin ping --silent >/dev/null 2>&1 && [ $i -lt 30 ]; do
        sleep 1; i=$((i+1))
    done
}

start_apache2() {
    pgrep -x httpd-prefork >/dev/null 2>&1 && return 0
    # openSUSE ships no apache2ctl and no init.d script without a live
    # systemd; /usr/sbin/start_apache2 is the actual launcher, and Apache's
    # own -k start/stop/restart daemon-control flags handle backgrounding
    # and the pidfile without needing systemd.
    /usr/sbin/start_apache2 -k start 2>&1
}

stop_apache2() {
    /usr/sbin/start_apache2 -k stop 2>/dev/null || true
}

start_cron() {
    pgrep cron >/dev/null 2>&1 && return 0
    cron
}

case "$action" in
    start)
        case "$unit" in
            mysql|mysqld) start_mysqld ;;
            apache2)      start_apache2 ;;
            cron)         start_cron ;;
            firewalld)    exit 0 ;;   # no-op: firewalld not available in Docker
            *) echo "systemctl shim: unsupported unit '$unit'" >&2; exit 1 ;;
        esac ;;
    stop)
        case "$unit" in
            mysql|mysqld) stop_mysqld ;;
            apache2)      stop_apache2 ;;
            *) exit 0 ;;   # non-fatal for unknown units on uninstall
        esac ;;
    restart)
        case "$unit" in
            mysql|mysqld) stop_mysqld; sleep 1; start_mysqld ;;
            apache2)      stop_apache2; sleep 1; start_apache2 ;;
            *) echo "systemctl shim: unsupported unit '$unit'" >&2; exit 1 ;;
        esac ;;
    is-active)
        case "$unit" in
            mysql|mysqld) mysqladmin ping --silent >/dev/null 2>&1 ;;
            apache2)      pgrep -x httpd-prefork >/dev/null 2>&1 ;;
            cron)         pgrep cron >/dev/null 2>&1 ;;
            *) exit 1 ;;
        esac ;;
    status)
        case "$unit" in
            mysql|mysqld) mysqladmin ping --silent >/dev/null 2>&1 && echo "active" || exit 3 ;;
            apache2)      pgrep -x httpd-prefork >/dev/null 2>&1 && echo "active" || exit 3 ;;
            *) exit 3 ;;
        esac ;;
    enable|disable|daemon-reload|mask|unmask|is-enabled|reset-failed)
        case "$unit" in
            cron) [ "$action" = "enable" ] && start_cron; exit 0 ;;
            *) exit 0 ;;   # no-op — we don't manage boot-time units
        esac ;;
    *)
        echo "systemctl shim: unknown action '$action'" >&2; exit 1 ;;
esac

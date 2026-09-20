#!/bin/bash
# Minimal systemctl shim — handles the subset used by simplerisk-setup.sh
# on openSUSE Leap without requiring a running systemd PID 1.

now_flag=
args=()
for arg in "$@"; do
    if [[ "$arg" == "--now" ]]; then
        now_flag=1
        continue
    fi
    [[ "$arg" == --* ]] && continue
    args+=("$arg")
done
action="${args[0]:-}"
unit="${args[1]%.service}"

start_mysqld() {
    mysqladmin ping --silent >/dev/null 2>&1 && return 0   # already running
    mkdir -p /var/log/mysql && chown mysql:mysql /var/log/mysql
    # Pre-create the log file with mysql ownership so mysqld (which drops to
    # the mysql user before opening it) can write to it - a bare shell
    # redirect below would otherwise create it root-owned and unwritable.
    touch /var/log/mysql/mysqld.log && chown mysql:mysql /var/log/mysql/mysqld.log
    # mysqld_pre_systemd is the same helper the real mysql.service unit runs
    # as ExecStartPre; it's idempotent (skips init if the datadir is already
    # populated) and internally runs `mysqld --initialize`, which is meant to
    # write the temp root password as a [Note] line to /var/log/mysql/mysqld.log
    # (per log-error in /etc/my.cnf) for simplerisk-setup.sh to read - but on
    # some hosts (observed on GitHub Actions runners, not reproducible in local
    # Docker Desktop testing) that Note only reaches mysqld_pre_systemd's own
    # stdout/stderr, never the file. Redirect explicitly into the log file so
    # the Note lands there regardless, matching the CentOS shim's same
    # defensive redirect around its own `mysqld --initialize` call.
    /usr/bin/mysqld_pre_systemd >>/var/log/mysql/mysqld.log 2>&1
    nohup /usr/sbin/mysqld --user=mysql >>/var/log/mysql/mysqld.log 2>&1 &
    local i=0
    while [ $i -lt 60 ]; do
        mysqladmin ping --silent >/dev/null 2>&1 && return 0
        sleep 1; i=$((i+1))
    done
    echo "systemctl shim: mysqld did not start within 60s" >&2; return 1
}

stop_mysqld() {
    # Send SIGTERM directly to the mysqld process so that no root password is
    # needed (mysqladmin shutdown requires auth after setup changes the password).
    local pidfile=/var/run/mysql/mysqld.pid
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

start_cron() {
    pgrep -x cron >/dev/null 2>&1 && return 0
    nohup /usr/sbin/cron -n >/dev/null 2>&1 &
}

case "$action" in
    start)
        case "$unit" in
            mysql|mysqld) start_mysqld ;;
            apache2)      start_apache2 -k start ;;
            cron)         start_cron ;;
            firewalld)    exit 0 ;;   # no-op: firewalld not available in Docker
            *) echo "systemctl shim: unsupported unit '$unit'" >&2; exit 1 ;;
        esac ;;
    stop)
        case "$unit" in
            mysql|mysqld) stop_mysqld ;;
            apache2)      start_apache2 -k stop ;;
            *) exit 0 ;;   # non-fatal for unknown units on uninstall
        esac ;;
    restart)
        case "$unit" in
            mysql|mysqld) stop_mysqld; sleep 1; start_mysqld ;;
            # `systemctl restart` maps to a real stop+start (ExecStop then
            # ExecStart), not the `-k graceful` rolling reload systemd uses
            # for `systemctl reload` - a graceful reload here reliably
            # segfaults newly-forked children (observed repeatedly in
            # testing), while a full stop/start does not.
            apache2)      start_apache2 -k stop; sleep 1; start_apache2 -k start ;;
            *) echo "systemctl shim: unsupported unit '$unit'" >&2; exit 1 ;;
        esac ;;
    is-active)
        case "$unit" in
            mysql|mysqld) mysqladmin ping --silent >/dev/null 2>&1 ;;
            apache2)      pgrep -x httpd-prefork >/dev/null 2>&1 ;;
            cron)         pgrep -x cron >/dev/null 2>&1 ;;
            *) exit 1 ;;
        esac ;;
    status)
        case "$unit" in
            mysql|mysqld) mysqladmin ping --silent >/dev/null 2>&1 && echo "active" || exit 3 ;;
            apache2)      pgrep -x httpd-prefork >/dev/null 2>&1 && echo "active" || exit 3 ;;
            cron)         pgrep -x cron >/dev/null 2>&1 && echo "active" || exit 3 ;;
            *) exit 3 ;;
        esac ;;
    enable)
        # We don't manage boot-time units, but `enable --now` also means
        # "start it now" on a real system - honor the --now part.
        if [ -n "$now_flag" ]; then
            case "$unit" in
                mysql|mysqld) start_mysqld ;;
                apache2)      start_apache2 -k start ;;
                cron)         start_cron ;;
                *) exit 0 ;;
            esac
        else
            exit 0
        fi ;;
    disable|daemon-reload|mask|unmask|is-enabled|reset-failed)
        exit 0 ;;   # no-op — we don't manage boot-time units
    *)
        echo "systemctl shim: unknown action '$action'" >&2; exit 1 ;;
esac

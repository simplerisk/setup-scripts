#!/bin/bash
# Minimal systemctl shim — handles the subset used by simplerisk-setup.sh
# on CentOS/RHEL without requiring a running systemd PID 1.

# Strip --quiet / --system / other flags; find the action and unit name.
args=()
for arg in "$@"; do
    [[ "$arg" == --* ]] && continue
    args+=("$arg")
done
action="${args[0]:-}"
unit="${args[1]%.service}"   # strip optional .service suffix

start_mysqld() {
    mysqladmin ping --silent >/dev/null 2>&1 && return 0   # already running
    mkdir -p /var/run/mysqld && chown mysql:mysql /var/run/mysqld 2>/dev/null || true
    # Pre-create the error log with mysql ownership so mysqld (running as mysql user)
    # can open it for writing internally in addition to the shell redirect.
    touch /var/log/mysqld.log && chown mysql:mysql /var/log/mysqld.log 2>/dev/null || true
    # The RPM %post scriptlet may leave /var/lib/mysql in a partial state when
    # systemd is unavailable (auto.cnf + binlog.index but no ibdata1).
    # Re-initialize if ibdata1 is missing.
    if [ ! -f /var/lib/mysql/ibdata1 ]; then
        rm -f /var/lib/mysql/auto.cnf /var/lib/mysql/binlog.index 2>/dev/null || true
        # Use --initialize (not --insecure) so a temporary root password is written
        # to /var/log/mysqld.log as a "Note" line for simplerisk-setup.sh to read.
        mysqld --initialize --user=mysql >>/var/log/mysqld.log 2>&1
    fi
    # mysqld_safe and --daemonize were removed in MySQL 8.4; run as background process.
    # Use --init-file to install the validate_password component at startup:
    # the community RPM does not pre-install it when systemd is absent, but
    # simplerisk-setup.sh calls SET GLOBAL validate_password.policy=LOW.
    # Errors in --init-file are non-fatal, so this is safe on subsequent restarts
    # when the component is already installed.
    printf "INSTALL COMPONENT 'file://component_validate_password';\n" > /var/lib/mysql/docker-init.sql
    # Append (>>) so the initialization "Note: temp password" line is preserved.
    nohup mysqld --user=mysql --init-file=/var/lib/mysql/docker-init.sql >>/var/log/mysqld.log 2>&1 &
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
    local pidfile=/var/run/mysqld/mysqld.pid
    if [ -f "$pidfile" ]; then
        local pid
        pid=$(cat "$pidfile" 2>/dev/null)
        [ -n "$pid" ] && kill -TERM "$pid" 2>/dev/null || true
    else
        pkill -TERM mysqld 2>/dev/null || true
    fi
    # Wait for mysqld to fully stop before returning so that the subsequent
    # start_mysqld call does not find MySQL still running and skip the restart.
    local i=0
    while mysqladmin ping --silent >/dev/null 2>&1 && [ $i -lt 30 ]; do
        sleep 1; i=$((i+1))
    done
}

start_httpd() {
    pgrep httpd >/dev/null 2>&1 && return 0
    # The mod_ssl %post scriptlet may skip cert generation without systemd.
    # Generate a self-signed cert if missing so httpd can start.
    if [ ! -f /etc/pki/tls/certs/localhost.crt ]; then
        openssl req -newkey rsa:2048 -nodes \
            -keyout /etc/pki/tls/private/localhost.key \
            -x509 -days 365 \
            -out /etc/pki/tls/certs/localhost.crt \
            -subj '/CN=localhost' 2>/dev/null
    fi
    httpd -k start 2>/dev/null
}

stop_httpd() {
    httpd -k stop 2>/dev/null || true
}

case "$action" in
    start)
        case "$unit" in
            mysqld|mysql) start_mysqld ;;
            httpd)        start_httpd  ;;
            sendmail)     exit 0 ;;   # no-op: sendmail cannot run without systemd
            firewalld)    exit 0 ;;   # no-op: firewalld not available in Docker
            *) echo "systemctl shim: unsupported unit '$unit'" >&2; exit 1 ;;
        esac ;;
    stop)
        case "$unit" in
            mysqld|mysql) stop_mysqld ;;
            httpd)        stop_httpd  ;;
            *) exit 0 ;;   # non-fatal for unknown units on uninstall
        esac ;;
    restart)
        case "$unit" in
            mysqld|mysql) stop_mysqld; sleep 1; start_mysqld ;;
            httpd)        httpd -k restart 2>/dev/null ;;
            *) echo "systemctl shim: unsupported unit '$unit'" >&2; exit 1 ;;
        esac ;;
    is-active)
        case "$unit" in
            mysqld|mysql) mysqladmin ping --silent >/dev/null 2>&1 ;;
            httpd)        pgrep httpd >/dev/null 2>&1 ;;
            *) exit 1 ;;
        esac ;;
    status)
        case "$unit" in
            mysqld|mysql) mysqladmin ping --silent >/dev/null 2>&1 && echo "active" || exit 3 ;;
            httpd)        pgrep httpd >/dev/null 2>&1 && echo "active" || exit 3 ;;
            *) exit 3 ;;
        esac ;;
    enable|disable|daemon-reload|mask|unmask|is-enabled|reset-failed)
        exit 0 ;;   # no-op — we don't manage boot-time units
    *)
        echo "systemctl shim: unknown action '$action'" >&2; exit 1 ;;
esac

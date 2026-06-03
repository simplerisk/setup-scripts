#!/usr/bin/env bash
# verify-install.sh — Run inside a container after simplerisk-setup.sh --yes
# to assert that the installation completed correctly.
# Exits 0 if all checks pass, 1 if any check fails.

set -uo pipefail

PASS=0
FAIL=0
ERRORS=()

# check <description> <cmd> [args...]
# Runs the command silently; records pass/fail without aborting on failure.
check() {
    local description="$1"
    shift
    local result=0
    "$@" > /dev/null 2>&1 || result=$?
    if [ "$result" -eq 0 ]; then
        echo "  PASS: $description"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $description"
        ERRORS+=("$description")
        FAIL=$((FAIL + 1))
    fi
}

echo "=== SimpleRisk Install Verification ==="
echo ""

# ── File system ──────────────────────────────────────────────────────────────
echo "--- File system ---"
check "SimpleRisk directory exists"                  test -d /var/www/simplerisk
check "index.php exists"                             test -f /var/www/simplerisk/index.php
check "config.php exists"                            test -f /var/www/simplerisk/includes/config.php
check "database.sql was removed post-install"        test ! -f /var/www/simplerisk/database.sql
check "cron script exists"                           test -f /var/www/simplerisk/cron/cron.php

# ── config.php content ───────────────────────────────────────────────────────
echo "--- config.php ---"
# Newer SimpleRisk ships config.sample.php (a template of __PLACEHOLDER__
# tokens) and treats the existence of config.php as the install marker, so
# there is no longer a SIMPLERISK_INSTALLED flag. Verify the installer
# substituted the placeholders instead.
check "config.php placeholders were substituted" \
    bash -c "! grep -qE \"define[(][^)]*__[A-Z_]+__\" /var/www/simplerisk/includes/config.php"
check "DB_PASSWORD is populated (not placeholder or default)" \
    bash -c "! grep -qE \"DB_PASSWORD', '(__DB_PASSWORD__|simplerisk)'\" /var/www/simplerisk/includes/config.php"

# ── Passwords file ───────────────────────────────────────────────────────────
echo "--- /root/passwords.txt ---"
check "passwords.txt exists"                         test -f /root/passwords.txt
check "passwords.txt has mode 600" \
    bash -c '[ "$(stat -c %a /root/passwords.txt)" = "600" ]'
check "passwords.txt contains MySQL root password entry" \
    grep -q "MYSQL ROOT PASSWORD:" /root/passwords.txt
check "passwords.txt contains MySQL simplerisk password entry" \
    grep -q "MYSQL SIMPLERISK PASSWORD:" /root/passwords.txt

MYSQL_ROOT_PW=$(grep "MYSQL ROOT PASSWORD:" /root/passwords.txt 2>/dev/null | awk -F ': ' '{print $2}')
MYSQL_SR_PW=$(grep "MYSQL SIMPLERISK PASSWORD:" /root/passwords.txt 2>/dev/null | awk -F ': ' '{print $2}')

check "MySQL root password is non-empty"             test -n "${MYSQL_ROOT_PW:-}"
check "MySQL simplerisk password is non-empty"       test -n "${MYSQL_SR_PW:-}"

# ── MySQL ────────────────────────────────────────────────────────────────────
echo "--- MySQL ---"
check "MySQL is reachable with root password" \
    mysql -uroot --password="${MYSQL_ROOT_PW:-}" -e "SELECT 1;"
check "simplerisk database exists" \
    bash -c "mysql -uroot --password='${MYSQL_ROOT_PW:-}' -e 'SHOW DATABASES;' 2>/dev/null | grep -q simplerisk"
check "simplerisk user can connect" \
    mysql -usimplerisk --password="${MYSQL_SR_PW:-}" simplerisk -e "SELECT 1;"
check "sql_mode does not contain STRICT_TRANS_TABLES" \
    bash -c "! mysql -uroot --password='${MYSQL_ROOT_PW:-}' -e 'SELECT @@sql_mode;' 2>/dev/null | grep -q STRICT_TRANS_TABLES"

# ── Cron job ─────────────────────────────────────────────────────────────────
echo "--- Cron ---"
check "Backup cron job is in root's crontab" \
    bash -c "crontab -l 2>/dev/null | grep -q 'simplerisk/cron/cron.php'"

# ── PHP ──────────────────────────────────────────────────────────────────────
echo "--- PHP ---"
check "PHP CLI is functional"                        php -r "echo 'OK';"
check "PHP version is 8.x"                           bash -c "php --version | grep -qE '^PHP 8\.'"

for ext in mysqli mbstring xml curl gd zip intl ldap; do
    check "PHP extension '$ext' is loaded"           php -m | grep -qi "$ext"
done

# ── Web server (OS-conditional) ───────────────────────────────────────────────
echo "--- Web server ---"
if command -v apache2 > /dev/null 2>&1; then
    # Debian/Ubuntu
    # apache2 -t requires env vars (APACHE_RUN_DIR etc.) that are only set by
    # apache2ctl.  Use apache2ctl -t so the environment is populated correctly.
    check "Apache config syntax is valid"            bash -c "apache2ctl -t 2>&1 | grep -q 'Syntax OK'"
    check "Apache service is running"                service apache2 status
    check "MySQL service is running"                 bash -c "service mysql status 2>/dev/null || service mysqld status 2>/dev/null"
elif command -v httpd > /dev/null 2>&1; then
    # CentOS/RHEL
    check "Apache config syntax is valid"            bash -c "httpd -t 2>&1 | grep -q 'Syntax OK'"
    check "httpd service is running (systemctl)"     systemctl is-active --quiet httpd
    check "mysqld service is running (systemctl)"    systemctl is-active --quiet mysqld
fi

# ── HTTP reachability ────────────────────────────────────────────────────────
echo "--- HTTP ---"
check "HTTP on port 80 returns a redirect or 200" \
    bash -c "curl -sk -o /dev/null -w '%{http_code}' http://localhost/ | grep -qE '^(200|301|302)$'"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "=== Verification Summary ==="
echo "  Passed : $PASS"
echo "  Failed : $FAIL"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "  Failed checks:"
    for err in "${ERRORS[@]}"; do
        echo "    - $err"
    done
    exit 1
fi

echo "  All checks passed."
exit 0

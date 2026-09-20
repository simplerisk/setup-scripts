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
# The backup cron runs as the web-server account (not root): cron/cron.php is
# owned and writable by that account, so running it as root would let anyone
# who can write that file escalate to root every minute. See HackerOne #3761952.
echo "--- Cron ---"
if grep -qiE "ubuntu|debian" /etc/os-release 2>/dev/null; then
    WEB_USER=www-data
elif grep -qiE "centos|red hat|rocky|alma" /etc/os-release 2>/dev/null; then
    WEB_USER=apache
elif grep -qiE "suse" /etc/os-release 2>/dev/null; then
    WEB_USER=wwwrun
else
    WEB_USER=""
fi

check "cron.d entry for the SimpleRisk backup exists" test -f /etc/cron.d/simplerisk
check "Backup cron entry runs as the web-server account ('$WEB_USER')" \
    bash -c "grep -qE '^\* \* \* \* \* ${WEB_USER} ' /etc/cron.d/simplerisk"
check "Backup cron entry does not run as root" \
    bash -c "! grep -qE '^\* \* \* \* \* root ' /etc/cron.d/simplerisk"
check "Backup cron job is not in root's crontab" \
    bash -c "! (crontab -l 2>/dev/null | grep -q 'simplerisk/cron/cron.php')"
# Waiting for an actual tick (rather than checking the daemon/script/config
# are in place) proved unreliable on some CI backends for reasons unrelated
# to the setup script itself - e.g. a container's PAM/audit stack rejecting
# crond's non-root job user outright regardless of nsswitch.conf. Verifying
# the daemon is actually running is what those attempts were missing; script
# presence and cron.d wiring are already covered above.
check "Cron daemon is running" \
    bash -c "pgrep -x crond >/dev/null 2>&1 || pgrep -x cron >/dev/null 2>&1"

# ── PHP ──────────────────────────────────────────────────────────────────────
echo "--- PHP ---"
check "PHP CLI is functional"                        php -r "echo 'OK';"
check "PHP version is 8.x"                           bash -c "php --version | grep -qE '^PHP 8\.'"

for ext in mysqli mbstring xml curl gd zip intl ldap; do
    check "PHP extension '$ext' is loaded"           bash -c "php -m | grep -qi '$ext'"
done

# ── Web server (OS-conditional) ───────────────────────────────────────────────
echo "--- Web server ---"
if grep -qi suse /etc/os-release 2>/dev/null; then
    # openSUSE/SLES: apache2-prefork's own /usr/sbin/httpd compatibility
    # symlink means `command -v httpd` below would otherwise misdetect this
    # as CentOS/RHEL, so this branch must be checked first. The real binary
    # is httpd-prefork/httpd-worker, started via /usr/sbin/start_apache2
    # (there is no apache2ctl and no init.d script without a live systemd).
    check "Apache config syntax is valid"            bash -c "/usr/sbin/start_apache2 -t 2>&1 | grep -q 'Syntax OK'"
    check "Apache service is running"                pgrep -x httpd-prefork > /dev/null
    check "MySQL service is running"                 mysqladmin ping --silent
elif command -v apache2 > /dev/null 2>&1; then
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
# A bare 200/301/302 only proves *something* answered on port 80 - it would
# also pass for a PHP fatal-error page, a blank page, or Apache's own default
# page. Follow the http->https redirect and grep the actual response body.
#
# A brand-new database has zero rows in `user`, so index.php's own gate
# (`if ($count == 0) { create_default_admin_account(); exit(); }`) shows the
# "Default Admin Account Creation" wizard and returns *before* the login form
# ever renders - that page, not the login screen, is the correct thing to see
# after a fresh install. verify_create_default_admin_account is that page's
# submit button name, a literal HTML attribute (not a translatable string).
echo "--- HTTP ---"
check "HTTP request reaches the app (following any http->https redirect)" \
    bash -c "test \"\$(curl -sk -o /dev/null -w '%{http_code}' -L http://localhost/)\" = 200"
check "SimpleRisk's default-admin-account page is actually rendered (not an error/default page)" \
    bash -c "curl -sk -L http://localhost/ | grep -q 'name=\"verify_create_default_admin_account\"'"

# ── End-to-end: create the admin account, log in, check the health page ───────
# Drives the real first-run flow with plain curl (no browser/JS dependency -
# every step here is a server-side form POST) rather than just probing
# individual endpoints, so a break anywhere in that chain - account creation,
# login, or the app's own self-reported health - fails the build.
#
# This must be curl's/this script's *first* interaction with the app on this
# container: SimpleRisk's simplerisk_base_url setting is written once, from
# whichever host/port the very first request used, and is never recomputed
# after that (get_base_url() checks the stored setting before ever looking at
# the live request again). Since every check in this script - including the
# ones above - already goes through the container's real internal address via
# `docker exec ... curl https://localhost/...` with no host port published,
# that's consistent for the whole run and this doesn't get a chance to drift.
echo "--- End-to-end (create admin account -> log in -> health check) ---"

E2E_DIR=$(mktemp -d)
E2E_COOKIES="$E2E_DIR/cookies.txt"
E2E_USER="ci-admin"
E2E_PASS="CI-Test-Passw0rd!"
E2E_EMAIL="ci-admin@example.com"

curl -sk -c "$E2E_COOKIES" -b "$E2E_COOKIES" https://localhost/ -o "$E2E_DIR/00-fresh.html"

curl -sk -c "$E2E_COOKIES" -b "$E2E_COOKIES" -L https://localhost/ \
    --data-urlencode "username=${E2E_USER}" \
    --data-urlencode "full_name=CI Admin" \
    --data-urlencode "email=${E2E_EMAIL}" \
    --data-urlencode "password=${E2E_PASS}" \
    --data-urlencode "confirm_password=${E2E_PASS}" \
    -d "verify_create_default_admin_account=CREATE" \
    -o "$E2E_DIR/01-post-create.html"
check "Default admin account was created (login page now shown)" \
    grep -q 'name="authenticate"' "$E2E_DIR/01-post-create.html"

E2E_CSRF=$(grep -oE 'name="csrf_token" value="[a-f0-9]+"' "$E2E_DIR/01-post-create.html" | grep -oE '[a-f0-9]{20,}')

curl -sk -c "$E2E_COOKIES" -b "$E2E_COOKIES" -L https://localhost/ \
    -d "csrf_token=${E2E_CSRF}" \
    --data-urlencode "user=${E2E_USER}" \
    --data-urlencode "pass=${E2E_PASS}" \
    -d "submit=submit" \
    -o "$E2E_DIR/02-post-login.html"
check "Logged in as the newly-created admin account" \
    grep -qi 'logout' "$E2E_DIR/02-post-login.html"

curl -sk -c "$E2E_COOKIES" -b "$E2E_COOKIES" https://localhost/admin/health_check.php \
    -o "$E2E_DIR/03-health-check.html" -w '%{http_code}' > "$E2E_DIR/03-health-check.code"
E2E_HEALTH_CODE=$(cat "$E2E_DIR/03-health-check.code")
check "Health check page loads (HTTP 200)" \
    test "${E2E_HEALTH_CODE}" = "200"
check "Health check: base URL matches the URL used to connect" \
    grep -q 'Base URL matches the URL you are using to connect to SimpleRisk' "$E2E_DIR/03-health-check.html"
check "Health check: communicated with the SimpleRisk API" \
    grep -q 'Communicated with the SimpleRisk API successfully' "$E2E_DIR/03-health-check.html"
# Two specific leaf checks can never pass in this environment, and their
# failure also flips two summary rollup rows to bad - none of this reflects
# a script or app defect:
#   - "a DNS lookup was not successful": check_simplerisk_base_url_dns()
#     calls dns_get_record() against SERVER_NAME ("localhost" here), which
#     can never resolve via real DNS - only /etc/hosts would, and
#     dns_get_record() doesn't consult it. This would be false on any real
#     deployment tested via http://localhost/ too, before a real domain is
#     configured.
#   - "hasn't run in the past hour": check_cron_configured() only reports
#     healthy if cron ticked within the last 3600s. This script verifies
#     cron is installed, configured, and running instead (see the Cron
#     section above) rather than waiting up to an hour for a real tick.
#   - "SimpleRisk Core" and "Connectivity" are summary rollups that go bad
#     whenever any check in their group fails, including the two above.
#     They're excluded here only alongside their known-bad members - their
#     other sibling checks (app/db version, session handling, data
#     integrity, base URL match, API/database/web connectivity) are all
#     still verified above/below and would surface their own distinct
#     failure text here if something else broke.
KNOWN_ENVIRONMENT_LIMITATIONS="$E2E_DIR/known-environment-limitations.txt"
cat > "$KNOWN_ENVIRONMENT_LIMITATIONS" <<'EOF'
SimpleRisk Core
Connectivity
The detected server name is a valid domain, but a DNS lookup was not successful.
The automation cron hasn&#039;t run in the past hour. Check the &#039;Backups&#039; tab under Configure-&gt; Settings to learn more.
EOF

E2E_HEALTH_FAILURES=$(grep -oE 'x-mark-5-16[^&]*&nbsp;&nbsp;[^<]*' "$E2E_DIR/03-health-check.html" | sed -E 's/^.*&nbsp;&nbsp;//')
if [ -n "$E2E_HEALTH_FAILURES" ]; then
    echo "  --- health check page has failing item(s) ---"
    echo "$E2E_HEALTH_FAILURES" | sed 's/^/    - /'
    echo "  --- end health check failures ---"
    E2E_UNEXPECTED_FAILURES=$(echo "$E2E_HEALTH_FAILURES" | grep -vxFf "$KNOWN_ENVIRONMENT_LIMITATIONS" || true)
else
    E2E_UNEXPECTED_FAILURES=""
fi
check "Health check: no unexpected failures (excluding known environment limitations above)" \
    test -z "$E2E_UNEXPECTED_FAILURES"

rm -rf "$E2E_DIR"

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

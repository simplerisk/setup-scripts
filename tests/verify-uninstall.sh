#!/usr/bin/env bash
# verify-uninstall.sh — Run inside a container after simplerisk-setup.sh --uninstall --yes
# to assert that all SimpleRisk components were cleanly removed.
# Exits 0 if all checks pass, 1 if any check fails.

set -uo pipefail

PASS=0
FAIL=0
ERRORS=()

# check <description> <cmd> [args...]
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

echo "=== SimpleRisk Uninstall Verification ==="
echo ""

# ── File system ──────────────────────────────────────────────────────────────
echo "--- File system ---"
check "SimpleRisk directory was removed"             test ! -d /var/www/simplerisk
check "passwords.txt was removed"                   test ! -f /root/passwords.txt

# ── Cron job ─────────────────────────────────────────────────────────────────
echo "--- Cron ---"
check "Backup cron job was removed from root's crontab" \
    bash -c "! crontab -l 2>/dev/null | grep -q 'simplerisk/cron/cron.php'"

# ── MySQL database ───────────────────────────────────────────────────────────
echo "--- MySQL database ---"
if command -v mysql > /dev/null 2>&1; then
    # MySQL client still installed (partially removed or not purged) — attempt
    # socket auth as root and verify the database is gone.
    check "simplerisk database was dropped" \
        bash -c "! mysql -uroot 2>/dev/null -e 'USE simplerisk;'"
    check "simplerisk MySQL user was dropped" \
        bash -c "! mysql -uroot 2>/dev/null -e \"SELECT User FROM mysql.user WHERE User='simplerisk';\" | grep -q simplerisk"
else
    echo "  PASS: mysql client not present (packages removed)"
    PASS=$((PASS + 1))
fi

# ── OS-specific package and config checks ────────────────────────────────────
if grep -qi ubuntu /etc/os-release 2>/dev/null || grep -qi debian /etc/os-release 2>/dev/null; then

    echo "--- Packages (Debian/Ubuntu) ---"
    check "apache2 package is removed" \
        bash -c "! dpkg -l apache2 2>/dev/null | grep -q '^ii'"
    check "mysql-server package is removed" \
        bash -c "! dpkg -l mysql-server 2>/dev/null | grep -q '^ii'"
    check "PHP packages are removed" \
        bash -c "! dpkg -l 'php*' 2>/dev/null | grep -qE '^ii.*php[0-9]'"
    check "sendmail package is removed" \
        bash -c "! dpkg -l sendmail 2>/dev/null | grep -q '^ii'"

    if grep -qi debian /etc/os-release 2>/dev/null; then
        echo "--- Repositories (Debian) ---"
        check "sury-php.list was removed" \
            test ! -f /etc/apt/sources.list.d/sury-php.list
        check "mysql.list was removed" \
            test ! -f /etc/apt/sources.list.d/mysql.list
        check "sury-php GPG key was removed" \
            test ! -f /etc/apt/keyrings/sury-php.gpg
        check "MySQL GPG key was removed" \
            test ! -f /etc/apt/trusted.gpg.d/mysql.gpg
    fi

elif grep -qi "centos\|red hat" /etc/os-release 2>/dev/null; then

    echo "--- Packages (CentOS/RHEL) ---"
    check "httpd package is removed" \
        bash -c "! rpm -q httpd"
    check "mysql-community-server package is removed" \
        bash -c "! rpm -q mysql-community-server"
    check "PHP packages are removed" \
        bash -c "! rpm -qa 'php*' | grep -q ."

    echo "--- Services (CentOS/RHEL) ---"
    check "httpd service is not active" \
        bash -c "! systemctl is-active --quiet httpd 2>/dev/null"
    check "mysqld service is not active" \
        bash -c "! systemctl is-active --quiet mysqld 2>/dev/null"

    echo "--- Config files (CentOS/RHEL) ---"
    check "simplerisk Apache vhost config was removed" \
        test ! -f /etc/httpd/sites-enabled/simplerisk.conf

fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "=== Uninstall Verification Summary ==="
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

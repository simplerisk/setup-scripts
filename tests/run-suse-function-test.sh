#!/usr/bin/env bash
# run-suse-function-test.sh — drives setup_suse()/uninstall_suse() directly.
#
# The full `setup()` entry point can't be exercised against a plain openSUSE
# Leap container: validate_os_and_version() requires /etc/os-release to say
# NAME=SLES exactly, and its SLES branch calls `suseconnect --list-extensions`
# to verify a licensed PHP module — both of which need a real, registered SUSE
# subscription that a public CI container doesn't have. This script instead
# sources the real, unmodified simplerisk-setup.sh (stripping only the
# trailing auto-invocation) and calls the install/uninstall functions
# directly, so the actual apache2/mysql/php8/cron logic in setup_suse() and
# uninstall_suse() still gets exercised for real on every change.
set -euo pipefail

SCRIPT=/root/simplerisk-setup.sh
ACTION="${1:?usage: run-suse-function-test.sh install|uninstall}"

# Strip the trailing `setup "${@:1}"` auto-invocation so sourcing the file
# only defines functions/readonly vars, matching the technique used to
# reproduce HackerOne #3761952.
LAST_LINE=$(grep -Fn 'setup "${@:1}"' "$SCRIPT" | tail -1 | cut -d: -f1)
head -n "$((LAST_LINE - 1))" "$SCRIPT" > /tmp/sr-functions.sh
# shellcheck disable=SC1091
source /tmp/sr-functions.sh

case "$ACTION" in
	install)
		DEBUG=y
		# setup_suse() references ${VER} (e.g. to gate PHP/rewrite module
		# enabling and the "SLES 15 has no sendmail" notice) which is
		# normally set by load_os_variables() from /etc/os-release -
		# bypassed here along with the rest of setup(). Match a real SLES
		# 15 SP's VERSION_ID format.
		VER="15.6"
		setup_suse "$(get_current_simplerisk_version)"
		;;
	uninstall)
		DEBUG=y
		uninstall_suse
		;;
	*)
		echo "unknown action: $ACTION" >&2
		exit 1
		;;
esac

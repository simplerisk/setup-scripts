#!/usr/bin/env bash
# run-tests.sh — Local test orchestrator for simplerisk-setup.sh
#
# Usage:
#   ./tests/run-tests.sh                   # Run all OSes
#   ./tests/run-tests.sh ubuntu-22.04      # Run a single OS
#
# Available OS slugs:
#   ubuntu-22.04  ubuntu-24.04
#   debian-12     debian-13
#   centos-stream-9  centos-stream-10
#
# Requirements:
#   - Docker must be installed and running
#   - Outbound internet access (the setup script downloads packages from the web)

set -euo pipefail

# On Windows/Git Bash, paths like /bin/bash and /root/... that are meant to
# be resolved *inside* the container get incorrectly converted to Windows paths
# by Git Bash before Docker sees them. Wrapping docker run/exec/cp calls with
# this function suppresses that conversion for those specific invocations.
# docker build still runs without it so that host build-context paths resolve correctly.
docker_nc() { MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" docker "$@"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_BASE="$SCRIPT_DIR/logs"

# All supported test targets
ALL_OS_SLUGS=(
    ubuntu-22.04
    ubuntu-24.04
    debian-12
    debian-13
    centos-stream-9
    centos-stream-10
)

# ── Helpers ───────────────────────────────────────────────────────────────────
log()  { echo "[$(date '+%H:%M:%S')] $*"; }
info() { echo ""; log ">>> $*"; echo ""; }
pass() { echo ""; echo "  ✔  $*"; echo ""; }
fail() { echo ""; echo "  ✘  $*"; echo ""; }

uses_systemd() {
    local slug="$1"
    # Docker Desktop for Windows does not expose a real cgroup hierarchy to
    # containers, so systemd (which needs cgroup v2 or legacy v1 mounts) cannot
    # start as PID 1 in any of our test containers.  All OSes use the non-systemd
    # path: --init + tail -f /dev/null, with service wrappers baked into each
    # Dockerfile (an /etc/init.d/mysql script for Debian, a /usr/bin/systemctl
    # shim for CentOS/RHEL).
    # Keep this function in case a future CI environment re-enables systemd.
    false
}

# ── Single OS test ─────────────────────────────────────────────────────────────
run_test() {
    local OS_SLUG="$1"
    local DOCKERFILE="$SCRIPT_DIR/dockerfiles/Dockerfile.${OS_SLUG}"
    local IMAGE_NAME="simplerisk-test:${OS_SLUG}"
    local CONTAINER_NAME="simplerisk-test-${OS_SLUG//./-}"
    local LOG_DIR="$LOG_BASE/${OS_SLUG}"

    if [ ! -f "$DOCKERFILE" ]; then
        echo "ERROR: Dockerfile not found: $DOCKERFILE"
        return 1
    fi

    mkdir -p "$LOG_DIR"

    # Remove any leftover container from a previous failed run.
    docker_nc rm -f "$CONTAINER_NAME" > /dev/null 2>&1 || true

    # Always clean up the container on exit, even on error.
    # Guard against CONTAINER_NAME being unset if docker run fails early.
    cleanup() {
        if [ -n "${CONTAINER_NAME:-}" ]; then
            log "Teardown: removing container $CONTAINER_NAME"
            docker_nc rm -f "$CONTAINER_NAME" > /dev/null 2>&1 || true
        fi
    }
    trap cleanup EXIT

    echo "=========================================="
    echo " SimpleRisk Test: $OS_SLUG"
    echo "=========================================="

    # ── Step 1: Build ────────────────────────────────────────────────────────
    info "Step 1/7 — Building image: $IMAGE_NAME"
    docker build \
        -f "$DOCKERFILE" \
        -t "$IMAGE_NAME" \
        "$SCRIPT_DIR/dockerfiles" \
        2>&1 | tee "$LOG_DIR/build.log"

    # ── Step 2: Start container ──────────────────────────────────────────────
    info "Step 2/7 — Starting container: $CONTAINER_NAME"

    if uses_systemd "$OS_SLUG"; then
        # CentOS/RHEL: systemd must be PID 1.
        # --privileged is sufficient on Docker Desktop (Windows/Mac) and on
        # Linux CI runners; the cgroup hierarchy is managed by the host VM.
        docker_nc run -d \
            --name "$CONTAINER_NAME" \
            --privileged \
            --cgroupns=host \
            --tmpfs /run \
            --tmpfs /run/lock \
            "$IMAGE_NAME" \
            2>&1 | tee "$LOG_DIR/start.log"

        log "Waiting for systemd multi-user.target..."
        local attempts=0
        until docker_nc exec "$CONTAINER_NAME" \
                systemctl is-active --quiet multi-user.target 2>/dev/null; do
            sleep 3
            attempts=$((attempts + 1))
            if [ "$attempts" -ge 30 ]; then
                echo "ERROR: systemd did not reach multi-user.target within 90s"
                docker_nc exec "$CONTAINER_NAME" journalctl -n 50 2>/dev/null || true
                return 1
            fi
        done
        log "systemd ready."
    else
        # Ubuntu/Debian: no systemd needed.
        # --privileged is required for ufw/iptables inside the container.
        # --init uses Docker's built-in tini as PID 1 so that child processes
        # (Apache workers, etc.) are properly reaped and do not accumulate as
        # zombies across the many service start/stop/restart calls the script makes.
        docker_nc run -d \
            --name "$CONTAINER_NAME" \
            --privileged \
            --init \
            "$IMAGE_NAME" \
            /bin/bash -c "tail -f /dev/null" \
            2>&1 | tee "$LOG_DIR/start.log"
        sleep 1

        # Ubuntu: lamp-server^ was pre-installed in the Dockerfile (with service
        # starts denied via policy-rc.d) to speed up test runs.  On a real host
        # the post-install scripts would leave MySQL and Apache running; replicate
        # that state here so the setup script finds services in the expected state.
        # Debian: packages are NOT pre-installed; these start calls will fail fast
        # and harmlessly (|| true) — the setup script installs and starts everything.
        log "Starting pre-installed services (mysql, apache2) if present..."
        docker_nc exec "$CONTAINER_NAME" service mysql start  2>&1 | tee -a "$LOG_DIR/start.log" || true
        docker_nc exec "$CONTAINER_NAME" service apache2 start 2>&1 | tee -a "$LOG_DIR/start.log" || true
    fi

    # ── Step 3: Copy files into container ────────────────────────────────────
    # Use plain `docker cp` here: Git Bash correctly converts the host source
    # path, and does not mangle `container:/dest` arguments (the colon guards it).
    info "Step 3/7 — Copying scripts into container"
    docker cp "$REPO_ROOT/simplerisk-setup.sh"    "$CONTAINER_NAME:/root/simplerisk-setup.sh"
    docker cp "$SCRIPT_DIR/verify-install.sh"     "$CONTAINER_NAME:/root/verify-install.sh"
    docker cp "$SCRIPT_DIR/verify-uninstall.sh"   "$CONTAINER_NAME:/root/verify-uninstall.sh"
    # Strip Windows CRLF line endings that Git on Windows may have introduced,
    # then make the scripts executable.
    docker_nc exec "$CONTAINER_NAME" \
        sed -i 's/\r//' /root/simplerisk-setup.sh /root/verify-install.sh /root/verify-uninstall.sh
    docker_nc exec "$CONTAINER_NAME" chmod +x \
        /root/simplerisk-setup.sh \
        /root/verify-install.sh \
        /root/verify-uninstall.sh

    # ── Step 4: Install ──────────────────────────────────────────────────────
    info "Step 4/7 — Running install (--yes --debug)"
    if ! docker_nc exec "$CONTAINER_NAME" \
            bash /root/simplerisk-setup.sh --yes --debug \
            2>&1 | tee "$LOG_DIR/install.log"; then
        echo "ERROR: Install script failed. See $LOG_DIR/install.log"
        return 1
    fi

    # ── Step 5: Verify install ───────────────────────────────────────────────
    info "Step 5/7 — Verifying installation"
    if ! docker_nc exec "$CONTAINER_NAME" \
            bash /root/verify-install.sh \
            2>&1 | tee "$LOG_DIR/verify-install.log"; then
        echo "ERROR: Install verification failed. See $LOG_DIR/verify-install.log"
        return 1
    fi

    # ── Step 6: Uninstall ────────────────────────────────────────────────────
    info "Step 6/7 — Running uninstall (--uninstall --yes --debug)"
    if ! docker_nc exec "$CONTAINER_NAME" \
            bash /root/simplerisk-setup.sh --uninstall --yes --debug \
            2>&1 | tee "$LOG_DIR/uninstall.log"; then
        echo "ERROR: Uninstall script failed. See $LOG_DIR/uninstall.log"
        return 1
    fi

    # ── Step 7: Verify uninstall ─────────────────────────────────────────────
    info "Step 7/7 — Verifying uninstallation"
    if ! docker_nc exec "$CONTAINER_NAME" \
            bash /root/verify-uninstall.sh \
            2>&1 | tee "$LOG_DIR/verify-uninstall.log"; then
        echo "ERROR: Uninstall verification failed. See $LOG_DIR/verify-uninstall.log"
        return 1
    fi

    pass "ALL TESTS PASSED: $OS_SLUG"
    return 0
}

# ── Entry point ───────────────────────────────────────────────────────────────
TARGET="${1:-}"

if [ -n "$TARGET" ]; then
    # Run a single OS
    run_test "$TARGET"
else
    # Run all OSes; collect results
    RESULTS_PASS=()
    RESULTS_FAIL=()

    for slug in "${ALL_OS_SLUGS[@]}"; do
        if run_test "$slug"; then
            RESULTS_PASS+=("$slug")
        else
            RESULTS_FAIL+=("$slug")
        fi
    done

    echo ""
    echo "=========================================="
    echo " Final Results"
    echo "=========================================="
    for s in "${RESULTS_PASS[@]:-}"; do echo "  PASS  $s"; done
    for s in "${RESULTS_FAIL[@]:-}"; do echo "  FAIL  $s"; done
    echo ""

    if [ "${#RESULTS_FAIL[@]}" -gt 0 ]; then
        echo "  ${#RESULTS_FAIL[@]} of ${#ALL_OS_SLUGS[@]} test(s) FAILED."
        exit 1
    fi

    echo "  All ${#ALL_OS_SLUGS[@]} tests passed."
    exit 0
fi

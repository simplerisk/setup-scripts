# SimpleRisk Setup Script

[![SimpleRisk Install/Uninstall Tests](https://github.com/simplerisk/setup-scripts/actions/workflows/install-test.yml/badge.svg)](https://github.com/simplerisk/setup-scripts/actions/workflows/install-test.yml)

## Supported versions

- Ubuntu LTS 22.04, 24.04, and 26.04
  - Interim (non-LTS) Ubuntu releases are not supported; they get ~9 months of upstream support and churn every 6 months
- Debian 13
- CentOS Stream 9, 10
- Red Hat Enterprise Linux (RHEL) 9, 10
  - RHEL shares the exact same install code path as CentOS Stream (see `setup_centos_rhel` in `simplerisk-setup.sh`), which
    *is* covered by CI below, but RHEL itself isn't independently tested: Red Hat's official container images require a
    paid subscription, and the free UBI images can't substitute because `firewalld` and `sendmail`, both of which the
    script installs, aren't published to any repo UBI can reach without one.
- openSUSE Leap 16.0
  - Leap 16.0 ships PHP 8.4 natively; a real MySQL Community Server RPM (built for SLES 15) installs and runs on it
    without issue - see `setup_suse`/`uninstall_suse` in `simplerisk-setup.sh`.
- SUSE Linux Enterprise Server (SLES) 16.0
  - SLES 16.0 and openSUSE Leap 16.0 share the exact same package builds (`setup_suse`/`uninstall_suse` is one code path
    for both), and unlike RHEL, SLES 16 *is* independently tested: SUSE's free, unauthenticated BCI (Base Container
    Image) - `registry.suse.com/bci/bci-base:16.0` - carries its own public `SLE_BCI` repo with no SCC subscription
    needed, so CI runs the real installer against real SLES 16, not just its openSUSE proxy.

## Explicitly unsupported versions

A few versions are excluded on purpose, not simply because they haven't been tried yet:

- **openSUSE Tumbleweed** - a rolling release, not a stable/LTS-equivalent target. Even though it always carries a
  current PHP, this script intentionally only targets openSUSE's stable branch (Leap).
- **openSUSE Leap 15.x and earlier** - capped at PHP 8.2 (the same `php8` package SLES 15 ships) with no upgrade path,
  and Leap 15.6, the last 15.x release, is now end-of-life.
- **SUSE Linux Enterprise Server (SLES) 15** (all service packs) - not supported, and won't be added without a way to
  verify it. SLES 15 SP7's release notes list PHP 8.3.x as available, which would clear SimpleRisk's PHP >= 8.3
  requirement, but that can't currently be confirmed: openSUSE Leap 15.x, which would otherwise serve as SLES 15's
  free/testable proxy the way Leap 16.0 does for SLES 16.0, ended at 15.6 (see above) and never exceeded PHP 8.2, and
  real SLES 15 container images require a paid SCC subscription to test directly.
- **Ubuntu releases older than 22.04** (18.04, 20.04, etc.), and interim (non-LTS) releases - see the LTS-only policy
  above.
- **Debian releases older than 13** (11, 12, etc.) - out of scope; only the version listed above is targeted.
- **CentOS Stream / RHEL releases older than 9** (8, 7, etc.) - out of scope; CentOS 8 reached end-of-life in December
  2021, and older major versions aren't targeted regardless of a given release's own support status.
- **RHEL-compatible rebuilds** (Rocky Linux, AlmaLinux, Oracle Linux, etc.) - not tested, even though they're binary-
  compatible with RHEL: `/etc/os-release`'s `NAME` differs from `Red Hat Enterprise Linux`/`Red Hat Enterprise Linux
  Server`, so `validate_os_and_version()` doesn't recognize them and the script exits rather than assuming
  compatibility.

## Instructions

Run as root or insert `sudo -E` before `bash`:

- `curl -sL https://raw.githubusercontent.com/simplerisk/setup-scripts/main/simplerisk-setup.sh | bash -`
- `wget -qO- https://raw.githubusercontent.com/simplerisk/setup-scripts/main/simplerisk-setup.sh | bash -`

## `--help`

```
Script to set up or uninstall SimpleRisk on a server.

./simplerisk-setup [-d|--debug] [--yes] [-h|--help] [--uninstall]

Flags:
-d|--debug:            Shows the output of the commands being run by this script
--uninstall:           Removes SimpleRisk and all associated packages, services, and data
                         (Apache/httpd, MySQL, PHP, sendmail/postfix, firewall rules).
                         WARNING: This action is irreversible and will destroy all SimpleRisk data.
--yes:                 Will answer yes on every question (Use it carefully)
-h|--help:             Shows instructions on how to use this script
```

# SimpleRisk Setup Script

[![SimpleRisk Install/Uninstall Tests](https://github.com/simplerisk/setup-scripts/actions/workflows/install-test.yml/badge.svg)](https://github.com/simplerisk/setup-scripts/actions/workflows/install-test.yml)

> [!NOTE]
> **This repository is a read-only publish mirror.** `simplerisk-setup.sh` and this README are published here
> automatically from SimpleRisk's internal development repository whenever they change. Development and testing
> happen there, and pull requests opened here cannot be merged: any change committed directly to this repository would
> be overwritten by the next sync. To report a problem or request a change, please open an issue.

## Supported versions

- Ubuntu LTS 22.04, 24.04, and 26.04
  - Interim (non-LTS) Ubuntu releases are not supported; they get ~9 months of upstream support and churn every 6 months
- Debian 13
- CentOS Stream 9, 10
- Red Hat Enterprise Linux (RHEL) 9, 10
  - RHEL shares the exact same install code path as CentOS Stream (see `setup_centos_rhel` in `simplerisk-setup.sh`),
    which is tested in containers (see [How this is tested](#how-this-is-tested)). Red Hat's container images require a
    paid subscription, and the free UBI images can't substitute because `firewalld` and `sendmail`, both of which the
    script installs, aren't published to any repo UBI can reach without one, so RHEL itself is installed on real
    RHEL 9 and 10 instances in SimpleRisk's private CI instead.
- openSUSE Leap 16.0
  - Leap 16.0 ships PHP 8.4 natively; a real MySQL Community Server RPM (built for SLES 15) installs and runs on it
    without issue - see `setup_suse`/`uninstall_suse` in `simplerisk-setup.sh`.
- SUSE Linux Enterprise Server (SLES) 15 SP7 or later
  - SLES 15 SP7 is the first service pack whose Web and Scripting module ships PHP 8.3 (SimpleRisk requires PHP 8.3+);
    SP6 and earlier ship PHP 8.2 or older and are rejected. It requires an active SUSE subscription with the Web and
    Scripting module activated via `suseconnect`, so it is verified on a real SLES 15 SP7 (x86_64) instance in SimpleRisk's
    private CI rather than in a public container.
- SUSE Linux Enterprise Server (SLES) 16.0
  - SLES 16.0 and openSUSE Leap 16.0 share the exact same package builds (`setup_suse`/`uninstall_suse` is one code path
    for both), and unlike RHEL, SLES 16 *is* independently tested: SUSE's free, unauthenticated BCI (Base Container
    Image) - `registry.suse.com/bci/bci-base:16.0` - carries its own public `SLE_BCI` repo with no SCC subscription
    needed, so CI runs the real installer against real SLES 16, not just its openSUSE proxy.

## How this is tested

| Platforms | Where | What is checked |
|---|---|---|
| Ubuntu 22.04, 24.04, 26.04; Debian 13; CentOS Stream 9, 10; openSUSE Leap 16.0; SLES 16.0 | Docker containers on GitHub-hosted runners | Install, then a verification script (files, configuration, database, cron, web server, and the application's own health check after creating the admin account), then uninstall and its verification |
| RHEL 9, 10; SLES 15 SP7 | Real instances in SimpleRisk's private CI (these need a paid subscription) | Install, then `https://localhost` must answer 200. Uninstall is not exercised |

## Architecture

The container tests run on **x86_64**. Of the real-instance tests, SLES 15 runs on **x86_64** and RHEL 9 and 10 run on
**arm64** (AWS Graviton); the RHEL install path is also exercised on x86_64 through the CentOS Stream containers.
SUSE-based systems (SLES, openSUSE Leap) are **x86_64 only**: MySQL does not publish a Community Server repository for
SLES 15 or 16 on aarch64, so the installer cannot complete there. Ubuntu, Debian and CentOS Stream on arm64 are not
tested.

## Explicitly unsupported versions

A few versions are excluded on purpose, not simply because they haven't been tried yet:

- **openSUSE Tumbleweed** - a rolling release, not a stable/LTS-equivalent target. Even though it always carries a
  current PHP, this script intentionally only targets openSUSE's stable branch (Leap).
- **openSUSE Leap 15.x and earlier** - capped at PHP 8.2 (the same PHP 8.2 `php8` package as SLES 15 SP6) with no upgrade path,
  and Leap 15.6, the last 15.x release, is now end-of-life.
- **SUSE Linux Enterprise Server (SLES) 15 SP6 and earlier** - capped at PHP 8.2 or older, below SimpleRisk's PHP >= 8.3
  requirement.
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

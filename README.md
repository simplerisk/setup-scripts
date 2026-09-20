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

SUSE Linux Enterprise Server (SLES) is not currently supported: SimpleRisk requires PHP >= 8.3, and SLES 15's own
repositories only offer PHP 8.2 with no upgrade path currently available. Support may return once a SLES release with a
newer PHP is available.

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

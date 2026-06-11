# SimpleRisk Setup Script

## Supported versions

- Ubuntu LTS 22.04, 24.04, and 25.x
  - Although it is possible to install on non-LTS versions in between the two most recent LTS versions or above the most
    recent version specified above, we do not support them officially
- Debian 13
- CentOS Stream 9, 10
- Red Hat Enterprise Linux (RHEL) 9, 10
- SUSE Linux Enterprise Server (SLES) 15.x

## Instructions

Run as root or insert `sudo -E` before `bash`:

- `curl -sL https://raw.githubusercontent.com/simplerisk/setup-scripts/master/simplerisk-setup.sh | bash -`
- `wget -qO- https://raw.githubusercontent.com/simplerisk/setup-scripts/master/simplerisk-setup.sh | bash -`

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

# SimpleRisk Setup Script

## Supported versions

- Ubuntu LTS 20.04, 22.04, and 24.04
  - Although it is possible to install on non-LTS versions in between the two most recent LTS versions specified above,
    we do not support them officially
- Debian 11, 12
- CentOS Stream 9
- Red Hat Enterprise Linux (RHEL) 8, 9
- SUSE Linux Enterprise Server (SLES) higher than 15.5

## Instructions

Run as root or insert `sudo -E` before `bash`:

- `curl -sL https://raw.githubusercontent.com/simplerisk/setup-scripts/master/simplerisk-setup.sh | bash -`
- `wget -qO- https://raw.githubusercontent.com/simplerisk/setup-scripts/master/simplerisk-setup.sh | bash -`

## `--help`

```
Script to set up SimpleRisk on a server.

./simplerisk-setup [-d|--debug] [-n|--no-assistance] [-h|--help] [--validate-os-only]

Flags:
-d|--debug:            Shows the output of the commands being run by this script
-n|--no-assistance:    Runs the script in headless mode (will assume yes on anything)
-t|--testing:          Picks the current testing version
--validate-os-only:    Only validates if the current host (OS and version) are supported by the script. This option does not require running the script as superuser.
-h|--help:             Shows instructions on how to use this script
```

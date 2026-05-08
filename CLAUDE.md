# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A single Bash script (`simplerisk-setup.sh`) that installs or uninstalls [SimpleRisk](https://www.simplerisk.com/) (an open-source risk management application) on supported Linux servers. It sets up a full LAMP stack (Apache, MySQL 8.4 LTS, PHP 8.5) with SSL, firewall rules, sendmail/postfix, and a backup cron job.

## Supported operating systems

| OS | Versions |
|---|---|
| Ubuntu | 22.04 LTS, 24.x, 25.x |
| Debian | 12, 13 |
| CentOS Stream | 9, 10 |
| RHEL / RHEL Server | 9.x, 10.x |
| SLES | 15.7+ (requires PHP module activated via `suseconnect`) |

## Automated testing

Docker-based tests live in `tests/`. They cover install and uninstall for every supported OS except RHEL (requires paid subscription) and SLES (requires subscription + `suseconnect`).

```bash
# Run all OSes
bash tests/run-tests.sh

# Run a single OS
bash tests/run-tests.sh ubuntu-22.04
bash tests/run-tests.sh debian-12
bash tests/run-tests.sh centos-stream-9
```

Available slugs: `ubuntu-22.04`, `ubuntu-24.04`, `debian-12`, `debian-13`, `centos-stream-9`, `centos-stream-10`.

Each test run: builds the image → starts the container → installs SimpleRisk (`--yes --debug`) → runs `tests/verify-install.sh` inside the container → uninstalls (`--uninstall --yes --debug`) → runs `tests/verify-uninstall.sh`. Logs land in `tests/logs/<os-slug>/`.

**CentOS/RHEL containers require `--privileged` and systemd as PID 1.** The Dockerfiles handle this. Debian/Ubuntu containers use `--privileged` only for UFW; no systemd is needed because the script calls `service` on those distros.

CI runs automatically via `.github/workflows/install-test.yml` on push/PR to `main` using a matrix across all six OSes (`fail-fast: false`).

## Validating the script

The only "test" available is the OS validation dry-run — no build system or test suite exists:

```bash
sudo bash simplerisk-setup.sh --validate-os-only
```

This validates that the detected OS/version is supported without requiring root and without making any changes.

## Running the script

```bash
# Interactive install
sudo bash simplerisk-setup.sh

# Headless install (auto-yes)
sudo bash simplerisk-setup.sh --yes

# Debug mode (shows all command output)
sudo bash simplerisk-setup.sh --debug

# Install the current testing release
sudo bash simplerisk-setup.sh --testing

# Uninstall SimpleRisk and all associated components
sudo bash simplerisk-setup.sh --uninstall
```

## Architecture

The script is structured as a single file with clearly delimited sections:

- **Main flow** (`setup`, `validate_args`, `check_root`, `ask_user`, `load_os_variables`, `validate_os_and_version`) — orchestrates the overall run. `setup()` is the entry point called at the bottom of the file.
- **Installation dispatcher** (`perform_installation`) — calls the appropriate OS-specific setup function.
- **Uninstallation dispatcher** (`perform_uninstallation`) — calls the appropriate OS-specific uninstall function.
- **Auxiliary/shared functions** — `set_up_database`, `set_up_simplerisk`, `set_php_settings`, `set_up_backup_cronjob`, `generate_passwords`, `drop_simplerisk_database`, `remove_backup_cronjob`, etc. These are called by the OS-specific functions.
- **OS setup functions** — `setup_ubuntu_debian`, `setup_centos_rhel`, `setup_suse`. Each handles its package manager, repos, service management, and config file paths.
- **OS uninstall functions** — `uninstall_ubuntu_debian`, `uninstall_centos_rhel`, `uninstall_suse`. Mirror the setup functions in reverse.

## Keeping README.md in sync

After any change to `simplerisk-setup.sh`, check whether `README.md` needs updating. The areas most likely to drift:

- **Supported OS/version table** — if a new distro or version is added/removed, update the list in the README.
- **`--help` flags block** — the README contains a verbatim copy of the help output. If flags are added, removed, or their descriptions change, mirror those changes in the README's ` ```--help``` ` section and its synopsis line.
- **SLES minimum SP** — the `SLES_15_SUPPORTED_SP` constant drives the version check; the README must reflect the same value.

## Key conventions

- `exec_cmd` wraps a command and calls `bail` on failure. Use this for steps that must succeed.
- `exec_cmd_nobail` runs a command but does not abort on failure. Use this for cleanup/uninstall steps where partial state is acceptable.
- OS detection populates `$OS` and `$VER`; `validate_os_and_version` sets `$SETUP_TYPE` to `debian`, `rhel`, or `suse`. All OS-specific branching elsewhere uses `$SETUP_TYPE` or `$OS`/`$VER` directly.
- MySQL root password is stored in `/root/passwords.txt` (mode 600) after install. The uninstall path reads it back via `get_mysql_root_password` to drop the database.
- SLES requires the PHP8 module to be activated in the subscription before running the script.

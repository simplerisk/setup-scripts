#!/usr/bin/env bash

set -euo pipefail

readonly UBUNTU_OSVAR='Ubuntu'
readonly DEBIAN_OSVAR='Debian GNU/Linux'
readonly CENTOS_STREAM_OSVAR='CentOS Stream'
readonly RHEL_OSVAR='Red Hat Enterprise Linux'
readonly RHELS_OSVAR='Red Hat Enterprise Linux Server'
readonly SLES_OSVAR='SLES'

# Base URL for setup scripts
readonly SETUP_SCRIPTS_BASE_URL='https://raw.githubusercontent.com/simplerisk/setup-scripts/master'

#########################
## MAIN FLOW FUNCTIONS ##
#########################
setup (){
	validate_args "${@:1}"

	# Check root unless you only want to validate if the script works on the host
	if [ ! -v VALIDATE_ONLY ]; then
		check_root
	fi
	# Ask user input unless it is on headless mode or validating if the script works
	if [ ! -v HEADLESS ] && [ ! -v VALIDATE_ONLY ]; then
		ask_user
	fi
	load_os_variables
	validate_os_and_version
	if [ -v VALIDATE_ONLY ]; then
		exit 0
	fi

	# Get SimpleRisk version (either specified or latest)
	if [ -z "${SIMPLERISK_VERSION:-}" ]; then
		print_status 'Determining latest SimpleRisk version...'
		SIMPLERISK_VERSION=$(get_current_simplerisk_version)
	fi
	print_status "SimpleRisk version to install: ${SIMPLERISK_VERSION}"

	download_and_run_os_installer
}

validate_args(){
	while [[ $# -gt 0 ]]
	do
		local key="${1}"
		case "${key}" in
			-n|--no-assistance)
				HEADLESS=y
				shift;;
			-d|--debug)
				DEBUG=y
				shift;;
			-t|--testing)
				TESTING=y
				shift;;
			-v|--version)
				if [[ -z "${2:-}" ]]; then
					echo "Error: --version requires a version number argument"
					print_help
					exit 1
				fi
				SIMPLERISK_VERSION="${2}"
				shift 2;;
			--validate-os-only)
				VALIDATE_ONLY=y
				shift;;
			-h|--help)
				print_help
				exit 0;;
			*)    # unknown option
				echo "Provided parameter ${key} is not valid."
				print_help
				exit 1;;
		esac
	done
}

check_root() {
	## Check to make sure we are running as root
	if [ ${EUID} -ne 0 ]; then
		print_error_message "This script must be run as root (unless for only verifying the OS). Try running the command 'sudo bash' and then run this script again."
	fi
}

ask_user(){
	read -r -p 'This script will install SimpleRisk on this system.  Are you sure that you would like to proceed? [ Yes / No ]: ' answer < /dev/tty
	case "${answer}" in
		Yes|yes|Y|y ) ;;
		* ) exit 1;;
	esac
}

load_os_variables(){
	# freedesktop.org and systemd
	if [ -f /etc/os-release ]; then
		# shellcheck source=/dev/null
		. /etc/os-release
		OS=$NAME
		VER=$VERSION_ID
	# linuxbase.org
	elif type lsb_release >/dev/null 2>&1; then
		OS=$(lsb_release -si)
		VER=$(lsb_release -sr)
	# For some versions of Debian/Ubuntu without lsb_release command
	elif [ -f /etc/lsb-release ]; then
		# shellcheck source=/dev/null
		. /etc/lsb-release
		OS=$DISTRIB_ID
		VER=$DISTRIB_RELEASE
	# Older Debian/Ubuntu/etc.
	elif [ -f /etc/debian_version ]; then
		OS=$DEBIAN_OSVAR
		VER=$(cat /etc/debian_version)
	# Older SuSE/etc. or Red Hat, CentOS, etc.
	elif [ -f /etc/SuSe-release ] || [ -f /etc/redhat-release ]; then
		echo 'The SimpleRisk setup script cannot reliably determine which commands to run for this OS. Exiting.'
		exit 1
	# Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
	else
		OS=$(uname -s)
		VER=$(uname -r)
	fi
}

validate_os_and_version(){
	local valid
	case "${OS}" in
		"${UBUNTU_OSVAR}")
			if [ "${VER}" = '22.04' ] || [[ "${VER}" = 24.* ]] || [[ "${VER}" = 25.* ]]; then
				valid=y
				SETUP_TYPE=debian
			fi;;
		"${DEBIAN_OSVAR}")
			if [ "${VER}" = "11" ] || [ "${VER}" = '12' ]; then
				valid=y
				SETUP_TYPE=debian
			fi;;
		"${CENTOS_STREAM_OSVAR}")
			if [ "${VER}" = "9" ]; then
				valid=y
				SETUP_TYPE=rhel
			fi;;
		"${RHEL_OSVAR}"|"${RHELS_OSVAR}")
			if [[ "${VER}" = 8* ]] || [[ "${VER}" = 9* ]]; then
				valid=y
				SETUP_TYPE=rhel
			fi;;
		"${SLES_OSVAR}")
			if [[ "${VER}" = 15* ]]; then
				valid=y
				if [ ! -v HEADLESS ] && [ ! -v VALIDATE_ONLY ]; then
					read -r -p 'Before continuing, SLES 15 does not have sendmail available on its repositories. You will need to configure postfix to be able to send emails. Do you still want to proceed? [ Yes / No ]: ' answer < /dev/tty
					case "${answer}" in
						Yes|yes|Y|y ) SETUP_TYPE=suse;;
						* ) exit 1;;
					esac
				else
					echo "This will install postfix. You will need to configure it after the installation."
					SETUP_TYPE=suse
				fi
			fi;;
		*)
			local unknown=y;;
	esac

	if [ -n "${valid:-}" ]; then
		echo "Detected OS is ${OS} ${VER}, which is supported by this script."
	elif [ -z "${valid:-}" ] && [ ! -v unknown ]; then
		echo "Detected OS is ${OS} ${VER}, but this version is not currently supported by this script."
		exit 1
	else
		echo "Detected OS is ${OS}, but it is unsupported by this script."
		exit 1
	fi
}

get_current_simplerisk_version() {
	curl -sL "https://updates${TESTING:+-test}.simplerisk.com/releases.xml" | grep -oP '<release version=(.*)>' | head -n1 | cut -d '"' -f 2
}

download_and_run_os_installer() {
	local installer_script
	case "${SETUP_TYPE:-}" in
		debian) installer_script="simplerisk-setup-debian.sh";;
		rhel) installer_script="simplerisk-setup-rhel.sh";;
		suse) installer_script="simplerisk-setup-suse.sh";;
		*) print_error_message "Could not validate the setup type. Check the validate_os_and_version function.";;
	esac

	print_status "Downloading and running ${installer_script}..."

	# Download the OS-specific installer
	local installer_url="${SETUP_SCRIPTS_BASE_URL}/${installer_script}"
	local temp_installer="/tmp/${installer_script}"

	# Use --fail to make curl return error on HTTP errors (like 404)
	# Use --location to follow redirects
	# Use --silent to suppress progress bar
	# Use --show-error to show errors even in silent mode
	if ! curl --fail --location --silent --show-error "${installer_url}" -o "${temp_installer}"; then
		print_error_message "Failed to download ${installer_script} from ${installer_url}. Please check that the script exists in the repository."
	fi

	# Verify the downloaded file is a bash script
	if ! head -n 1 "${temp_installer}" | grep -q '^#!/'; then
		print_error_message "Downloaded file does not appear to be a valid script. The URL may have returned an error page."
	fi

	# Make it executable
	chmod +x "${temp_installer}"

	# Export variables that the installer will need
	export OS
	export VER
	export SETUP_TYPE
	export SIMPLERISK_VERSION
	export DEBUG
	export TESTING
	export HEADLESS

	# Run the installer
	if ! bash "${temp_installer}"; then
		print_error_message "Installation failed. Check the output above for details."
	fi

	# Clean up
	rm -f "${temp_installer}"
}

#########################
## AUXILIARY FUNCTIONS ##
#########################
print_status() {
	echo
	echo "## ${1}"
	echo
}

print_error_message() {
	echo
	echo "!!! ERROR: ${1} !!!"
	echo
	exit 1
}

print_help() {
	cat << EOC

Script to set up SimpleRisk on a server.

./simplerisk-setup.sh [-d|--debug] [-n|--no-assistance] [-v|--version VERSION] [-t|--testing] [-h|--help] [--validate-os-only]

Flags:
-d|--debug:            Shows the output of the commands being run by this script
-n|--no-assistance:    Runs the script in headless mode (will assume yes on anything)
-v|--version VERSION:  Install a specific version of SimpleRisk (default: latest)
-t|--testing:          Picks the current testing version from the testing channel
--validate-os-only:    Only validates if the current host (OS and version) are supported
                         by the script. This option does not require running the script
                         as superuser.
-h|--help:             Shows instructions on how to use this script

Examples:
  Install latest version:
    curl -sL https://raw.githubusercontent.com/simplerisk/setup-scripts/master/simplerisk-setup.sh | bash -

  Install specific version:
    curl -sL https://raw.githubusercontent.com/simplerisk/setup-scripts/master/simplerisk-setup.sh | bash -s -- -v 20241201-001

  Install in headless mode with debug output:
    curl -sL https://raw.githubusercontent.com/simplerisk/setup-scripts/master/simplerisk-setup.sh | bash -s -- -n -d

  Validate OS compatibility only:
    curl -sL https://raw.githubusercontent.com/simplerisk/setup-scripts/master/simplerisk-setup.sh | bash -s -- --validate-os-only
EOC
}

## Defer setup until we have the complete script
setup "${@:1}"
#!/usr/bin/env bash
#shellcheck disable=SC2034
# Comments prefixed by BASHDOC: are hints to specific GNU Bash Manual's section:
# https://www.gnu.org/software/bash/manual/

## Makes debuggers' life easier - Unofficial Bash Strict Mode
## http://redsymbol.net/articles/unofficial-bash-strict-mode/
## BASHDOC: Shell Builtin Commands - Modifying Shell Behavior - The Set Builtin
### Exit prematurely if a command's return value is not 0(with some exceptions), triggers ERR trap if available.
set -o errexit

### Trap on `ERR' is inherited by shell functions, command substitutions, and subshell environment as well
set -o errtrace

### Exit prematurely if an unset variable is expanded, causing parameter expansion failure.
set -o nounset

### Let the return value of a pipeline be the value of the last (rightmost) command to exit with a non-zero status
set -o pipefail

## Non-overridable Primitive Variables
##
## BashFAQ/How do I determine the location of my script? I want to read some config files from the same place. - Greg's Wiki
## http://mywiki.wooledge.org/BashFAQ/028
RUNTIME_EXECUTABLE_FILENAME="$(basename "${BASH_SOURCE[0]}")"
declare -r RUNTIME_EXECUTABLE_FILENAME
declare -r RUNTIME_EXECUTABLE_NAME="${RUNTIME_EXECUTABLE_FILENAME%.*}"
RUNTIME_EXECUTABLE_DIRECTORY="$(dirname "$(realpath --strip "${0}")")"
declare -r RUNTIME_EXECUTABLE_DIRECTORY
declare -r RUNTIME_EXECUTABLE_PATH_ABSOLUTE="${RUNTIME_EXECUTABLE_DIRECTORY}/${RUNTIME_EXECUTABLE_FILENAME}"
declare -r RUNTIME_EXECUTABLE_PATH_RELATIVE="${0}"
declare -r RUNTIME_COMMAND_BASE="${RUNTIME_COMMAND_BASE:-${0}}"

trap_errexit(){
	printf "An error occurred and the script is prematurely aborted\n" 1>&2
	return 0
}; declare -fr trap_errexit; trap trap_errexit ERR

trap_exit(){
	return 0
}; declare -fr trap_exit; trap trap_exit EXIT

check_runtime_dependencies(){
	for a_command in git ln; do
		if ! command -v "${a_command}" &>/dev/null; then
			printf "%s: %s: Error: \"%s\" command not found, check your runtime dependencies\n" "${RUNTIME_EXECUTABLE_NAME}" "${FUNCNAME[0]}" "${a_command}" 1>&2
		fi
	done
}; declare -fr check_runtime_dependencies
## init function: program entrypoint
init(){
	cd "${RUNTIME_EXECUTABLE_DIRECTORY}"
	git submodule init \
		'Git Clean and Smudge Filters/Clean Filter for GNU Bash Scripts' \
		'Git Hooks/Git Pre-commit Hook for GNU Bash Projects' \
		'Linters/GNU Bash Automatic Checking Program for Git Projects'
	git submodule update \
		--depth=1

	export GIT_DIR="${RUNTIME_EXECUTABLE_DIRECTORY}/.git"
	export GIT_WORK_TREE="${RUNTIME_EXECUTABLE_DIRECTORY}"

	git config --local include.path ../.gitconfig
	ln\
		--verbose\
		--symbolic\
		--relative\
		--force\
		"${RUNTIME_EXECUTABLE_DIRECTORY}/Git Hooks/Git Pre-commit Hook for GNU Bash Projects/Pre-commit Script.bash"\
		"${GIT_DIR}/hooks/pre-commit"

	printf "\nDevelopment environment setup done, happy hacking!\n"
	exit 0
}; declare -fr init
init "${@}"

## This script is based on the GNU Bash Shell Script Template project
## https://github.com/Lin-Buo-Ren/GNU-Bash-Shell-Script-Template
## and is based on the following version:
declare -r META_BASED_ON_GNU_BASH_SHELL_SCRIPT_TEMPLATE_VERSION="v1.24.1"
## You may rebase your script to incorporate new features and fixes from the template

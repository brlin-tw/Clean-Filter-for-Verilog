#!/usr/bin/env bash
#shellcheck disable=SC2034
# Comments prefixed by BASHDOC: are hints to specific GNU Bash Manual's section:
# https://www.gnu.org/software/bash/manual/
# Clean filter for Verilog using vdent(https://github.com/bmartini/vdent) wrapper for manual applying
# 林博仁 © 2017

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
	rm --force "${temp_file}"
	return 0
}; declare -fr trap_exit; trap trap_exit EXIT

## init function: program entrypoint
init(){
	if [ "${#}" -ne 1 ]; then
		printf "錯誤：參數數量錯誤。\n" 1>&2
		printf "資訊：使用方式：%s 〈要套用過濾器的檔案〉\n" "${RUNTIME_COMMAND_BASE}"
		exit 1
	else
		local target_file="${*}"
		declare -g temp_file
		temp_file="$(mktemp --tmpdir "${RUNTIME_EXECUTABLE_NAME}.XXXXXX")"
		readonly temp_file

		local filter_name
		filter_name="$(basename --suffix=.manual-apply.bash "${RUNTIME_EXECUTABLE_FILENAME}").bash"
		local filter="${RUNTIME_EXECUTABLE_DIRECTORY}/${filter_name}"

		"${filter}" <"${target_file}" >"$temp_file"
		cat "$temp_file" >"$target_file"
		exit 0
	fi
}; declare -fr init
init "${@}"

## This script is based on the GNU Bash Shell Script Template project
## https://github.com/Lin-Buo-Ren/GNU-Bash-Shell-Script-Template
## and is based on the following version:
declare -r META_BASED_ON_GNU_BASH_SHELL_SCRIPT_TEMPLATE_VERSION="v1.24.2-3-g3ec093a"
## You may rebase your script to incorporate new features and fixes from the template
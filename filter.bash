#!/usr/bin/env bash
declare -r APPLICATION_NAME='Clean Filter for Verilog HDL'
# 林博仁 © 2017, 2018

# NOTE: ALWAYS PRINT MESSAGES TO STDERR as output to stdout will contaminate the input files when the program is operate in filter mode.

## Makes debuggers' life easier - Unofficial Bash Strict Mode
## BASHDOC: Shell Builtin Commands - Modifying Shell Behavior - The Set Builtin
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

## Runtime Dependencies Checking
declare\
	runtime_dependency_checking_result=still-pass\
	required_software

for required_command in \
	basename \
	cp \
	dirname \
	mktemp \
	realpath \
	sed \
	unexpand; do
	if ! command -v "${required_command}" &>/dev/null; then
		runtime_dependency_checking_result=fail

		case "${required_command}" in
			basename \
			|cp \
			|dirname \
			|mktemp \
			|realpath \
			|unexpand)
				required_software='GNU Coreutils'
				;;
			sed)
				required_software='GNU Sed'
				;;
			*)
				required_software="${required_command}"
				;;
		esac

		printf --\
			'Error: This program requires "%s" to be installed and its executables in the executable searching paths.\n'\
			"${required_software}" 1>&2
		unset required_software
	fi
done; unset required_command required_software

if [ "${runtime_dependency_checking_result}" = fail ]; then
	printf --\
		'Error: Runtime dependency checking fail, the progrom cannot continue.\n' 1>&2
	exit 1
fi; unset runtime_dependency_checking_result

## Non-overridable Primitive Variables
## BASHDOC: Shell Variables » Bash Variables
## BASHDOC: Basic Shell Features » Shell Parameters » Special Parameters
if [ -v 'BASH_SOURCE[0]' ]; then
	RUNTIME_EXECUTABLE_PATH="$(realpath --strip "${BASH_SOURCE[0]}")"
	RUNTIME_EXECUTABLE_FILENAME="$(basename "${RUNTIME_EXECUTABLE_PATH}")"
	RUNTIME_EXECUTABLE_NAME="${RUNTIME_EXECUTABLE_FILENAME%.*}"
	RUNTIME_EXECUTABLE_DIRECTORY="$(dirname "${RUNTIME_EXECUTABLE_PATH}")"
	RUNTIME_COMMANDLINE_BASECOMMAND="${0}"
	# We intentionally leaves these variables for script developers
	# shellcheck disable=SC2034
	declare -r \
		RUNTIME_EXECUTABLE_PATH \
		RUNTIME_EXECUTABLE_FILENAME \
		RUNTIME_EXECUTABLE_NAME \
		RUNTIME_EXECUTABLE_DIRECTORY \
		RUNTIME_COMMANDLINE_BASECOMMAND
fi
declare -ar RUNTIME_COMMANDLINE_ARGUMENTS=("${@}")

## Global Variables
### Temporary file used in converter mode
### This parameter will be dropped in exit trap as we need to clean the temporary file
declare converter_intermediate_file

### Temporary file for emulating filter feature where iStyle doesn't support it.
### This parameter will be dropped in exit trap as we need to clean the temporary file
declare istyle_filter_emul_file

## init function: entrypoint of main program
## This function is called near the end of the file,
## with the script's command-line parameters as arguments
init(){
	local cleaner=vdent
	local flag_converter_mode=false
	local -a input_files=()

	if ! process_commandline_arguments \
			cleaner \
			flag_converter_mode \
			input_files; then
		printf --\
			'Error: Invalid command-line parameters.\n'\
			1>&2

		# separate error message and help message
		printf '\n' \
			1>&2
		print_help
		exit 1
	fi

	if ! check_optional_dependencies \
		"${cleaner}"; then
		exit 1
	fi

	case "${flag_converter_mode}" in
		false)
			# Filter mode
			printf -- \
				'%s: Cleaning Verilog HDL code...\n' \
				"${APPLICATION_NAME}" \
				1>&2
			pass_over_filter\
				"${cleaner}"
			;;
		true)
			converter_intermediate_file="$(
				mktemp\
					--tmpdir\
					--suffix=.v\
					"${APPLICATION_NAME}.XXXX"
			)"

			for input_file in "${input_files[@]}"; do
				printf -- \
					'%s: Cleaning "%s"...\n' \
					"${APPLICATION_NAME}" \
					"${input_file}" \
					1>&2
				pass_over_filter \
					"${cleaner}" \
					<"${input_file}" \
					>"${converter_intermediate_file}"
				cp \
					--force \
					"${converter_intermediate_file}" \
					"${input_file}"
			done; unset input_file
			;;
		*)
			printf -- \
				"FATAL: Shouldn't be here, report bug.\\n" \
				1>&2
			exit 1
			;;
	esac

	exit 0
}; declare -fr init

print_help(){
	# shellcheck disable=SC2016
	# Backticks(`) in this context are Markdown code formatting, not command expansion
	# BASH_MANUAL: Basic Shell Features > Shell Commands > Compound Commands > Grouping Commands
	{
		printf '# Help Information for %s #\n' \
			"${APPLICATION_NAME}"
		printf '## Synopsis ##\n'
		printf '### Filter Mode(default) ###\n'
		printf '`cat _verilog_file_ | "%s" > _beautified_verilog_file_`\n' \
			"${RUNTIME_COMMANDLINE_BASECOMMAND}"
		printf '\n'
		printf '(Input should be provided through data redirection by shell facility, cleaned product is provided through stdout)\n'
		printf '\n'
		printf '### Converter Mode ###\n'
		printf '`"%s" --converter _verilog_file_ ...`\n' \
			"${RUNTIME_COMMANDLINE_BASECOMMAND}"
		printf '\n'
		printf '## Command-line Options ##\n'
		printf '### `--help` / `-h` ###\n'
		printf 'This message\n\n'

		printf '### `--debug` / `-d` ###\n'
		printf 'Enable debug mode\n\n'

		printf '### `--cleaner` / `-c` <name> ###\n'
		printf 'Select cleaner: `vdent`(default), `istyle`\n\n'

		printf '### `--converter` / `-C` ###\n'
		printf 'Operate in converter mode instead of filter mode, accept non-option arguments as input files\n\n'

		printf '### `--` ###\n'
		printf 'Signals that further command-line arguments are all input files\n\n'
	} 1>&2

	return 0
}; declare -fr print_help;

process_commandline_arguments() {
	local -n cleaner_ref="${1}"; shift
	local -n flag_converter_mode_ref="${1}"; shift
	local -n input_files_ref="${1}"

	if [ "${#RUNTIME_COMMANDLINE_ARGUMENTS[@]}" -eq 0 ]; then
		return 0
	fi

	# modifyable parameters for parsing by consuming
	local -a parameters=("${RUNTIME_COMMANDLINE_ARGUMENTS[@]}")

	# Normally we won't want debug traces to appear during parameter parsing, so we add this flag and defer its activation till returning(Y: Do debug)
	local enable_debug=N

	while true; do
		if [ "${#parameters[@]}" -eq 0 ]; then
			break
		else
			case "${parameters[0]}" in
				--help\
				|-h)
					print_help;
					exit 0
					;;
				--debug\
				|-d)
					enable_debug=Y
					;;
				--cleaner\
				|-c)
					if [ "${#parameters[@]}" -eq 1 ]; then
						printf -- \
							'%s: Error: --cleaner requires 1 additional argument.\n' \
							"${FUNCNAME[0]}" \
							1>&2
						return 1
					fi
					cleaner_ref="${parameters[1]}"
					# shift array by 1 = unset 1st then repack
					unset 'parameters[0]'
					if [ "${#parameters[@]}" -ne 0 ]; then
						parameters=("${parameters[@]}")
					fi
					;;
				--converter\
				|-C)
					flag_converter_mode_ref=true
					;;
				--)
					# shift array by 1 = unset 1st then repack
					unset 'parameters[0]'
					if [ "${#parameters[@]}" -ne 0 ]; then
						parameters=("${parameters[@]}")
					fi

					input_files_ref=("${input_files_ref[@]}" "${parameters[@]}")

					# Break out loop as all arguments are processed
					break
					;;
				*)
					# Assuming converter mode
					input_files_ref+=("${parameters[0]}")
					;;
			esac
			# shift array by 1 = unset 1st then repack
			unset 'parameters[0]'
			if [ "${#parameters[@]}" -ne 0 ]; then
				parameters=("${parameters[@]}")
			fi
		fi
	done

	if [ "${flag_converter_mode_ref}" = false ] && [ "${#input_files_ref[@]}" -ne 0 ]; then
		printf -- \
			'%s: Error: Only in --converter mode can have non-option arguments.\n' \
			"${FUNCNAME[0]}" \
			1>&2
		return 1
	fi

	if [ "${flag_converter_mode_ref}" = true ] && [ "${#input_files_ref[@]}" -eq 0 ]; then
		printf -- \
			'%s: Error: No input files are supplied.\n' \
			"${FUNCNAME[0]}" \
			1>&2
		return 1
	fi

	case "${cleaner_ref}" in
		vdent\
		|istyle)
			:
			;;
		*)
			printf -- \
				'%s: Error: --cleaner not supported.\n' \
				"${FUNCNAME[0]}" \
				1>&2
			return 1
			;;
	esac

	if [ "${enable_debug}" = Y ]; then
		trap 'trap_return "${FUNCNAME[0]}"' RETURN
		set -o xtrace
	fi
	return 0
}; declare -fr process_commandline_arguments

check_optional_dependencies(){
	local -r cleaner="${1}"

	local cleaner_command

	case "${cleaner}" in
		vdent)
			cleaner_command=vdent
			;;
		istyle)
			cleaner_command=iStyle
			;;
		*)
			printf -- \
				"%s: FATAL: Shouldn't be here, report bug.\\n" \
				"${FUNCNAME[0]}" \
				1>&2
			;;
	esac

	if ! command -v "${cleaner_command}" 1>/dev/null 2>&1; then
		printf -- \
			'%s: Error: Unable to find cleaner.  Please ensure that the selected cleaner is installed and its executable path is in the executable search PATHs.\n' \
			"${FUNCNAME[0]}" \
			1>&2
		return 1
	fi

	return 0
}; declare -fr check_optional_dependencies

pass_over_filter(){
	local -r cleaner="${1}"

	case "${cleaner}" in
		vdent)
			vdent -s8 \
				| unexpand
			return 0
			;;
		istyle)
			# As iStyle doesn't support read from stdin, dump stdin to a file as input data
			istyle_filter_emul_file="$(
				mktemp \
					--tmpdir \
					--suffix=.v \
					"${APPLICATION_NAME}.XXXX"
			)"
			cat >"${istyle_filter_emul_file}"

			iStyle \
				--suffix=none \
				--indent=tab=4 \
				--indent-blocks \
				"${istyle_filter_emul_file}" \
				>/dev/null # NOTE: iStyle output message in stdout!

			# Workaround: Remove redundant indentation before `module` statement
			# `module` statement always indented with 8 spaces when `ifndef` compiler directive is used · Issue #4 · thomasrussellmurphy/istyle-verilog-formatter
			# https://github.com/thomasrussellmurphy/istyle-verilog-formatter/issues/4
			sed \
				--in-place \
				's/^        module/module/' \
				"${istyle_filter_emul_file}"

			# print stdin's content to stdout
			cat "${istyle_filter_emul_file}"
			;;
		*)
			printf -- \
				'%s: Error: Unsupported cleaner "%s".\n' \
				"${FUNCNAME[0]}" \
				"${cleaner}" \
				1>&2
			return 1
			;;
	esac
}; declare -fr pass_over_filter

## Traps: Functions that are triggered when certain condition occurred
## Shell Builtin Commands » Bourne Shell Builtins » trap
trap_errexit(){
	printf 'An error occurred and the script is prematurely aborted\n' 1>&2
	return 0
}; declare -fr trap_errexit; trap trap_errexit ERR

trap_exit(){
	# Clean up temp files if available
	if test -v converter_intermediate_file; then
		rm --force "${converter_intermediate_file}"
		unset converter_intermediate_file
	fi
	if test -v istyle_filter_emul_file; then
		rm --force "${istyle_filter_emul_file}"
		unset istyle_filter_emul_file
	fi

	return 0
}; declare -fr trap_exit; trap trap_exit EXIT

trap_return(){
	local returning_function="${1}"

	printf 'DEBUG: %s: returning from %s\n' "${FUNCNAME[0]}" "${returning_function}" 1>&2
}; declare -fr trap_return

trap_interrupt(){
	printf '\n' # Separate previous output
	printf 'Recieved SIGINT, script is interrupted.' 1>&2
	return 1
}; declare -fr trap_interrupt; trap trap_interrupt INT

init "${@}"

## This script is based on the GNU Bash Shell Script Template project
## https://github.com/Lin-Buo-Ren/GNU-Bash-Shell-Script-Template
## and is based on the following version:
## GNU_BASH_SHELL_SCRIPT_TEMPLATE_VERSION="v3.0.9"
## You may rebase your script to incorporate new features and fixes from the template

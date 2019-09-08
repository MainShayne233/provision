#!/usr/bin/env bash

bash_setup() {
    set -CEeuo pipefail
    IFS=$'\n\t'
    shopt -s extdebug

    if "${DEBUG:-false}" eq "true"; then
        set -x
    fi
}

bash_setup

export LOCAL_BIN="/usr/local/bin"
export OPT_DIR="$HOME/opt/"
SCRIPT_PATH="$(dirname $(realpath $0))"
export PACKAGES_DIR="$SCRIPT_PATH/../lib/packages"

if [[ $(uname) == "Darwin" ]]; then
  sedf() { command sed -l "$@"; }
else
  sedf() { command sed -u "$@"; }
fi

indent() {
  sedf "s/^/       /"
}

log() {
  echo "$@" | indent
}

error() {
  echo "$@" 1>&2;
}

header() {
  echo "-----> $1"
}

ensure_args() {
    local expected="$1"
    local actual="$2"
    if [ "$expected" -ne "$actual" ]; then
        echo "Expected $expected args, but got $actual"
        exit 1
    fi
}

which_verify() {
	local name="$1"

  if command -v "$name" > /dev/null; then
    exit 0
  else
    exit 1
  fi
}

ensure_installed() {
    local package_name
    local not_installed
    package_name="$1"
    set +e
    provision verify "$package_name"
    not_installed="$?"
    set -e
    if [ "$not_installed" -eq "1" ]; then
      bash  "$SCRIPT_PATH/$name" "install"
    fi
}

wget_dpkg() {
	local download_url="$1"
	local file="$2"
	wget -P /tmp "$download_url"
	sudo dpkg -i "/tmp/$file"
}

apt_package() {
	local action="$1"
	local package_name="$2"
	local command_name="${3:-$2}"

	case "$action" in

	"verify")
		which_verify "$command_name"
		;;

	"install")
		sudo apt install "$package_name"
		;;

	*)
		echo "Bad action used for apt_package: $action"
		exit 1
		;;
	esac
}

package_script() {
    local package_name
    local package_script
    ensure_args "1" "$#"
    package_name="$1"
    package_script="$PACKAGES_DIR/$package_name"
    if [[ -f "$package_script" ]]; then
        echo "$package_script"
    else
        error "no package script for $package_name"
        exit 1
    fi
}

run_package_command() {
    local package_name
    local command
    local script_path
    local result_code
    ensure_args "2" "$#"
    package_name="$1"
    command="$2"
    script_path=$(package_script "$package_name")
    set +e
    (
        eval "$(cat $script_path)"
        eval "$command"
    )
    result_code="$?"
    set -e
    if [ "$result_code" -eq "0" ]; then
        echo "success"
    else
        echo "failure"
    fi
}

asdf_install_latest() {
    local package_name
    local plugin_url
    local version
    ensure_installed "asdf"
    package_name="$1"
    plugin_url="$2"
    set +e
    asdf plugin-add "$package_name"  "$plugin_url"
    set -e
    version="${3:-$(asdf list-all "$package_name" | grep -v rc | tail -n 1)}"
    asdf install "$package_name" $version
    asdf global "$package_name" $version
}

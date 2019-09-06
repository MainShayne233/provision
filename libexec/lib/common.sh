#!/usr/bin/env bash
# shellcheck disable=SC1117
set -CEeuo pipefail
IFS=$'\n\t'
shopt -s extdebug

export LOCAL_BIN="/usr/local/bin"
export OPT_DIR="$HOME/opt/"

SCRIPT_PATH="$(dirname $(realpath $0))"

export PACKAGES_DIR="$SCRIPT_PATH/../lib/packages"

# if "${DEBUG:-false}" eq "true"; then
#     set +x
# fi

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

  if ! type "$name" > /dev/null; then
    exit 1
  else
    exit 0
  fi
}

ensure_installed() {
  local name="$1"
  local not_installed
  set +e
  bash  "$SCRIPT_PATH/$name" "verify"
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
        echo "No package script found for $package_name"
        exit 1
    fi
}

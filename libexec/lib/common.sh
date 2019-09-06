#!/usr/bin/env bash
# shellcheck disable=SC1117
set -CEeuo pipefail
IFS=$'\n\t'
shopt -s extdebug

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

value_for_index_and_query() {
  local query=".[$1].$2"
  local path=$(echo $INDEX_JSON_FILE | jq --raw-output $query)
  echo $(eval "echo $path")
}

item_name_for_index() {
  local query="name"
  value_for_index_and_query $1 "$query"
}

system_path_for_index() {
  local query="$SYSTEM.system_path"
  value_for_index_and_query $1 "$query"
}

repo_path_for_index() {
  local query="$SYSTEM.repo_path"
  local rel_dir=$(value_for_index_and_query $1 "$query")
  echo "$DOTFILES_DIR/$rel_dir"
}

there_is_system_configuration_for_index() {
  local query="$SYSTEM | type"
  if [[ $(value_for_index_and_query $1 $query) == 'object' ]]; then
    echo 'true'
  else
    echo 'false'
  fi
}

file_or_dir_exists() {
  local path="$1"
  if [[ -f $path || -d $path ]]; then
    return 0
  else
    return 1
  fi
}

BOTH_MATCH=0
BOTH_EXIST=1
SOURCE_EXISTS=2
DESTINATION_EXISTS=3
NEITHER_EXIST=4

determine_path_case() {
  set +e
  local source_path="$1"
  local destination_path="$2"
  file_or_dir_exists $source_path
  local source_exists=$(echo $?)
  file_or_dir_exists $destination_path
  local destination_exists=$(echo $?)

  if [[ $source_exists -eq 0 && $destination_exists -eq 0 ]]; then
    if diff $source_path $destination_path >/dev/null; then
      return $BOTH_MATCH
    else
      return $BOTH_EXIST
    fi
    return $BOTH_EXIST
  elif [[ $source_exists -eq 0 ]]; then
    return $SOURCE_EXISTS
  elif [[ $destination_exists -eq 0 ]]; then
    return $DESTINATION_EXISTS
  else
    return $NEITHER_EXIST
  fi
  set -e
}

verbose_cp() {
  local source="$1"
  local destination="$2"
  header "Copying $source to $destination"
  mkdir -p $destination
  rm -rf $destination
  cp -r $source $destination
}

verbose_rm() {
  local source="$1"
  header "Removing $source"
  rm -rf $source
}

replace_in_repo() {
  local name="$1"
  local system_path="$2"
  local repo_path="$3"
  determine_path_case $system_path $repo_path
  case $? in
    $BOTH_MATCH)
      header "MATCH - $name is up to date!"
      ;;
    $BOTH_EXIST)
      header "DIFF - The version of $name differs on the system from the repo. Update the repo with current version? [y/n/diff]"
      read -r
      if [[ $REPLY =~ ^[Yy]$  ]]; then
        verbose_rm $repo_path
        verbose_cp $system_path $repo_path
      elif [[ $REPLY =~ ^diff$ ]]; then
        set +e
	diff $repo_path $system_path
	set -e
	replace_in_repo $name $system_path $repo_path
      fi
      ;;
    $SOURCE_EXISTS)
      header "MISSING IN REPO - $name does not exist in the repo. Add $system_path to the repo? [y/n]"
      read -r
      if [[ $REPLY =~ ^[Yy]$  ]]; then
         verbose_cp $system_path $repo_path
      fi
      ;;
    $DESTINATION_EXISTS)
      header "MISSING ON SYSTEM - $name does not exist in the on the system. Remove $name from repo too? [y/n]"
      read -r
      if [[ $REPLY =~ ^[Yy]$  ]]; then
        verbose_rm $repo_path
      fi
      ;;
    $NEITHER_EXIST)
      header "ALL MISSING - $name does not exist on the system or in the repo. Skipping."
      ;;
    *)
  esac
}

replace_on_system() {
  local name="$1"
  local system_path="$2"
  local repo_path="$3"
  determine_path_case $system_path $repo_path
  case $? in
    $BOTH_MATCH)
      header "MATCH - $name is up to date!"
      ;;
    $BOTH_EXIST)
      header "DIFF - The version of $name differs on the system from the repo. Update your system with the latest from the repo? [y/n/diff]"
      read -r
      if [[ $REPLY =~ ^[Yy]$  ]]; then
        verbose_rm $system_path
        verbose_cp $repo_path $system_path
      elif [[ $REPLY =~ ^diff$ ]];then
        set +e
	diff $system_path $repo_path
	set -e
	replace_on_system $name $system_path $repo_path
      fi
      ;;
    $SOURCE_EXISTS)
      header "MISSING IN REPO - $name does not exist in the repo. Remove $name from the system as well? [y/n]"
      read -r
      if [[ $REPLY =~ ^[Yy]$  ]]; then
         verbose_rm $system_path
      fi
      ;;
    $DESTINATION_EXISTS)
      header "MISSING ON SYSTEM - $name does not exist in the on the system. Copy $name onto the system? [y/n]"
      read -r
      if [[ $REPLY =~ ^[Yy]$  ]]; then
        verbose_cp $repo_path $system_path
      fi
      ;;
    $NEITHER_EXIST)
      header "ALL MISSING - $name does not exist on the system or in the repo. Skipping."
      ;;
    *)
  esac
}

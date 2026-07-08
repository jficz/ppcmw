#!/usr/bin/env bash

VERSION=0.3.0
PROGNAME=ppcmw

# basic functions
function log() {
  echo "$*" > /dev/stderr
}

function die() {
  log "$*"
  exit 1
}

if [[ "$1" == "-v" || "$1" == "--version" ]]; then
  log "$PROGNAME v$VERSION"
  exit 0
fi

# config
_conf="${XDG_CONFIG_HOME:-"$HOME/.config"}/ppcmw.conf"
_state="${XDG_STATE_HOME:-"$HOME/.local/state"}/ppcmw"

[[ -f "$_conf" ]] && source "$_conf"

# fail fast if cli not found
_pcli=${pass_cli_bin:-"pass-cli"}
[[ -x $(command -v $_pcli) ]] || die "Pass-cli binary not found: $_pcli"


# create or include state
mkdir -p "$_state"

declare -A state
for st in vault_share_id items_cache; do
  state[$st]=$([[ -f "$_state/$st" ]] && cat "${_state}/${st}")
done

# defaults
_vault=${vault_name:-Personal}
_menu=${menu_command:-fuzzel --dmenu --index --hide-before-typing}
_type=${type_command:-wtype}

[[ -x $(command -v ${_menu%% *}) ]] || die "Menu binary not found: ${_menu%% *}"
[[ -x $(command -v ${_type%% *}) ]] || die "Type binary not found: ${_type%% *}"


# runtime functions

function call-pass() {
  pass-cli "$@" --output json --share-id "${state[vault_share_id]}"
}

if ! $_pcli test; then
  if [[ -n "$PAT" ]]; then
    PROTON_PASS_PERSONAL_ACCESS_TOKEN="$PAT" \
    $_pcli login \
    || die "Cannot log in with provided PAT"
  else
    die "No active session and PAT not provided!"
  fi
fi

# cache vault share id if needed, in the background
(
  _id=$($_pcli vault list --output json | jq -r '.vaults[] | select(.name == "'"$_vault"'") | .share_id')
  if [[ "$_id" != "${state[vault_share_id]}" ]]; then
    echo "$_id" > "$_state"/vault_share_id
  fi
) &

if [[ -z "${state[vault_share_id]}" ]]; then
  wait
  state[vault_share_id]=$(cat "$_state"/vault_share_id)
fi


# refresh items cache in the background
(
  _items_cache=$(call-pass item list --filter-type login --filter-state active | jq -r '.items[] | (.id,.title)')
  if [[ ${#_items_cache} -ne ${#state[items_cache]} ]]; then
    echo "$_items_cache" > "$_state"/items_cache
  fi
) &

if [[ -z "${state[items_cache]}" ]]; then
  wait
  state[items_cache]=$(cat "$_state"/items_cache)
fi


declare -a _items_title _items_id

while read id; do
  read title
  _items_id+=("$id;;;password")
  _items_id+=("$id;;;username")
  _items_id+=("$id;;;email")
  _items_title+=("$title | password")
  _items_title+=("$title | username")
  _items_title+=("$title | email")
done <<< "${state[items_cache]}"

if ret_item_id=$($_menu <<< $(printf '%s\n' "${_items_title[@]}")); then
  _item_id="${_items_id[$ret_item_id]%;;;*}"
  _item_field="${_items_id[$ret_item_id]##*;;;}"
  case $_item_field in
    username) _alt=email;;
    email)    _alt=username;;
  esac
  _out=$(call-pass item view --item-id "${_item_id}" --field "$_item_field") \
  || _out=$(call-pass item view --item-id "${_item_id}" --field "$_alt")
  $_type "$_out"
fi

wait

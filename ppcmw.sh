#!/usr/bin/env bash

readonly VERSION=0.3.1
readonly PROGNAME=ppcmw
readonly LICENSE=BW-NWv1

umask 077

# basic functions
log() { echo "$*" >&2; }
die() { log "$*"; exit 1; }
version() { log "$PROGNAME v$VERSION"; }

usage() {
  version
  log "
Usage: $PROGNAME [OPTIONS]

Options:
 -v, --version    Show version and exit
 -h, --help       Show this help and exit

Without options: show menu with Vault 'login'-type items (password/username/email).
"
  exit 0
}

# Process options
case "${1:-}" in
  -v|--version) version; exit 0;;
  -h|--help)    usage;;
esac

# config paths
cfg_conffile="${XDG_CONFIG_HOME:-"$HOME/.config"}/ppcmw.conf"
cfg_statedir="${XDG_STATE_HOME:-"$HOME/.local/state"}/ppcmw"

[[ -f "$cfg_conffile" ]] && source "$cfg_conffile"

cfg_PAT="$PAT"

# fail fast if cli not found
cmd_pcli=${pass_cli_bin:-"pass-cli"}
[[ -x $(command -v $cmd_pcli) ]] || die "Pass-cli binary not found: $cmd_pcli"

# fail if no session exists and no session can be created
if ! $cmd_pcli test; then
  if [[ -n "$cfg_PAT" ]]; then
    PROTON_PASS_PERSONAL_ACCESS_TOKEN="$cfg_PAT" \
    $cmd_pcli login \
    || die "Cannot log in with provided PAT"
  else
    die "No active session and PAT not provided!"
  fi
fi


# create or include state
mkdir -p "$cfg_statedir"
declare -A _state
for _st in vault_share_id items_cache; do
  [[ -f "$cfg_statedir/$_st" ]] && _state[$_st]=$(cat "$cfg_statedir/$_st")
done

# defaults
cfg_vault=${vault_name:-Personal}
cmd_menu=${menu_command:-fuzzel --dmenu --index --hide-before-typing}
cmd_type=${type_command:-wtype}

[[ -x $(command -v ${cmd_menu%% *}) ]] || die "Menu binary not found: ${cmd_menu%% *}"
[[ -x $(command -v ${cmd_type%% *}) ]] || die "Type binary not found: ${cmd_type%% *}"


# runtime functions

call-pass() {
  $cmd_pcli "$@" --output json --share-id "${_state[vault_share_id]}"
}


declare -A _pid

# cleanup on exit or signal
cleanup() {
  if [[ ${#_pid[@]} -gt 0 ]]; then
    kill "${_pid[@]}" &>/dev/null
  fi
  wait &>/dev/null
}
trap cleanup EXIT INT TERM

# cache vault share id if needed, in the background
(
  _id=$(
    $cmd_pcli vault list --output json |\
    jq -r \
      --arg vault "$cfg_vault" \
      '.vaults[] | select(.name == $vault) | .share_id'
  )

  if [[ "$_id" != "${_state[vault_share_id]}" ]]; then
    echo "$_id" > "$cfg_statedir/vault_share_id.tmp" && \
      mv "$cfg_statedir/vault_share_id.tmp" "$cfg_statedir/vault_share_id"
  fi
) &
_pid[cache_vault]=$!

# refresh items cache in the background
(
  _items_cache=$(
    call-pass item list --filter-type login --filter-state active |\
    jq -r '.items[] | (.id,.title)'
  )

  if [[ ${#_items_cache} -ne ${#_state[items_cache]} ]]; then
    echo "$_items_cache" > "$cfg_statedir/items_cache.tmp" && \
      mv "$cfg_statedir/items_cache.tmp" "$cfg_statedir/items_cache"
  fi
) &
_pid[cache_items]=$!

# wait for caches refresh if needed
if [[ -z "${_state[vault_share_id]}" ]]; then
  wait ${_pid[cache_vault]}
  _state[vault_share_id]=$(cat "$cfg_statedir/vault_share_id")
fi

if [[ -z "${_state[items_cache]}" ]]; then
  wait ${_pid[cache_items]}
  _state[items_cache]=$(cat "$cfg_statedir/items_cache")
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
done <<< "${_state[items_cache]}"

[[ ${#_items_title[@]} -eq 0 ]] && die "No login items found in vault"

_titles=$(printf '%s\n' "${_items_title[@]}")

if ret_item_id=$($cmd_menu <<< "$_titles"); then
  _item_id="${_items_id[$ret_item_id]%;;;*}"
  _item_field="${_items_id[$ret_item_id]##*;;;}"
  case $_item_field in
    username) _alt=email;;
    email)    _alt=username;;
  esac
  _out=$(call-pass item view --item-id "${_item_id}" --field "$_item_field") \
    || _out=$(call-pass item view --item-id "${_item_id}" --field "$_alt")

  [[ -n "$_out" ]] || die "No data found for $_item_field (or fallback $_alt)"
  $cmd_type "$_out"
fi

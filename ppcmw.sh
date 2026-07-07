#!/usr/bin/env bash

_conf="${XDG_CONFIG_HOME:-~/.config}/ppcmw.conf"

[[ -f "$_conf" ]] && source "$_conf"

_vault=${vault_name:-Personal}
_pcli=${pass_cli_bin:-"pass-cli"}

function die() {
  echo "$*" > /dev/stderr
  exit 1
}

function call-pass() {
  if [[ "$*" =~ "item list " ]]; then
    vopt=("$_vault")
  else
    vopt=("--vault-name" "$_vault")
  fi
  pass-cli "$@" --output json ${vopt[@]}
}

[[ -x $(command -v $_pcli) ]] || die "Pass-cli binary not found: $_pcli"

if [[ -z "${PAT}" ]]; then
  die "PAT not set!"
fi

$_pcli test || PROTON_PASS_PERSONAL_ACCESS_TOKEN="$PAT" $_pcli login

declare -a _items_title _items_id

while read id; do
  read title
  _items_id+=("$id")
  _items_title+=("$title")
done <<< $(call-pass item list --filter-type login --filter-state active | jq -r '.items[] | (.id,.title)')

ret_item_id=$(fuzzel --dmenu --index <<< $(printf '%s\n' "${_items_title[@]}"))

wtype $(call-pass item view --item-id "${_items_id[$ret_item_id]}" | jq -r '.item.content.content.Login.password')

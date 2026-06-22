#!/usr/bin/env bash
# Source from root ~/.bashrc — SyncApp shell commands (alongside K12Hunar).

_SYNC_ROOT="${SYNCAPP_ROOT:-/root/syncapp}"
[[ -d "$_SYNC_ROOT" ]] || return 0

info-sync()    { bash "$_SYNC_ROOT/scripts/vps/info.sh" "$@"; }
status-sync()  { bash "$_SYNC_ROOT/scripts/vps/status.sh" "$@"; }
logs-sync()    { bash "$_SYNC_ROOT/scripts/vps/logs.sh" "$@"; }
restart-sync() { bash "$_SYNC_ROOT/scripts/vps/restart.sh" "$@"; }
deploy-sync()  { bash "$_SYNC_ROOT/scripts/vps/deploy.sh" "$@"; }
health-sync()  { bash "$_SYNC_ROOT/scripts/vps/health.sh" "$@"; }

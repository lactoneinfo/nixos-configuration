#!/usr/bin/env bash
# NixOS リビルドは必ずこれ経由で。
# 理由: 自宅NASのSMBマウント定義 (/mnt/obsidian, /mnt/zotero) は
# /etc/nixos-private/private-hosts.nix にあり、common.nix が絶対パスで条件 import
# している。flake の pure eval だとこの絶対パスが読めず import が黙って落ち、
# マウントユニットごと消える (2026-08-22, 2026-09-10 に実際に発生)。
# --impure を付けると /etc/nixos-private/ を読めるようになり mount が復活する。
set -euo pipefail
exec sudo nixos-rebuild "${1:-switch}" --flake "$HOME/nixos-config#thinkpad" --impure "${@:2}"
#!/usr/bin/env bash
# System info tile — parity with what fastfetch shows in foot, so cockpit and
# terminal always agree on the same facts.
os_name=$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-NixOS}")
arch=$(uname -m)
host=$(hostname)
host_model=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
host_ver=$(cat /sys/class/dmi/id/product_version 2>/dev/null)
[ -z "$host_model" ] && host_model="unknown"
kernel=$(uname -r)
up=$(uptime -p 2>/dev/null | sed 's/^up //')
shell=$(basename "${SHELL:-sh}")
shell_ver=$(bash --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
pkgs=$(ls /run/current-system/sw/bin 2>/dev/null | wc -l)
gpu=$(lspci 2>/dev/null | grep -i 'vga\|3d controller' | head -1 | sed 's/.*: //')
[ -z "$gpu" ] && gpu="unknown"
swap=$(swapon --summary 2>/dev/null | tail -n +2)
[ -z "$swap" ] && swap_txt="Disabled" || swap_txt="Enabled"
locale_cur="${LANG:-en_US.UTF-8}"
ip4=$(ip -4 addr show scope global 2>/dev/null | awk '/inet /{print $2; exit}')
disp="unknown"
if command -v hyprctl >/dev/null 2>&1; then
  disp=$(hyprctl monitors 2>/dev/null | awk '/@/{print $1; exit}')
fi
font_line=$(grep '^font' ~/.config/foot/foot.ini 2>/dev/null | head -1 | sed 's/font=//')
[ -z "$font_line" ] && font_line="JetBrainsMono Nerd Font"

# CPU使用率(1秒差分)
read -r _ a b c idle1 rest < /proc/stat
t1=$((a+b+c+idle1)); i1=$idle1
sleep 0.4
read -r _ a b c idle2 rest < /proc/stat
t2=$((a+b+c+idle2)); i2=$idle2
dt=$((t2-t1)); di=$((i2-i1))
if [ "$dt" -gt 0 ]; then cpu=$(( (100*(dt-di))/dt )); else cpu=0; fi
cpu_model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//' | sed -E 's/\([^)]*\)//g' | tr -s ' ')
cpu_cores=$(nproc)
cpu_ghz=$(awk '/cpu MHz/{printf "%.2f", $4/1000; exit}' /proc/cpuinfo 2>/dev/null)

# メモリ
memtotal=$(grep MemTotal /proc/meminfo | awk '{print $2}')
memavail=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
memused=$((memtotal-memavail))
mempct=$(( 100*memused/memtotal ))
memused_g=$(awk "BEGIN{printf \"%.1f\", $memused/1048576}")
memtotal_g=$(awk "BEGIN{printf \"%.1f\", $memtotal/1048576}")

# ルートディスク使用率
read -r _ _ _ rootpct_raw _ < <(df -P / 2>/dev/null | tail -1)
rootpct=$(df -P / 2>/dev/null | tail -1 | awk '{gsub("%","",$5); print $5}')
rootfs=$(df -PT / 2>/dev/null | tail -1 | awk '{print $2}')

jq -n \
  --arg os "$os_name ($arch)" \
  --arg host "$host ($host_model $host_ver)" \
  --arg kernel "$kernel" \
  --arg uptime "$up" \
  --arg shell "$shell $shell_ver" \
  --arg display "$disp" \
  --arg wm "Hyprland" \
  --arg terminal "foot" \
  --arg font "$font_line" \
  --arg cpu_model "$cpu_model" \
  --argjson cpu_cores "$cpu_cores" \
  --arg cpu_ghz "${cpu_ghz:-?}" \
  --arg gpu "$gpu" \
  --arg swap "$swap_txt" \
  --arg locale "$locale_cur" \
  --arg ip "${ip4:-—}" \
  --arg rootfs "$rootfs" \
  --argjson cpu "$cpu" \
  --argjson mempct "$mempct" \
  --arg memused "$memused_g" \
  --arg memtotal "$memtotal_g" \
  --argjson rootpct "${rootpct:-0}" \
  --argjson pkgs "$pkgs" \
  '{os:$os, host:$host, kernel:$kernel, uptime:$uptime, shell:$shell, display:$display, wm:$wm, terminal:$terminal, font:$font, cpu_model:$cpu_model, cpu_cores:$cpu_cores, cpu_ghz:$cpu_ghz, gpu:$gpu, swap:$swap, locale:$locale, ip:$ip, rootfs:$rootfs, cpu:$cpu, mempct:$mempct, memused:$memused, memtotal:$memtotal, rootpct:$rootpct, pkgs:$pkgs}'

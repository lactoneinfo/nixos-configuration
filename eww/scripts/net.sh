#!/usr/bin/env bash
# ネットワーク: 既定IFのスループット + 疎通(ping) + 回線強度をJSON化。
iface=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')
[ -z "$iface" ] && iface=$(ls /sys/class/net 2>/dev/null | grep -v lo | head -1)
ip4=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet /{print $2; exit}')
[ -z "$ip4" ] && ip4="—"

rx1=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
tx1=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)
sleep 1
rx2=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
tx2=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)
down=$(awk "BEGIN{printf \"%.1f\", ($rx2-$rx1)/1024}")
up=$(awk "BEGIN{printf \"%.1f\", ($tx2-$tx1)/1024}")

# インターネット疎通チェック(Googleの8.8.8.8に1発ping、往復ms)
lat=$(ping -c1 -W1 8.8.8.8 2>/dev/null | awk -F'time=' '/time=/{print int($2)}')
if [ -n "$lat" ]; then online="up"; else online="down"; lat="—"; fi

# 回線種別/強度。無線ならSSID+強度%、有線ならlink speed(Mbps)。
kind="wired"; strength="—"; linkspeed="—"; ssid="—"
if [ -d "/sys/class/net/$iface/wireless" ]; then
  kind="wifi"
  q=$(awk "/$iface/"'{print $3}' /proc/net/wireless 2>/dev/null | tr -d '.')
  [ -n "$q" ] && strength=$(awk "BEGIN{printf \"%d\", $q*100/70}")
  if command -v iw >/dev/null 2>&1; then
    s=$(iw dev "$iface" link 2>/dev/null | awk -F': ' '/SSID/{print $2}')
    [ -n "$s" ] && ssid="$s"
  fi
else
  s=$(cat /sys/class/net/$iface/speed 2>/dev/null)
  [ -n "$s" ] && [ "$s" -gt 0 ] 2>/dev/null && linkspeed=$s
fi

printf '{"iface":"%s","ip":"%s","down":%s,"up":%s,"online":"%s","lat":"%s","kind":"%s","strength":"%s","linkspeed":"%s","ssid":"%s"}\n' \
  "$iface" "$ip4" "$down" "$up" "$online" "$lat" "$kind" "$strength" "$linkspeed" "$ssid"

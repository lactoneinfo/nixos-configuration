#!/usr/bin/env bash
# 個人のtailnet上の特定デバイスの接続状況+IPを一覧化。
# 実際のホスト名・表示名はこのファイル(git管理下)には一切書かず、
# ~/.private-rice/device-map.json (gitの外、このVM/実機にだけ手動で置く)
# から読む。個人情報をpublicリポジトリに残さないための分離。
MAP="$HOME/.private-rice/device-map.json"

if [ ! -f "$MAP" ]; then
  printf '{"state":"unconfigured","self_ip":"—","devices":[]}\n'
  exit 0
fi

be=$(tailscale status --json 2>/dev/null)
targets=$(jq -r '.[].target' "$MAP" 2>/dev/null)

if [ -z "$be" ]; then
  jq -c --slurpfile map "$MAP" -n \
    '{state:"stopped", self_ip:"—", devices:[$map[0][] | {name:.label, ip:"—", online:false, found:false}]}'
  exit 0
fi

state=$(echo "$be" | jq -r '.BackendState // "stopped"')
self_ip=$(echo "$be" | jq -r '.TailscaleIPs[0] // "—"')

result="["
sep=""
while IFS= read -r entry; do
  t=$(echo "$entry" | jq -r '.target')
  label=$(echo "$entry" | jq -r '.label')
  match=$(echo "$be" | jq -r --arg t "$t" '
    (.Peer // {}) | to_entries[] | .value
    | select((.HostName // "" | ascii_downcase | contains($t)) or (.DNSName // "" | ascii_downcase | contains($t)))
    | [(.TailscaleIPs[0] // "—"), (.Online // false)] | @tsv
  ' 2>/dev/null | head -1)
  if [ -n "$match" ]; then
    ip=$(echo "$match" | cut -f1)
    online=$(echo "$match" | cut -f2)
  else
    ip="—"; online="false"
  fi
  found=$([ "$ip" != "—" ] && echo true || echo false)
  result="$result$sep{\"name\":\"$label\",\"ip\":\"$ip\",\"online\":$online,\"found\":$found}"
  sep=","
done < <(jq -c '.[]' "$MAP")
result="$result]"

jq -n --arg state "$state" --arg self_ip "$self_ip" --argjson devices "$result" \
  '{state:$state, self_ip:$self_ip, devices:$devices}'

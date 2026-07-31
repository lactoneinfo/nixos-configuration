#!/bin/sh
# r/todayilearned の人気順(24時間以内)上位3件をJSONで返す。
# Reddit APIはUser-Agentが無いと429を返すことがあるため明示的に設定する。
out=$(curl -sf --max-time 8 -A "nixos-cockpit-study-widget/1.0" \
  "https://www.reddit.com/r/todayilearned/top.json?limit=3&t=day" 2>/dev/null)

if [ -z "$out" ]; then
  echo '[]'
  exit 0
fi

echo "$out" | jq -c '[.data.children[].data | {
  title: .title,
  url: (if (.url | test("reddit.com")) then ("https://reddit.com" + .permalink) else .url end),
  score: .score,
  comments: .num_comments
}]' 2>/dev/null || echo '[]'

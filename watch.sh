#!/usr/bin/env bash
# 螃蟹燒餅 — 盯著 Anthropic 的 Clawd 毛絨什麼時候重新開放。
#
# 盯兩扇門：
#   1. claude.dev/terminal/swag-status.json —— 網站自己的開關。off 陣列列的是「已關閉」的品項。
#   2. Brilliant 的登記表單 —— 關著的時候會把人轉去 /sorry。
#      廠商那邊可能先把表單打開、再去改網站的檔案，所以這扇門可能更早開。
#
# 三種情況會吵妳：
#   · 有品項從 off 名單裡消失        → 開了，鬧鐘等級，持續響
#   · 登記表單不再轉去 /sorry        → 開了，鬧鐘等級，持續響
#   · 名單裡冒出沒見過的新名字        → 他們在準備新東西（像 10/29 的 boo），普通等級
#
# 抓不到 / JSON 壞掉 / 格式不對 → 一律當作「沒變」，絕不誤報把人半夜吵醒。

set -uo pipefail

STATUS_URL="${STATUS_URL:-https://claude.dev/terminal/swag-status.json}"
TERMINAL_URL="${TERMINAL_URL:-https://claude.dev/terminal/}"
FORM_PLUSHIES="${FORM_PLUSHIES:-https://app.brilliantmade.com/r/claude-code-plushies}"
FORM_STICKERS="${FORM_STICKERS:-https://app.brilliantmade.com/r/claude-code-stickers}"
STATE_FILE="${STATE_FILE:-state.json}"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

log() { printf '%s | %s\n' "$(date -u '+%Y-%m-%d %H:%M:%SZ')" "$*"; }

# ---------- 推送 ----------
bark_push() {
  local title="$1" body="$2" level="${3:-active}" link="${4:-$TERMINAL_URL}"
  if [[ -z "${BARK_URL:-}" ]]; then
    log "（沒有 BARK_URL，跳過推送）$title — $body"
    return 0
  fi
  local base="${BARK_URL%/}"
  local key="${base##*/}"
  local host="${base%/*}"

  curl -fsS --max-time 20 -X POST "${host}/push" \
    -H 'Content-Type: application/json; charset=utf-8' \
    -d "$(jq -n --arg k "$key" --arg t "$title" --arg b "$body" --arg u "$link" --arg lv "$level" \
          '{device_key:$k, title:$t, body:$b, url:$u, level:$lv, sound:"alarm", volume:10, group:"clawd", isArchive:1}
           # 真警報的時候像來電一樣持續響，不是叮一聲就沉進通知中心
           + (if $lv == "critical" then {call:"1"} else {} end)')" \
    >/dev/null && log "推送已送出：$title" || log "推送失敗"
}

if [[ "${1:-}" == "--test" ]]; then
  bark_push "燒餅報到 🦀" "哨兵已上線，正在盯著螃蟹。這是一條測試推送。" "active"
  exit 0
fi

# ---------- 上次看到的樣子 ----------
if [[ -f "$STATE_FILE" ]] && jq -e . "$STATE_FILE" >/dev/null 2>&1; then
  prev_off="$(jq -r '.off[]?' "$STATE_FILE" | sort)"
  prev_form_p="$(jq -r '.form_plushies // "unknown"' "$STATE_FILE")"
  first_run=0
else
  prev_off=""
  prev_form_p="unknown"
  first_run=1
  log "沒有 state，這是第一次跑：只記錄現況，不推送。"
fi

# ---------- 第一扇門：狀態檔 ----------
curr_off=""
json_ok=0
body="$(curl -fsS --max-time 25 -A "$UA" "$STATUS_URL" 2>/dev/null)"
if [[ -z "$body" ]]; then
  log "抓不到狀態檔（網路錯誤或被擋），這一輪不判斷它"
elif ! echo "$body" | jq -e '.off | type == "array"' >/dev/null 2>&1; then
  log "狀態檔格式不對，不判斷：$(echo "$body" | head -c 200)"
else
  json_ok=1
  curr_off="$(echo "$body" | jq -r '.off[]' | tr -d '\r' | sort)"
  log "目前關閉的品項：$(echo "$curr_off" | tr '\n' ' ')"
fi

# ---------- 第二扇門：登記表單 ----------
# 轉去 /sorry = 關著；200 而且沒被轉走 = 開了；其他一律當作看不清楚。
check_form() {
  local url="$1" out code eff
  out="$(curl -sS -o /dev/null -L --max-time 20 -A "$UA" -w '%{http_code}|%{url_effective}' "$url" 2>/dev/null)" || { echo "unknown"; return; }
  code="${out%%|*}"
  eff="${out#*|}"
  if [[ "$eff" == *"/sorry"* ]]; then echo "closed"
  elif [[ "$code" == "200" ]]; then echo "open"
  else echo "unknown"; fi
}
curr_form_p="$(check_form "$FORM_PLUSHIES")"
log "毛絨登記表單：$curr_form_p"

# ---------- 比對 ----------
gone=()   # 從名單裡消失 = 開了
added=()  # 新冒出來的名字 = 他們在準備東西

if [[ $json_ok -eq 1 && $first_run -eq 0 ]]; then
  while IFS= read -r item; do
    [[ -z "$item" ]] && continue
    grep -qx "$item" <<<"$curr_off" || gone+=("$item")
  done <<<"$prev_off"

  while IFS= read -r item; do
    [[ -z "$item" ]] && continue
    grep -qx "$item" <<<"$prev_off" || added+=("$item")
  done <<<"$curr_off"
fi

form_opened=0
if [[ "$curr_form_p" == "open" && "$prev_form_p" != "open" && $first_run -eq 0 ]]; then
  form_opened=1
fi

# ---------- 吵人 ----------
pretty() {
  case "$1" in
    plushie)  echo "毛絨 /plushies" ;;
    stickers) echo "貼紙 /stickers" ;;
    *)        echo "$1" ;;
  esac
}

if [[ ${#gone[@]} -gt 0 ]]; then
  names=""
  for g in "${gone[@]}"; do names+="$(pretty "$g")、"; done
  names="${names%、}"
  log "！！開了：${gone[*]}"
  bark_push "🦀 螃蟹開了！${names}" \
            "立刻開 claude.dev/terminal 打 /plushies。上次是同一天領光的。國家選 China 會跳出身份證號那一欄。" \
            "critical"
elif [[ $form_opened -eq 1 ]]; then
  log "！！登記表單先開了"
  bark_push "🦀 登記表單開了！" \
            "Brilliant 的表單不再轉去 /sorry，直接進去填。網站那邊可能還沒更新。" \
            "critical" "$FORM_PLUSHIES"
fi

if [[ ${#added[@]} -gt 0 ]]; then
  log "名單裡多了新東西：${added[*]}"
  bark_push "👀 他們在準備新東西" \
            "狀態檔裡冒出沒見過的名字：${added[*]}。現在還關著，但這表示有東西在路上（上次 boo 就是萬聖節前兩天這樣出現的）。" \
            "active"
fi

if [[ ${#gone[@]} -eq 0 && ${#added[@]} -eq 0 && $form_opened -eq 0 ]]; then
  log "沒有變化，安靜。"
fi

# ---------- 記住這次看到的樣子 ----------
if [[ $json_ok -eq 1 ]]; then
  jq -n --argjson off "$(echo "$curr_off" | jq -R . | jq -s 'map(select(length>0))')" \
        --arg fp "$curr_form_p" \
        --arg at "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        '{off:$off, form_plushies:$fp, checked_at:$at}' > "$STATE_FILE"
  log "state 已更新"
fi

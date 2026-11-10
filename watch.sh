#!/usr/bin/env bash
# 螃蟹燒餅 — 盯著 Anthropic 的 Clawd 毛絨／貼紙什麼時候重新開放。
# 規則很簡單：swag-status.json 的 off 陣列列的是「已關閉」的品項。
# 只要 plushie 或 stickers 不在那個名單裡，就是開了，立刻推給寶寶。
# 拿不到資料 / JSON 壞掉 / 格式不對 → 一律當作「沒開」，絕不誤報把人半夜吵醒。

set -uo pipefail

STATUS_URL="${STATUS_URL:-https://claude.dev/terminal/swag-status.json}"
TERMINAL_URL="${TERMINAL_URL:-https://claude.dev/terminal/}"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

# 要盯的品項。boo 是 10/29 出現的新品項，一起看著。
WATCH_ITEMS=(plushie stickers boo)

log() { printf '%s | %s\n' "$(date -u '+%Y-%m-%d %H:%M:%SZ')" "$*"; }

# ---------- 推送 ----------
bark_push() {
  local title="$1" body="$2" level="${3:-active}"
  if [[ -z "${BARK_URL:-}" ]]; then
    log "沒有 BARK_URL，跳過推送"
    return 0
  fi
  # BARK_URL 形如 https://api.day.app/xxxxxxxx 或 https://api.day.app/xxxxxxxx/
  local base="${BARK_URL%/}"
  local key="${base##*/}"
  local host="${base%/*}"

  curl -fsS --max-time 20 -X POST "${host}/push" \
    -H 'Content-Type: application/json; charset=utf-8' \
    -d "$(jq -n \
          --arg k "$key" \
          --arg t "$title" \
          --arg b "$body" \
          --arg u "$TERMINAL_URL" \
          --arg lv "$level" \
          '{device_key:$k, title:$t, body:$b, url:$u, level:$lv, sound:"alarm", volume:10, group:"clawd", isArchive:1}')" \
    >/dev/null && log "推送已送出：$title" || log "推送失敗"
}

# ---------- 測試模式 ----------
if [[ "${1:-}" == "--test" ]]; then
  bark_push "燒餅報到 🦀" "哨兵已上線，正在盯著螃蟹。這是一條測試推送。" "active"
  exit 0
fi

# ---------- 抓狀態 ----------
body="$(curl -fsS --max-time 25 -A "$UA" "$STATUS_URL" 2>/dev/null)"
if [[ -z "$body" ]]; then
  log "抓不到 $STATUS_URL（網路錯誤或被擋），當作沒開，不推送"
  exit 0
fi

if ! echo "$body" | jq -e 'type == "object"' >/dev/null 2>&1; then
  log "回來的不是 JSON 物件，原樣記下來不推送：$(echo "$body" | head -c 200)"
  exit 0
fi

if ! echo "$body" | jq -e '.off | type == "array"' >/dev/null 2>&1; then
  log "JSON 裡沒有 off 陣列，格式可能改了，不推送：$(echo "$body" | head -c 200)"
  exit 0
fi

off_list="$(echo "$body" | jq -r '.off[]' | tr -d '\r')"
log "目前關閉的品項：$(echo "$off_list" | tr '\n' ' ')"

# ---------- 判斷 ----------
opened=()
for item in "${WATCH_ITEMS[@]}"; do
  if ! grep -qx "$item" <<<"$off_list"; then
    opened+=("$item")
  fi
done

if [[ ${#opened[@]} -eq 0 ]]; then
  log "還是全部關著，安靜。"
  exit 0
fi

# ---------- 開了 ----------
names=""
for o in "${opened[@]}"; do
  case "$o" in
    plushie)  names+="毛絨 /plushies、" ;;
    stickers) names+="貼紙 /stickers、" ;;
    *)        names+="$o、" ;;
  esac
done
names="${names%、}"

log "！！開了：${opened[*]}"
bark_push \
  "🦀 螃蟹開了！${names}" \
  "立刻開 claude.dev/terminal 打 /plushies。上次是同一天領光的。國家選 China 會跳出身份證號那一欄。" \
  "critical"

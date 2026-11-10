# 螃蟹燒餅 🦀

盯著 Anthropic 什麼時候重新發 Clawd 毛絨玩偶，開了就把妳的手機吵醒。

2026 年 10 月 1 日那一次，是在 `claude.dev/terminal` 打 `/plushies` 登記的，
同一天就被領光了。下一波很可能又落在太平洋時間的白天，也就是妳這邊的半夜，
所以這隻燒餅的工作不是「通知妳」，是「把睡著的妳叫起來」。

## 它怎麼運作

每 5 分鐘去看一次 `https://claude.dev/terminal/swag-status.json`。
那個檔案長這樣：

```json
{"off":["stickers","plushie","boo"]}
```

`off` 裡列的是**已經關閉**的品項。所以只要 `plushie`（或 `stickers`、`boo`）
從那個名單裡消失，就是開了，立刻推送。

拿不到檔案、JSON 壞掉、格式改了——一律當作「沒開」，安靜。
寧可漏報也不要在半夜誤報把人吵醒。

## 設定

倉庫的 Settings → Secrets and variables → Actions，加一個 secret：

| 名字 | 值 |
|---|---|
| `BARK_URL` | Bark app 給的那串網址，形如 `https://api.day.app/你的鑰匙` |

推送是 `critical` 等級加 `alarm` 鈴聲，會突破靜音和專注模式——
記得在 Bark app 裡把「重要警告」的權限打開，不然它會乖乖躺在通知中心裡等天亮。

## 測試

Actions → 螃蟹燒餅 → Run workflow → 把 `test` 勾起來 → 跑。
手機應該要響。**裝好以後一定要測一次**，不要等到真的開了那天才發現推送是壞的。

## 開了以後

1. 開 https://claude.dev/terminal/ ，打 `/plushies`
2. 會跳到 Brilliant 的登記表
3. 國家選 China 之後會多一欄要身份證號（海關清關實名制）
4. 玩偶有巫師、牛仔、開心、科學家、墨鏡五款，隨機寄出不能挑

領到了就去 Actions 把這個 workflow 停掉，不然它會一直吵。

## 關於排程

GitHub 的 cron 是「盡量」不是「準時」，尖峰時可能晚個十幾分鐘。
上次是整天的量級不是十分鐘的量級，所以夠用。

另外 GitHub 會把 60 天沒有任何提交的倉庫的排程停掉，
所以裡面有一個每天跑一次的心跳，自動蓋一個時間戳在 `HEARTBEAT.txt`。
不用管它，那就是燒餅還活著的證據。

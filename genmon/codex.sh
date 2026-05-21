#!/usr/bin/env bash
# Ref: https://gist.github.com/hqppyz/f6bda38865e45e1d57b7f8e280e6bab4
# Requires: curl, jq, and CHATGPT_CODEX_AUTH as an env var with your Bearer token
# Vibe coded with claude.ai

readonly DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly NO_CONNECTION_ICON="${DIR}/icons/broken-connection.svg"
readonly AVAILABLE_ICON="${DIR}/icons/codex.svg"
readonly WAIT_FIVE_H_ICON="${DIR}/icons/codex-yellow.svg"
readonly WAIT_WEEK_ICON="${DIR}/icons/codex-red.svg"

readonly API="https://chatgpt.com/backend-api/wham/usage"

icon_text() {
  local ICON="$1"
  local TEXT="$2"

  if [[ -f "$ICON" ]] && file -b "$ICON" | grep -qE 'PNG|SVG'; then
    echo "<img>${ICON}</img><txt> ${TEXT}</txt>"
  else
    echo "<txt>${TEXT}</txt>"
  fi
}

reset_text() {
  local SECONDS="$1"
  local TIME="$2"

  if (( SECONDS < 3600 )); then
    local MINUTES=$(( (SECONDS + 59) / 60 ))

    if (( MINUTES == 1 )); then
      echo "resets in ${MINUTES} minute (${TIME})"
    else
      echo "resets in ${MINUTES} minutes (${TIME})"
    fi
  elif (( SECONDS <= 86400 )); then
    local HALF_HOURS=$(( (SECONDS + 1799) / 1800 ))
    local HOURS=$(( HALF_HOURS / 2 ))

    if (( HALF_HOURS % 2 == 0 )); then
      if (( HOURS == 1 )); then
        echo "resets in ${HOURS} hour (${TIME})"
      else
        echo "resets in ${HOURS} hours (${TIME})"
      fi
    else
      echo "resets in ${HOURS}.5 hours (${TIME})"
    fi
  else
    local HALF_DAYS=$(( (SECONDS + 43199) / 43200 ))
    local DAYS=$(( HALF_DAYS / 2 ))

    if (( HALF_DAYS % 2 == 0 )); then
      if (( DAYS == 1 )); then
        echo "resets in ${DAYS} day (${TIME})"
      else
        echo "resets in ${DAYS} days (${TIME})"
      fi
    else
      echo "resets in ${DAYS}.5 days (${TIME})"
    fi
  fi
}

if [[ -z "$CHATGPT_CODEX_AUTH" || $1 == "--disable" ]]; then
  echo -e "$(icon_text "$WAIT_WEEK_ICON" " DISABLED")"

  [[ -z "$CHATGPT_CODEX_AUTH" ]] && {
    echo "<tool>TOKEN MISSING</tool>"
    exit 1
  }

  echo "<tool>SCRIPT DISABLED</tool>"
  exit 0;
fi

if ! DATA=$(curl -sSf "$API" -H "authorization: Bearer $CHATGPT_CODEX_AUTH" 2>&1); then
  echo -e "$(icon_text "$NO_CONNECTION_ICON" "???%/???%")"
  echo "<tool>$DATA</tool>"
  exit 1
fi

FIVE_H_USED=$(echo "$DATA" | jq '.rate_limit.primary_window.used_percent')
WEEKLY_USED=$(echo "$DATA" | jq '.rate_limit.secondary_window.used_percent')
FIVE_H_RESET=$(echo "$DATA" | jq '.rate_limit.primary_window.reset_at')
WEEKLY_RESET=$(echo "$DATA" | jq '.rate_limit.secondary_window.reset_at')
FIVE_H_RESET_AFTER=$(echo "$DATA" | jq '.rate_limit.primary_window.reset_after_seconds')
WEEKLY_RESET_AFTER=$(echo "$DATA" | jq '.rate_limit.secondary_window.reset_after_seconds')

FIVE_H_LEFT=$(( 100 - FIVE_H_USED ))
WEEKLY_LEFT=$(( 100 - WEEKLY_USED ))

FIVE_H_TIME=$(date -d "@${FIVE_H_RESET}" '+%H:%M')
WEEKLY_TIME=$(date -d "@${WEEKLY_RESET}" '+%H:%M on %d %b')

FIVE_H_RESET_TEXT=$(reset_text "$FIVE_H_RESET_AFTER" "$FIVE_H_TIME")
WEEKLY_RESET_TEXT=$(reset_text "$WEEKLY_RESET_AFTER" "$WEEKLY_TIME")

if (( WEEKLY_LEFT <= 0 )); then
  OUT=$(icon_text "$WAIT_WEEK_ICON" "${FIVE_H_LEFT}%/${WEEKLY_LEFT}%")
elif (( FIVE_H_LEFT <= 0 )); then
  OUT=$(icon_text "$WAIT_FIVE_H_ICON" "${FIVE_H_LEFT}%/${WEEKLY_LEFT}%")
else
  OUT=$(icon_text "$AVAILABLE_ICON" "${FIVE_H_LEFT}%/${WEEKLY_LEFT}%")
fi

TOOLTIP="<tool>"
TOOLTIP+="┌ Codex usage\n"
TOOLTIP+="├─ 5h limit:    ${FIVE_H_LEFT}% left  ${FIVE_H_RESET_TEXT}\n"
TOOLTIP+="└─ Weekly:      ${WEEKLY_LEFT}% left  ${WEEKLY_RESET_TEXT}"
TOOLTIP+="</tool>"

echo -e "$OUT"
echo -e "$TOOLTIP"

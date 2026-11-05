#!/usr/bin/env bash
# Claude Code status line, three lines:
#   1: cost in USD centered, 5h limit bar right
#   2: daily budget bar right
#   3: notif mode left, [model - effort] badge centered, weekly limit bar right
# Cost reads "<since last prompt> / <session total>", colored by its share of
# the daily budget: the weekly limit left, split evenly over the days left.
source /opt/dotfiles/scripts/require-colors

input=$(cat)

# bar <left %> <mark %> <mark color> <digits>: 20-cell bar, 5% per cell. Full
# cells are what is LEFT, colored green/brown/red as it drains; right after
# them <mark %> (what this session used) in <mark color>, at least one cell
# when above 0. Then the left % padded to <digits>; below 0 means over.
bar() {
  local left=${1%.*} mark=${2%.*} filled marked color i cells=""
  filled=$(( (left + 2) / 5 )); (( filled < 0 )) && filled=0; (( filled > 20 )) && filled=20
  marked=$(( (mark + 2) / 5 )); (( mark > 0 && marked == 0 )) && marked=1
  (( marked > 20 - filled )) && marked=$(( 20 - filled ))
  if   (( left <= 20 )); then color=$C_RED
  elif (( left <= 50 )); then color=$C_BROWN
  else                        color=$C_GREEN; fi
  for (( i = 0; i < filled; i++ )); do cells+="█"; done
  cells+="$F_RESET$3"
  for (( i = 0; i < marked; i++ )); do cells+="▓"; done
  cells+="$F_RESET$C_NEUTRAL_3"
  for (( i = filled + marked; i < 20; i++ )); do cells+="░"; done
  printf '%s%s%s  %s%*d%%%s' "$color" "$cells" "$F_RESET" "$color" "${4:-1}" "$left" "$F_RESET"
}

# until_reset <epoch>: time left until reset, e.g. 2h13m or 3d4h.
until_reset() {
  local s=$(( $1 - $(date +%s) ))
  (( s < 0 )) && s=0
  if (( s >= 86400 )); then printf '%dd%dh' $((s / 86400)) $((s % 86400 / 3600))
  else printf '%dh%02dm' $((s / 3600)) $((s % 3600 / 60)); fi
}

# Badge: [model - effort]; a missing part is dropped, both missing hides it.
badge=$(printf '%s' "$input" | jq -r '
  [.model.display_name // .model.id, .effort.level]
  | map(select(. != null and . != "")) | join(" - ")')
center=""
[ -n "$badge" ] && center="${F_BOLD}${C_ORANGE}[${badge}]${F_RESET}"

# Notification mode (per project, set by the notif mod in mods/notif): read
# from the transcript folder; missing, a symlink or invalid means off.
left=""
tp=$(printf '%s' "$input" | jq -r '.transcript_path // ""')
if [ -n "$tp" ]; then
  nf="$(dirname "$tp")/notif-mode" nmode=""
  [ -f "$nf" ] && [ ! -L "$nf" ] && nmode=$(head -c 16 "$nf" | tr -cd 'a-z')
  case "$nmode" in ask|all) ;; *) nmode=off ;; esac
  ncolor=$C_YELLOW; [ "$nmode" = off ] && ncolor=$C_NEUTRAL_3
  left="${ncolor}⏵⏵ notif ${nmode}${F_RESET}"
fi

read -r h5 h5r d7 d7r < <(printf '%s' "$input" | jq -r '[
  .rate_limits.five_hour.used_percentage // "", .rate_limits.five_hour.resets_at // "",
  .rate_limits.seven_day.used_percentage // "", .rate_limits.seven_day.resets_at // ""
] | map(tostring | if . == "" then "-" else . end) | join(" ")')

# Session baselines, kept per session next to the transcript as
# "<promptId> <cost at prompt> <5h % at start> <wk % at start>". The limit
# baselines are the values at the session's first run; the cost baseline is
# reset on each new prompt (see below). Before any prompt it is 0, so the
# first figure shows init costs. A limit that resets (used % drops) rebases
# to 0.
total=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // ""')
h5n=$h5; [ "$h5n" = "-" ] && h5n=""
wkn=$d7; [ "$wkn" = "-" ] && wkn=""
pc=0 sh=$h5n sw=$wkn
# rebase <current> <base>: 0 when the limit window reset, else the base.
rebase() { awk -v c="${1:-0}" -v b="${2:-0}" 'BEGIN { print (c + 0 < b + 0) ? 0 : b }'; }
if [ -n "$tp" ] && [ -f "$tp" ]; then
  # Only prompts that start a turn count: messages queued mid-turn and system
  # prompts (task notifications, channel and peer messages) keep the baseline.
  pid=$(grep -E '"promptSource":"(typed|suggestion_accepted|sdk)"' "$tp" | tail -1 |
    grep -o '"promptId":"[^"]*"' | cut -d'"' -f4)
  cf="${tp%.jsonl}.statusline" spid=""
  [ -f "$cf" ] && [ ! -L "$cf" ] && read -r spid pc sh sw < "$cf"
  [ "$spid" = "-" ] && spid=""
  sh=${sh:-$h5n} sw=${sw:-$wkn}
  [ "$pid" != "$spid" ] && pc=${total:-0}
  [ -z "$pid" ] && pc=0
  [ -n "$h5n" ] && sh=$(rebase "$h5n" "$sh")
  [ -n "$wkn" ] && sw=$(rebase "$wkn" "$sw")
  printf '%s %s %s %s\n' "${pid:--}" "${pc:-0}" "${sh:-0}" "${sw:-0}" > "$cf"
fi

# Daily budget, shared by all sessions in $XDG_STATE_HOME/claude/statusline-day as
# "<date> <wk % at day start> <budget %>". On the first run of a day the budget
# is the weekly limit left, split evenly over the days until the weekly reset
# (today included). A weekly reset during the day starts the day over.
WK_PCT_PER_USD=0.59 # weekly % per dollar, calibrated from one session (rough)
budget=""
if [ -n "$wkn" ]; then
  df="${XDG_STATE_HOME:-$HOME/.local/state}/claude/statusline-day" dday="" dwk="" dbud=""
  [ -f "$df" ] && [ ! -L "$df" ] && read -r dday dwk dbud < "$df"
  now=$(date +%s) day=$(date +%F)
  if [ "$dday" != "$day" ] || [ -z "$dbud" ] || awk -v c="$wkn" -v b="$dwk" 'BEGIN { exit !(c + 0 < b + 0) }'; then
    dwk=$wkn
    dbud=$(awk -v w="$wkn" -v r="${d7r/-/}" -v n="$now" 'BEGIN {
      d = (r == "") ? 7 : int((r - n + 86399) / 86400); if (d < 1) d = 1
      printf "%.3f", (100 - w) / d }')
    mkdir -p "${df%/*}"
    printf '%s %s %s\n' "$day" "$dwk" "$dbud" > "$df"
  fi
  budget=$dbud
fi

# heat <x> <blue from> <green from> <orange from> <red from>: the C_HEAT
# level for <x>. Violet is trivial (zero included), blue normal, green room to
# breathe, orange should try to stop or compact, red is STOP.
heat() {
  awk -v x="$1" -v b="$2" -v g="$3" -v o="$4" -v d="$5" 'BEGIN {
    print (x < b) ? 0 : (x < g) ? 1 : (x < o) ? 2 : (x < d) ? 3 : 4 }'
}

# paint <level> <text>: <text> in C_HEAT<level>.
paint() {
  local c="C_HEAT$1"
  printf '%s%s%s' "${!c}" "$2" "$F_RESET"
}

# Thresholds (blue, green, orange, red from) as a share of the daily budget.
# With about $24 a day: a prompt goes orange at $0.50 and red at $1.20, a
# session orange at $2.40 and red at $4.80.
T_PROMPT="0.002 0.005 0.02 0.05"
T_SESSION="0.01 0.03 0.1 0.2"

# Daily budget in dollars; without limits, $24.
budget_usd=$(awk -v b="${budget:-14.2}" -v k="$WK_PCT_PER_USD" 'BEGIN { print b / k }')

# level <usd> <thresholds>: heat level of <usd> as a share of the daily budget.
level() {
  heat "$(awk -v x="$1" -v d="$budget_usd" 'BEGIN { print x / d }')" $2
}

usd="" slevel=0
if [ -n "$total" ]; then
  a=$(awk -v n="$total" -v p="${pc:-0}" 'BEGIN { d = n - p; printf "%.2f", d < 0 ? 0 : d }')
  b=$(awk -v n="$total" 'BEGIN { printf "%.2f", n }')
  slevel=$(level "$b" "$T_SESSION")
  usd="${C_CYAN}\$${F_RESET} $(paint "$(level "$a" "$T_PROMPT")" "$a") ${C_NEUTRAL_3}/${F_RESET} $(paint "$slevel" "$b")"
fi
mark_color="C_HEAT$slevel"; mark_color=${!mark_color}

# Bars: 5h left with this session's 5h use marked; today's budget left
# (dd) with this session's weekly use marked, as a share of the budget; weekly
# left with this session's weekly use marked. The 5h bar has the time to its
# reset; dd and wk share a 2x2 matrix of times, now and the weekly reset, as
# weekdays over times, with the time left between them. Times and percents are padded so the bars align.
t5="" l5="" ldd="" lwk="" mdd="" mwk=""
if [ -n "$h5n" ]; then
  [ "$h5r" != "-" ] && t5=$(until_reset "$h5r")
  l5=$(awk -v u="$h5n" 'BEGIN { printf "%d", 100 - u }')
fi
if [ -n "$budget" ]; then
  ldd=$(awk -v n="$wkn" -v d="$dwk" -v b="$budget" 'BEGIN { printf "%d", 100 * (b - (n - d)) / b }')
fi
if [ -n "$wkn" ]; then
  lwk=$(awk -v u="$wkn" 'BEGIN { printf "%d", 100 - u }')
  # Between the columns, the time left to the reset: days over hours.
  rday="---" rtime="--:--" ld="-" lh="-"
  if [ "$d7r" != "-" ]; then
    rday=$(date -d "@$d7r" +%a) rtime=$(date -d "@$d7r" +%H:%M)
    s=$(( d7r - $(date +%s) )); (( s < 0 )) && s=0
    ld="$(( s / 86400 ))d" lh="$(( s % 86400 / 3600 ))h"
  fi
  gw=$(( ${#ld} > ${#lh} ? ${#ld} : ${#lh} ))
  # ╲ over ╱ draws one > across both lines.
  mdd=" $(date +%a)  ╲ $(printf '%*s' "$gw" "$ld") ╲  $rday " mwk="$(date +%H:%M) ╱ $(printf '%*s' "$gw" "$lh") ╱ $rtime"
fi
tw=$(( ${#t5} > ${#mdd} ? ${#t5} : ${#mdd} ))
pw=${#l5}; (( ${#ldd} > pw )) && pw=${#ldd}; (( ${#lwk} > pw )) && pw=${#lwk}
# Slashes a step fainter than the times, colored after tw is measured.
mdd=${mdd//╲/$C_NEUTRAL_4╲$C_NEUTRAL_2} mwk=${mwk//╱/$C_NEUTRAL_4╱$C_NEUTRAL_2}
s5=""
if [ -n "$h5n" ]; then
  m=$(awk -v n="$h5n" -v s="${sh:-0}" 'BEGIN { print n - s }')
  s5="${C_NEUTRAL_2}$(printf '%*s' "$tw" "$t5")${F_RESET}  ${C_CYAN}5h${F_RESET}  $(bar "$l5" "$m" "$mark_color" "$pw")"
fi
sdd=""
if [ -n "$budget" ]; then
  m=$(awk -v n="$wkn" -v s="${sw:-0}" -v b="$budget" 'BEGIN { print 100 * (n - s) / b }')
  sdd="${C_NEUTRAL_2}$(printf '%*s' "$tw" "$mdd")${F_RESET}  ${C_CYAN}dd${F_RESET}  $(bar "$ldd" "$m" "$mark_color" "$pw")"
fi
swk=""
if [ -n "$wkn" ]; then
  m=$(awk -v n="$wkn" -v s="${sw:-0}" 'BEGIN { print n - s }')
  swk="${C_NEUTRAL_2}$(printf '%*s' "$tw" "$mwk")${F_RESET}  ${C_CYAN}wk${F_RESET}  $(bar "$lwk" "$m" "$mark_color" "$pw")"
fi

# Layout: pad by terminal width minus the visible length of each part.
# Width from the controlling tty minus MARGIN: Claude Code pads the status line,
# so the full tty width overflows and cuts the end. Raise MARGIN if still cut.
# Unknown width falls back to a 2-space gap. UTF-8 locale so █/░ count as 1.
MARGIN=4
export LC_ALL=C.UTF-8
cols=$({ stty size </dev/tty; } 2>/dev/null | cut -d' ' -f2)
[ -z "$cols" ] && cols=${COLUMNS:-0}
# display_width <text>: how many terminal cells <text> takes once drawn. Every
# width the layout uses goes through here. Known to be off (strips only SGR
# escapes, counts code points, not cells); to be fixed in this one place.
display_width() {
  local t
  t=$(printf '%s' "$1" | sed 's/\x1b\[[0-9;]*m//g')
  printf '%d' "${#t}"
}
width=$(( cols - MARGIN ))

# row <left> <center> <right>: one line, center centered, right right-aligned.
# Starts with a reset escape so leading padding is not trimmed as whitespace.
row() {
  local lw cw rw g1 g2
  lw=$(display_width "$1"); cw=$(display_width "$2"); rw=$(display_width "$3")
  g1=$(( (width - cw) / 2 - lw )); (( g1 < 2 )) && g1=2
  g2=$(( width - lw - g1 - cw - rw )); (( g2 < 2 )) && g2=2
  printf '%s%s%*s%s%*s%s' "$F_RESET" "$1" "$g1" '' "$2" "$g2" '' "$3"
}
row "" "$usd" "$s5"
printf '\n'
row "" "" "$sdd"
printf '\n'
row "$left" "$center" "$swk"

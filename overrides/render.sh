#!/usr/bin/env bash
# Bundle sites/<domain>/{style.css,script.js} into one userscript. Usage: render.sh [output-path]
# Dependencies: jq

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITES="$DIR/sites"
OUT="${1:-$DIR/overrides.user.js}"
URL="https://overrides.montanari.cc/overrides.user.js"

command -v jq >/dev/null || { echo "ERROR: jq is required" >&2; exit 1; }

domains=()
if [ -d "$SITES" ]; then
  for d in "$SITES"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    if [[ ! "$name" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$ ]]; then
      echo "ERROR: sites/$name is not a lowercase domain name" >&2
      exit 1
    fi
    [ -f "$d/style.css" ] || [ -f "$d/script.js" ] || { echo "WARNING: sites/$name has no style.css or script.js, skipped" >&2; continue; }
    domains+=("$name")
  done
fi

# Minute-level stamps could collide on two renders in one minute; seconds keep @version strictly increasing
version="$(date -u +%Y.%-m.%-d.%H%M%S)"

render() {
  cat <<EOF
// ==UserScript==
// @name         Overrides
// @namespace    https://overrides.montanari.cc
// @description  Per-domain CSS and JS overrides from the dotfiles repo
// @version      $version
// @updateURL    $URL
// @downloadURL  $URL
// @run-at       document-start
// @grant        GM_addStyle
// @grant        GM.addStyle
// @grant        unsafeWindow
EOF
  if [ ${#domains[@]} -eq 0 ]; then
    # A script with no @match is rejected or runs nowhere depending on the manager; keep it installable
    echo "// @match        $URL"
  fi
  for name in "${domains[@]}"; do
    echo "// @match        *://$name/*"
    echo "// @match        *://*.$name/*"
  done
  cat <<'EOF'
// ==/UserScript==

(() => {
  const host = location.hostname;
  const matches = (domain) => host === domain || host.endsWith('.' + domain);

  const addStyle = (css) => {
    if (typeof GM_addStyle === 'function') return GM_addStyle(css);
    if (typeof GM !== 'undefined' && GM.addStyle) return GM.addStyle(css);
    const el = document.createElement('style');
    el.textContent = css;
    (document.head || document.documentElement).appendChild(el);
  };

  const run = (domain, type, fn) => {
    console.log(`[overrides] registering ${type} for ${domain}`);
    try {
      fn();
    } catch (e) {
      console.error(`[overrides] ${type} for ${domain}:`, e);
    }
  };
EOF
  for name in "${domains[@]}"; do
    local d="$SITES/$name" jsname
    jsname="'$name'"
    printf '\n  // %s\n  if (matches(%s)) {\n' "$name" "$jsname"
    if [ -f "$d/style.css" ]; then
      printf '    run(%s, %s, () => addStyle(%s));\n' "$jsname" "'style'" "$(jq -Rs . < "$d/style.css")"
    fi
    if [ -f "$d/script.js" ]; then
      printf '    run(%s, %s, function () {\n' "$jsname" "'script'"
      cat "$d/script.js"
      # Newline guards against a trailing // comment swallowing the closer
      printf '\n    });\n'
    fi
    printf '  }\n'
  done
  printf '})();\n'
}

OUTDIR="$(dirname "$OUT")"
mkdir -p "$OUTDIR"
TMP="$(mktemp "$OUTDIR/.overrides.XXXXXX")"
trap 'rm -f "$TMP"' EXIT
render > "$TMP"
chmod 644 "$TMP"
mv -f "$TMP" "$OUT"
trap - EXIT

echo "Rendered ${#domains[@]} site(s) to $OUT (version $version)"

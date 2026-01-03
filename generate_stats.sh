#!/usr/bin/env bash
# generate_stats.sh – creates a stats markdown fragment and injects it into README.md
# Requirements: git, cloc (optional), du, wc, sed

# Helper to URL‑encode a string (for badge URLs)
urlencode() {
  local LANG=C i c e=""
  for ((i=0;i<${#1};i++)); do
    c=${1:i:1}
    case "$c" in
      [a-zA-Z0-9.~_-]) e+="$c" ;;
      *) e+="%$(printf "%02X" "'${c}")" ;;
    esac
  done
  echo "$e"
}

# Compute metrics
COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo 0)
LAST_COMMIT=$(git log -1 --format=%cd --date=short 2>/dev/null || echo "N/A")
# Approximate total coding hours – assume 8 h per commit (simple heuristic)
HOURS=$((COMMITS * 8))

# Lines of code and language breakdown (using cloc if available)
if command -v cloc >/dev/null 2>&1; then
  CLOCDATA=$(cloc --json .)
  LOC=$(echo "$CLOCDATA" | python - <<'PY'
import sys, json
j = json.load(sys.stdin)
print(j.get('SUM', {}).get('code', 0))
PY
  )
  LANGS=$(echo "$CLOCDATA" | python - <<'PY'
import sys, json
j = json.load(sys.stdin)
langs = j.get('languages', {})
# sort by code lines, take top 3
sorted_lang = sorted(langs.items(), key=lambda kv: kv[1].get('code', 0), reverse=True)[:3]
print(' | '.join([k for k, _ in sorted_lang]))
PY
  )
else
  LOC=$(git ls-files | xargs wc -l | tail -1 | awk '{print $1}')
  LANGS="N/A"
fi

FILE_COUNT=$(git ls-files | wc -l)
REPO_SIZE=$(du -sh . | cut -f1)

# Build badge URLs (dark‑mode style)
style="flat-square"
labelColor="2D2D2D"
badge_commits="https://img.shields.io/badge/Commits-$(urlencode $COMMITS)-blue?style=$style&logo=git&logoColor=white&labelColor=$labelColor"
badge_hours="https://img.shields.io/badge/Hours-$(urlencode $HOURS)-orange?style=$style&logo=clock&logoColor=white&labelColor=$labelColor"
badge_loc="https://img.shields.io/badge/LOC-$(urlencode $LOC)-brightgreen?style=$style&logo=code&logoColor=white&labelColor=$labelColor"
badge_files="https://img.shields.io/badge/Files-$(urlencode $FILE_COUNT)-yellow?style=$style&logo=file&logoColor=white&labelColor=$labelColor"
badge_langs="https://img.shields.io/badge/Languages-$(urlencode $LANGS)-red?style=$style&logo=language&logoColor=white&labelColor=$labelColor"
badge_last="https://img.shields.io/badge/Last%20Commit-$(urlencode $LAST_COMMIT)-lightgrey?style=$style&logo=git&logoColor=white&labelColor=$labelColor"
badge_size="https://img.shields.io/badge/Size-$(urlencode $REPO_SIZE)-purple?style=$style&logo=folder&logoColor=white&labelColor=$labelColor"

# Write stats fragment
cat > stats.md <<EOF
---
## 📊 Project Stats

![Commits]($badge_commits)
![Hours]($badge_hours)
![Lines of Code]($badge_loc)
![Files]($badge_files)
![Languages]($badge_langs)
![Last Commit]($badge_last)
![Size]($badge_size)

---
EOF

# Insert or replace placeholder in README
PLACEHOLDER="<!-- STATS_PLACEHOLDER -->"
if grep -q "$PLACEHOLDER" README.md; then
  # Replace the placeholder line with the contents of stats.md
  sed -i "/$PLACEHOLDER/c\\
$(sed 's/[&/]/\\&/g' stats.md)" README.md
else
  echo "Placeholder not found – you can manually copy stats.md into your README where desired." >&2
fi

echo "Stats generated and injected into README.md."

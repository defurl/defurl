#!/usr/bin/env bash
# generate_stats.sh – creates a stats markdown fragment and injects it into README.md

urlencode() {
  local LANG=C i c e=""
  for ((i=0; i<${#1}; i++)); do
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
# Estimate 8h per commit (simple heuristic)
HOURS=$((COMMITS * 8))

# Lines of code and language breakdown
if command -v cloc >/dev/null 2>&1; then
  CLOCDATA=$(cloc --json .)
  LOC=$(echo "$CLOCDATA" | python -c "import sys, json; j=json.load(sys.stdin); print(j.get('SUM', {}).get('code', 0))")
  LANGS=$(echo "$CLOCDATA" | python -c "import sys, json; j=json.load(sys.stdin); langs=j.get('languages', {}); sorted_lang=sorted(langs.items(), key=lambda kv: kv[1].get('code', 0), reverse=True)[:3]; print(' | '.join([k for k, _ in sorted_lang]))")
else
  LOC=$(git ls-files | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
  [ -z "$LOC" ] && LOC=0
  LANGS="N/A"
fi

FILE_COUNT=$(git ls-files | wc -l)
REPO_SIZE=$(du -sh . | cut -f1)

# Build badge URLs (dark‑mode style)
style="flat-square"
labelColor="2D2D2D"

# Using "_" instead of "%20" for the label part to avoid Shields.io 404s
badge_commits="https://img.shields.io/badge/Commits-$(urlencode $COMMITS)-blue?style=$style&logo=git&logoColor=white&labelColor=$labelColor"
badge_hours="https://img.shields.io/badge/Hours-$(urlencode $HOURS)-orange?style=$style&logo=clock&logoColor=white&labelColor=$labelColor"
badge_loc="https://img.shields.io/badge/LOC-$(urlencode $LOC)-brightgreen?style=$style&logo=code&logoColor=white&labelColor=$labelColor"
badge_files="https://img.shields.io/badge/Files-$(urlencode $FILE_COUNT)-yellow?style=$style&logo=file&logoColor=white&labelColor=$labelColor"
badge_langs="https://img.shields.io/badge/Languages-$(urlencode $LANGS)-red?style=$style&logo=language&logoColor=white&labelColor=$labelColor"
badge_last="https://img.shields.io/badge/Last_Commit-$(urlencode $LAST_COMMIT)-lightgrey?style=$style&logo=git&logoColor=white&labelColor=$labelColor"
badge_size="https://img.shields.io/badge/Size-$(urlencode $REPO_SIZE)-purple?style=$style&logo=folder&logoColor=white&labelColor=$labelColor"

# Write stats fragment
cat > stats.md <<EOF
<!-- STATS_START -->
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
<!-- STATS_END -->
EOF

# Inject into README using Python
# This script will replace anything between <!-- STATS_START --> and <!-- STATS_END --> 
# OR replace the initial <!-- STATS_PLACEHOLDER -->
python -c '
import sys, os, re
readme_file = "README.md"
stats_file = "stats.md"
placeholder = "<!-- STATS_PLACEHOLDER -->"

if not os.path.exists(readme_file) or not os.path.exists(stats_file):
    sys.exit(0)

with open(readme_file, "r", encoding="utf-8") as f:
    content = f.read()

with open(stats_file, "r", encoding="utf-8") as f:
    stats = f.read()

# Pattern to find existing stats block or the placeholder
pattern = r"<!-- STATS_START -->.*?<!-- STATS_END -->|<!-- STATS_PLACEHOLDER -->"

if re.search(pattern, content, re.DOTALL):
    new_content = re.sub(pattern, stats, content, flags=re.DOTALL)
    with open(readme_file, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("Stats updated successfully.")
else:
    print("No placeholder or stats block found in README.md.")
'
echo "Done."

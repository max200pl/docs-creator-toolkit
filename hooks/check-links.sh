#!/usr/bin/env bash
# PostToolUse(Write|Edit): flag broken cross-refs in .md / .mmd files.
#
# Two entry modes:
#   - stdin JSON (PostToolUse hook call — reads tool_input.file_path)
#   - CLI:  check-links.sh <file>            — scan one file
#           check-links.sh --all             — scan entire repo
#           check-links.sh --dir <path>      — scan a directory recursively
#           check-links.sh --layer-check     — public-→-.claude/ ref check only (full repo)
#
# Warnings emitted as `[WARN] file:line → target (reason)`. Exit 0 clean, 2 warnings.
# When invoked as a hook, output is wrapped in JSON systemMessage.
set -u

MODE_HOOK=0
MODE_ALL=0
MODE_DIR=""
MODE_FILE=""
MODE_LAYER=0

# ---------- arg parsing ----------
case "${1:-}" in
  --all)          MODE_ALL=1 ;;
  --dir)          MODE_DIR="${2:-.}" ;;
  --layer-check)  MODE_LAYER=1 ;;
  --help|-h)
    sed -n '2,12p' "$0" | sed 's/^# \?//'
    exit 0 ;;
  "")             MODE_HOOK=1 ;;
  *)              MODE_FILE="$1" ;;
esac

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 0

# Auto-detect whether we're scanning the toolkit itself (has .claude-plugin/plugin.json)
# or a target project. Layer-check is toolkit-only — target projects have a single-layer
# .claude/ with no public/internal split.
IS_TOOLKIT_REPO=0
if [ -f "$REPO_ROOT/.claude-plugin/plugin.json" ]; then
  IS_TOOLKIT_REPO=1
fi

# ---------- collect target files ----------
collect_targets() {
  if [ "$MODE_HOOK" -eq 1 ]; then
    local f
    f="$(jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)"
    [ -z "$f" ] && return
    case "$f" in *.md|*.mmd) ;; *) return ;; esac
    [ -f "$f" ] && printf '%s\n' "$f"
    return
  fi
  if [ "$MODE_ALL" -eq 1 ] || [ "$MODE_LAYER" -eq 1 ]; then
    find . -type f \( -name '*.md' -o -name '*.mmd' \) \
      -not -path './.git/*' -not -path './.claude/state/*' \
      -not -path './node_modules/*' 2>/dev/null | sed 's|^\./||'
    return
  fi
  if [ -n "$MODE_DIR" ]; then
    find "$MODE_DIR" -type f \( -name '*.md' -o -name '*.mmd' \) 2>/dev/null | sed 's|^\./||'
    return
  fi
  [ -f "$MODE_FILE" ] && printf '%s\n' "$MODE_FILE"
}

# ---------- resolver ----------
# normalize_path <path>  — collapse `../` and `./` segments.
normalize_path() {
  local p="$1"
  # Try python first (handles ../ correctly), fall back to realpath -m, else manual.
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import os,sys; print(os.path.normpath(sys.argv[1]))" "$p"
  elif command -v realpath >/dev/null 2>&1; then
    realpath -m "$p" 2>/dev/null || printf '%s' "$p"
  else
    printf '%s' "$p"
  fi
}

# classify_layer <path>  — prints 'public' | 'internal' | 'other'
classify_layer() {
  case "$1" in
    .claude/*) printf 'internal' ;;
    skills/*|agents/*|rules/*|docs/*|sequences/*|hooks/*|output-styles/*|.claude-plugin/*|CHANGELOG.md|README.md|LICENSE*|CLAUDE.md)
      printf 'public' ;;
    *) printf 'other' ;;
  esac
}

# ---------- scan one file ----------
scan_file() {
  local file="$1" warn_count=0
  local dir; dir="$(dirname "$file")"
  local src_layer; src_layer="$(classify_layer "$file")"
  local basename_file; basename_file="$(basename "$file")"

  # Walk the file once, tracking fenced-code-block state so refs inside ``` blocks
  # (which are template/example code, not real cross-refs) are skipped.
  local in_fence=0 line_num=0
  while IFS= read -r line_content || [ -n "$line_content" ]; do
    line_num=$((line_num + 1))
    # Toggle fence on any line whose first non-whitespace chars are ```
    case "$line_content" in
      \`\`\`*|*$'\t'\`\`\`*|' '*\`\`\`*)
        if [ "$in_fence" -eq 0 ]; then in_fence=1; else in_fence=0; fi
        continue ;;
    esac
    [ "$in_fence" -eq 1 ] && continue

    # Strip inline-code runs (`...`) so links shown as examples inside backticks are ignored.
    local line_scan; line_scan="$(printf '%s' "$line_content" | sed 's/`[^`]*`//g')"

    # MD link: [text](path.md|.mmd#anchor?)
    for path in $(printf '%s\n' "$line_scan" | grep -oE '\]\([^)]+\.(md|mmd)(#[^)]*)?\)' | sed -E 's|^\]\(||; s|\)$||'); do
      case "$path" in
        http://*|https://*|mailto:*) continue ;;
        *'<'*|*'>'*) continue ;;  # placeholder — skip
      esac
      local path_clean="${path%%#*}"
      [ -z "$path_clean" ] && continue
      local target
      if [[ "$path_clean" == /* ]]; then
        target="${REPO_ROOT}${path_clean}"
      else
        target="${dir}/${path_clean}"
      fi
      target="$(normalize_path "$target")"
      if [ ! -e "$target" ]; then
        echo "[WARN] $file:$line_num → $path_clean (not found)"
        warn_count=$((warn_count + 1))
        continue
      fi
      if { [ "$IS_TOOLKIT_REPO" -eq 1 ] || [ "$MODE_LAYER" -eq 1 ]; } && [ "$src_layer" = "public" ]; then
        local rel_target="${target#"$REPO_ROOT"/}"
        local tgt_layer; tgt_layer="$(classify_layer "$rel_target")"
        if [ "$tgt_layer" = "internal" ]; then
          echo "[ERR]  $file:$line_num → $path_clean (public→internal layer violation)"
          warn_count=$((warn_count + 1))
        fi
      fi
    done

    # @-imports — only check in root CLAUDE.md / CLAUDE.local.md
    case "$basename_file" in
      CLAUDE.md|CLAUDE.local.md)
        for path in $(printf '%s\n' "$line_content" | grep -oE '^@[^[:space:]]+\.(md|mmd)' | sed 's/^@//'); do
          case "$path" in *'<'*|*'>'*) continue ;; esac
          local target="${REPO_ROOT}/${path}"
          target="$(normalize_path "$target")"
          if [ ! -e "$target" ]; then
            echo "[WARN] $file:$line_num → @$path (not found)"
            warn_count=$((warn_count + 1))
          fi
        done
        ;;
    esac
  done < "$file"

  return "$warn_count"
}

# ---------- main ----------
TARGETS="$(collect_targets)"
[ -z "$TARGETS" ] && exit 0

TOTAL_WARN=0
OUTPUT=""
while IFS= read -r file; do
  [ -z "$file" ] && continue
  result="$(scan_file "$file")"
  if [ -n "$result" ]; then
    OUTPUT="${OUTPUT}${result}"$'\n'
    count=$(printf '%s' "$result" | grep -c '^\[')
    TOTAL_WARN=$((TOTAL_WARN + count))
  fi
done <<< "$TARGETS"

if [ "$TOTAL_WARN" -gt 0 ]; then
  if [ "$MODE_HOOK" -eq 1 ]; then
    # Emit as systemMessage for Claude Code to display
    msg="⚠ ${TOTAL_WARN} broken link(s):
${OUTPUT}"
    jq -n --arg m "$msg" '{systemMessage: $m}' 2>/dev/null || printf '%s\n' "$msg" >&2
    exit 0  # don't block writes from hook
  else
    printf '%s' "$OUTPUT"
    printf -- '---\n%d broken ref(s)\n' "$TOTAL_WARN"
    exit 2
  fi
fi

if [ "$MODE_HOOK" -eq 0 ]; then
  # Standalone: print clean
  files_scanned=$(printf '%s\n' "$TARGETS" | grep -c .)
  printf '[OK] %d file(s) scanned, no broken refs.\n' "$files_scanned"
fi
exit 0

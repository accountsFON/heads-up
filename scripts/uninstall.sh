#!/bin/sh
# Removes Heads Up: the app, the hook script, its log, and only its own entries in
# ~/.claude/settings.json (backed up first). Every other hook stays untouched.
#   curl -fsSL https://raw.githubusercontent.com/accountsFON/heads-up/main/scripts/uninstall.sh | sh
#
# Options:
#   --test    skip Launch Services cleanup (for test runs with a temporary HOME)
set -e
TEST=0
for opt in "$@"; do
  case "$opt" in
    --test) TEST=1 ;;
    *) echo "Unknown option: $opt" >&2; exit 2 ;;
  esac
done

APP="$HOME/Applications/Heads Up.app"
HOOK="$HOME/.claude/hooks/heads-up-notify.py"
SETTINGS="$HOME/.claude/settings.json"
LOG="$HOME/Library/Logs/heads-up.log"

if [ -f "$SETTINGS" ] && grep -q "heads-up-notify.py" "$SETTINGS"; then
  if /usr/bin/python3 -c 'import json' >/dev/null 2>&1; then
    PY="/usr/bin/python3"
  elif command -v python3 >/dev/null 2>&1; then
    PY="$(command -v python3)"
  else
    echo "Removing the hook entries needs python3 (xcode-select --install). Nothing was changed." >&2
    exit 1
  fi
  STAMP="$(date +%Y%m%d-%H%M%S)"
  BACKUP="$SETTINGS.heads-up-backup-$STAMP"
  N=2
  while [ -e "$BACKUP" ]; do BACKUP="$SETTINGS.heads-up-backup-$STAMP-$N"; N=$((N + 1)); done
  cp "$SETTINGS" "$BACKUP"
  echo "Backed up your Claude Code settings to $BACKUP"
  "$PY" - "$SETTINGS" <<'STRIP'
import json, os, sys

path = sys.argv[1]
MARK = "heads-up-notify.py"
with open(path, encoding="utf-8") as f:
    data = json.load(f)
hooks = data.get("hooks", {})
for event in list(hooks):
    groups = hooks[event]
    if not isinstance(groups, list):
        continue
    kept, removed = [], False
    for group in groups:
        entries = group.get("hooks", []) if isinstance(group, dict) else []
        rest = [h for h in entries if MARK not in str(h.get("command", ""))]
        if len(rest) == len(entries):
            kept.append(group)
            continue
        removed = True
        if rest:
            group["hooks"] = rest
            kept.append(group)
    if removed and not kept:
        del hooks[event]
    else:
        hooks[event] = kept
if "hooks" in data and not hooks:
    del data["hooks"]
tmp = path + ".heads-up-tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.replace(tmp, path)
STRIP
  echo "Removed the Heads Up hook entries from $SETTINGS"
fi

rm -f "$HOOK" "$LOG"
if [ -d "$APP" ]; then
  if [ "$TEST" = 0 ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP" 2>/dev/null || true
  fi
  rm -rf "$APP"
fi

cat <<DONE
Heads Up is removed. Running Claude Code sessions keep their hooks until they restart.

If you changed the Claude desktop app's notification settings for Heads Up, set
Task complete, Question, and Permission request back to Banners in Settings > Claude Code.
Your settings backups (settings.json.heads-up-backup-*) stay in ~/.claude in case you need one.
DONE

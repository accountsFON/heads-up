#!/bin/sh
# Installs or updates Heads Up.
#   curl -fsSL https://raw.githubusercontent.com/accountsFON/heads-up/main/scripts/install.sh | sh
# Uses a local HeadsUp.zip when one sits next to this script or in ../dist
# (local builds and team copies); otherwise downloads the latest GitHub release.
#
# Options:
#   --local   only use a local HeadsUp.zip, never download
#   --test    skip Launch Services registration and the welcome notification
#             (for test runs with HOME pointed at a temporary folder)
#
# What it changes, and nothing else:
#   ~/Applications/Heads Up.app                  the notifier app
#   ~/.claude/hooks/heads-up-notify.py           the Claude Code hook
#   ~/.claude/settings.json                      adds its hook entries (backed up first)
set -e
REPO="accountsFON/heads-up"
LOCAL_ONLY=0
TEST=0
for opt in "$@"; do
  case "$opt" in
    --local) LOCAL_ONLY=1 ;;
    --test) TEST=1 ;;
    *) echo "Unknown option: $opt" >&2; exit 2 ;;
  esac
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# The hook and the settings merge both run on python3. macOS gets it from the
# Xcode Command Line Tools; a Homebrew or python.org python3 works too.
if /usr/bin/python3 -c 'import json' >/dev/null 2>&1; then
  PY="/usr/bin/python3"
elif command -v python3 >/dev/null 2>&1 && python3 -c 'import json' >/dev/null 2>&1; then
  PY="$(command -v python3)"
else
  echo "Heads Up needs python3. Install the Command Line Tools with: xcode-select --install"
  echo "Then run this installer again."
  exit 1
fi

HERE="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$HERE/HeadsUp.zip" ]; then
  ZIP="$HERE/HeadsUp.zip"
elif [ -f "$HERE/../dist/HeadsUp.zip" ]; then
  ZIP="$HERE/../dist/HeadsUp.zip"
elif [ "$LOCAL_ONLY" = 1 ]; then
  echo "No local HeadsUp.zip found. Run sh scripts/build.sh first." >&2
  exit 1
else
  echo "Downloading the latest Heads Up release..."
  curl -fsSL "https://github.com/$REPO/releases/latest/download/HeadsUp.zip" -o "$TMP/HeadsUp.zip"
  ZIP="$TMP/HeadsUp.zip"
fi
ditto -x -k "$ZIP" "$TMP/pkg"
[ -d "$TMP/pkg/Heads Up.app" ] && [ -f "$TMP/pkg/heads-up-notify.py" ] || {
  echo "$ZIP is missing Heads Up.app or heads-up-notify.py." >&2
  exit 1
}

# 1. The app.
DEST="$HOME/Applications"
APP="$DEST/Heads Up.app"
mkdir -p "$DEST"
rm -rf "$APP"
ditto "$TMP/pkg/Heads Up.app" "$APP"
# Use the alert sound that ships with your own macOS, then re-sign the bundle (ad hoc).
if [ -f /System/Library/Sounds/Hero.aiff ]; then
  cp /System/Library/Sounds/Hero.aiff "$APP/Contents/Resources/Hero.aiff"
  codesign --force --sign - "$APP" >/dev/null 2>&1 || true
fi
# The app is ad hoc signed (not notarized), so clear the download quarantine flag.
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
if [ "$TEST" = 0 ]; then
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" || true
fi

# 2. The hook script.
HOOK="$HOME/.claude/hooks/heads-up-notify.py"
mkdir -p "$HOME/.claude/hooks"
cp "$TMP/pkg/heads-up-notify.py" "$HOOK"
chmod 755 "$HOOK"

# 3. The hook entries in ~/.claude/settings.json. Back up first, then merge:
# earlier Heads Up entries are replaced, everything else stays exactly as it was.
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
  STAMP="$(date +%Y%m%d-%H%M%S)"
  BACKUP="$SETTINGS.heads-up-backup-$STAMP"
  N=2
  while [ -e "$BACKUP" ]; do BACKUP="$SETTINGS.heads-up-backup-$STAMP-$N"; N=$((N + 1)); done
  cp "$SETTINGS" "$BACKUP"
  echo "Backed up your Claude Code settings to $BACKUP"
fi
"$PY" - "$SETTINGS" "$PY" "$HOOK" <<'MERGE'
import json, os, sys

path, py, hook = sys.argv[1:4]
MARK = "heads-up-notify.py"
WANT = [
    ("PreToolUse", "AskUserQuestion|ExitPlanMode|mcp__ccd_turn__wrap_up", "notify"),
    ("PermissionRequest", None, "notify"),
    ("Notification", "elicitation_dialog", "notify"),
    ("PostToolUse", "AskUserQuestion|ExitPlanMode", "clear"),
    ("UserPromptSubmit", None, "clear"),
]

data = {}
if os.path.exists(path) and os.path.getsize(path) > 0:
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except ValueError as exc:
        sys.exit(f"Could not read {path} ({exc}). Fix the file, then run the installer again.")
hooks = data.setdefault("hooks", {})

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

for event, matcher, mode in WANT:
    group = {"matcher": matcher} if matcher else {}
    group["hooks"] = [{"type": "command", "command": f'"{py}" "{hook}" {mode}', "timeout": 5}]
    hooks.setdefault(event, []).append(group)

os.makedirs(os.path.dirname(path), exist_ok=True)
tmp = path + ".heads-up-tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.replace(tmp, path)
MERGE

# 4. A first notification, so macOS asks for permission now instead of at Claude's first question.
if [ "$TEST" = 0 ]; then
  "$APP/Contents/MacOS/HeadsUp" --title "Heads Up is ready" \
    --body "You'll see a notification like this when Claude needs you." --id "headsup:welcome" \
    >/dev/null 2>&1 &
fi

cat <<DONE

Installed Heads Up:
  $APP
  $HOOK
  hook entries in $SETTINGS

Next steps:
  1. Allow notifications when macOS asks (System Settings > Notifications > Heads Up).
  2. Start a new Claude Code session. Hooks load when a session starts.
  3. Recommended, in the Claude desktop app's Settings > Claude Code notifications:
       Task complete:       Off
       Question:            Badge only
       Permission request:  Badge only
     Heads Up already covers questions and permissions with a notification that opens
     the right session, so the app's own banners would double up. Badge only keeps the
     count on the Dock icon. Task complete fires on every finished turn, which is the
     noise Heads Up is built to remove.

To remove it: curl -fsSL https://raw.githubusercontent.com/$REPO/main/scripts/uninstall.sh | sh
DONE

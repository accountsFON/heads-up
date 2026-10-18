#!/usr/bin/env python3
"""Heads Up: notifications for Claude Code that only fire when Claude needs you.

A Claude Code hook. It posts a macOS notification only when you have to act: a
question, a decision, a plan to approve, a permission request, or an input form.
Clicking it opens the exact Claude desktop session (or the terminal app for CLI
sessions). Answering clears the notification. It never blocks Claude: it always
exits 0 and prints nothing.

scripts/install.sh registers it in ~/.claude/settings.json:
  PreToolUse  AskUserQuestion|ExitPlanMode|mcp__ccd_turn__wrap_up -> notify
  PermissionRequest                                              -> notify
  Notification elicitation_dialog                                -> notify
  PostToolUse AskUserQuestion|ExitPlanMode, UserPromptSubmit     -> clear

Testing: HEADSUP_DRYRUN=1 prints the notifier command instead of running it.
Log: ~/Library/Logs/heads-up.log
"""
import glob
import json
import os
import subprocess
import sys

NOTIFIER = os.path.expanduser("~/Applications/Heads Up.app/Contents/MacOS/HeadsUp")
# Claude desktop app internals: per session metadata, and the app's bundle id.
SESSIONS = os.path.expanduser("~/Library/Application Support/Claude/claude-code-sessions")
CLAUDE_APP = "com.anthropic.claudefordesktop"
LOG = os.path.expanduser("~/Library/Logs/heads-up.log")
KINDS = ("question", "decision", "plan", "permission", "input")


def clip(text, n=180):
    text = " ".join(str(text or "").split())
    return text if len(text) <= n else text[: n - 3].rstrip() + "..."


def session_meta():
    """Title and lastFocusedAt for every desktop session, keyed by host id."""
    out = {}
    for path in glob.glob(os.path.join(SESSIONS, "*", "*", "local_*.json")):
        try:
            with open(path, encoding="utf-8") as f:
                d = json.load(f)
            out[d["sessionId"]] = (d.get("title") or "", d.get("lastFocusedAt") or 0)
        except Exception:
            continue
    return out


def frontmost_bundle():
    try:
        front = subprocess.run(["lsappinfo", "front"], capture_output=True, text=True, timeout=2).stdout.strip()
        info = subprocess.run(["lsappinfo", "info", "-only", "bundleid", front],
                              capture_output=True, text=True, timeout=2).stdout
        return info.split("=")[-1].strip().strip('"')
    except Exception:
        return ""


def classify(event, data):
    """Return (kind, title, body) when you have to act, else None."""
    tool = data.get("tool_name", "")
    inp = data.get("tool_input") or {}
    if event == "PreToolUse":
        if tool == "AskUserQuestion":
            qs = inp.get("questions") or [{}]
            more = f" (+{len(qs) - 1} more)" if len(qs) > 1 else ""
            return "question", "A question for you", clip(qs[0].get("question")) + more
        if tool == "ExitPlanMode":
            return "plan", "Plan ready for your OK", "Review the plan and approve it to start the work."
        if tool == "mcp__ccd_turn__wrap_up" and inp.get("ask"):
            return "decision", "Your call", clip(inp.get("ask"))
        return None
    if event == "PermissionRequest":
        # The desktop app also sends PermissionRequest for these two tools.
        # PreToolUse already announced them, so skip the duplicate.
        if tool in ("AskUserQuestion", "ExitPlanMode"):
            return None
        detail = inp.get("command") or inp.get("file_path") or inp.get("url") or ""
        return "permission", "Approval needed", clip(f"Claude wants to use {tool}" + (f": {detail}" if detail else ""))
    if event == "Notification":
        kind = data.get("notification_type", "")
        if kind == "elicitation_dialog":
            return "input", "Input needed", clip(data.get("message"))
    return None


def run(args):
    if os.environ.get("HEADSUP_DRYRUN") == "1":
        print(json.dumps(args))
        return
    if os.path.exists(NOTIFIER):
        subprocess.Popen([NOTIFIER] + args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)


def log(line):
    try:
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "notify"
    try:
        data = json.load(sys.stdin)
    except Exception:
        data = {}
    event = data.get("hook_event_name", "")
    host_id = os.environ.get("CLAUDE_CODE_HOST_SESSION_ID", "")  # set inside the desktop app
    key = host_id or data.get("session_id", "cli")

    if mode == "clear":
        run(["--clear", ",".join(f"{key}:{k}" for k in KINDS)])
        return

    hit = classify(event, data)
    if not hit:
        return
    kind, title, body = hit
    args = ["--title", title, "--body", body, "--id", f"{key}:{kind}"]

    if host_id:
        meta = session_meta()
        name, focused_at = meta.get(host_id, ("", 0))
        # You're already looking at this session: the app shows the prompt in place.
        latest = max((v[1] for v in meta.values()), default=0)
        if focused_at and focused_at >= latest and frontmost_bundle() == CLAUDE_APP:
            log(f"skip {kind} {host_id}: session in focus")
            return
        args += ["--subtitle", name or "Claude session", "--url", f"claude://claude.ai/epitaxy/{host_id}"]
    else:
        folder = os.path.basename(data.get("cwd") or os.getcwd())
        args += ["--subtitle", f"Claude in {folder}"]
        bundle = os.environ.get("__CFBundleIdentifier")  # the terminal app running the CLI
        if bundle:
            args += ["--activate", bundle]
    log(f"{event} {kind} {data.get('tool_name', '')} {key}")
    run(args)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # never break a Claude turn
        log(f"error {exc!r}")
    sys.exit(0)

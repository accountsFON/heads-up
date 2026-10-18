# Heads Up

Notifications for Claude Code that only fire when Claude needs you. Heads Up posts a Mac notification when Claude asks a question, wants a decision, has a plan to approve, needs a permission, or opens an input form. Click it and you land in the exact session that's waiting. Finished turns stay quiet.

Built for anyone who runs a few Claude Code sessions at once, works in other apps while they run, and wants to hear from them only when one is stuck waiting on an answer.

## Features

- **Only when you're needed:** questions, end of turn decisions, plan approvals, permission prompts, and MCP input forms. Finished turns and idle pings stay silent.
- **Opens the right session:** a click jumps straight to the waiting session in the Claude desktop app. For the `claude` CLI, it brings your terminal forward.
- **Skips the session on screen:** when the waiting session is already in front of you, the app's own prompt is enough, so Heads Up stays quiet.
- **Clears itself:** answer the question or send a message, and that session's notifications leave Notification Center.
- **One per session per kind:** a newer question replaces the older one, so a busy session never stacks up a pile.
- **Gentle on your setup:** the installer backs up `settings.json` and adds its hooks next to yours. Run it again to update in place. The uninstaller removes only what Heads Up added.
- **Never blocks Claude:** the hook exits cleanly every time, even when something goes wrong, and the notifier runs in the background.

## Compatibility

| Requirement | Details |
|---|---|
| **macOS** | 12 Monterey or newer |
| **Chips** | Apple Silicon (M1 and later) and Intel, in one universal app |
| **Claude Code** | Claude Code sessions in the Claude desktop app, and the `claude` CLI in any terminal |
| **python3** | Runs the hook. macOS gets it from the Xcode Command Line Tools (`xcode-select --install`). A Homebrew or python.org `python3` works too |
| **Account** | Any user account. Everything installs inside your home folder, so there's no admin password |
| **Tested on** | MacBook Pro 16-inch, M4 Max, macOS 26.5.1, Claude Code 2.1.224 (October 2026) |

A few things to know before you install:

- **Claude desktop app internals:** three undocumented pieces of the Claude desktop app could change in a future update. They are the session link a click opens (`claude://claude.ai/epitaxy/<session id>`), the session files Heads Up reads for the session name and the on screen check, and the `wrap_up` tool behind "Your call" decisions. A change could make a click open the app without jumping to the session, show a session as "Claude session", or stop decisions from firing. The hook events themselves are documented Claude Code features.
- **Intel Macs and older macOS:** the app is built for Intel and for macOS 12, but so far it has only been tested on Apple Silicon with macOS 26. Reports are welcome in [Issues](https://github.com/accountsFON/heads-up/issues).
- **First run permission:** macOS asks once before the app can post anything. The installer sends a welcome notification right away, so that prompt shows up during setup. If you miss it, allow notifications in System Settings > Notifications.
- **Unsigned app:** Heads Up is free and isn't notarized by Apple. It's ad hoc signed, and the installer clears the download quarantine flag so macOS opens it without a warning.
- **Work or school Macs:** a managed Mac can have policies that block unsigned apps or their notifications. If your company manages your Mac, ask your IT team first.

## Install

Open Terminal and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/accountsFON/heads-up/main/scripts/install.sh | sh
```

That downloads the latest release and makes three changes, all inside your home folder:

1. **The app:** `~/Applications/Heads Up.app`, the notifier.
2. **The hook:** `~/.claude/hooks/heads-up-notify.py`, which decides when to notify.
3. **Your Claude Code settings:** five hook entries merged into `~/.claude/settings.json`, after a timestamped backup next to it. Your existing hooks and settings stay exactly as they were.

Run the same line again any time to update. It replaces its own entries and never duplicates them.

**Prefer to download it yourself?** Grab `HeadsUp.zip` from the [latest release](https://github.com/accountsFON/heads-up/releases/latest), save [scripts/install.sh](scripts/install.sh) in the same folder, read it, and run `sh install.sh`. The installer uses the zip sitting next to it.

## Use It

1. Install with the line above, and click **Allow** when macOS asks about notifications.
2. In the Claude desktop app, open **Settings > Claude Code** and set **Task complete** to Off, **Question** to Badge only, and **Permission request** to Badge only. The reasons are in the next section.
3. Start a new Claude Code session. Hooks load when a session starts, so sessions already open keep their old setup until you restart them.
4. Switch to another app or another session and keep working.
5. When Claude needs you, a notification appears. Click it to jump to that session, answer, and the notification clears.

## Recommended Claude App Settings

The Claude desktop app has notifications of its own, and with Heads Up installed they would double up. The installer prints these recommendations and leaves the app's settings for you to change:

- **Task complete, Off:** it fires at the end of every turn, which is the noise Heads Up is built to remove.
- **Question, Badge only:** Heads Up posts the banner, and its click opens the waiting session. The badge keeps a count on the Dock icon.
- **Permission request, Badge only:** same reason. Heads Up covers permission prompts with a banner that opens the right session.

Using only the `claude` CLI? Skip this section.

## What Fires

| When Claude needs you to | Notification title | Body |
|---|---|---|
| Answer a question (`AskUserQuestion`) | A question for you | The first question, plus a count of any others |
| Make a call at the end of a turn (`wrap_up` with a question, desktop app) | Your call | The question |
| Approve a plan (`ExitPlanMode`) | Plan ready for your OK | Review the plan and approve it to start the work. |
| Approve a tool (permission prompt, desktop app or CLI) | Approval needed | The tool, plus its command, file, or URL |
| Fill in a form from an MCP server (elicitation) | Input needed | The form's message |

In the desktop app the subtitle shows the session title, and in the CLI it shows `Claude in <folder>`. Notifications play the Hero alert sound from your Mac.

**Stays silent:** finished turns, idle "waiting for input" pings, a `wrap_up` with no question, and anything in the session you're looking at (the Claude app in front, with that session the last one you focused).

**Clears:** answering a question or plan, or sending any prompt in a session, removes that session's notifications from Notification Center.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/accountsFON/heads-up/main/scripts/uninstall.sh | sh
```

It backs up `~/.claude/settings.json`, removes only the hook entries that point at `heads-up-notify.py`, and deletes the app, the hook script, and the log. Every other hook stays. Running sessions keep their hooks until they restart.

If you changed the Claude app's notification settings, set them back to Banners in Settings > Claude Code. To pause Heads Up without uninstalling, turn it off in System Settings > Notifications.

## How It Works

[Resources/heads-up-notify.py](Resources/heads-up-notify.py) is a Claude Code hook. The installer registers it on these events:

- **Notify:** `PreToolUse` for `AskUserQuestion`, `ExitPlanMode`, and `mcp__ccd_turn__wrap_up`, plus `PermissionRequest`, plus `Notification` for `elicitation_dialog`.
- **Clear:** `PostToolUse` for `AskUserQuestion` and `ExitPlanMode`, plus `UserPromptSubmit`.

The hook reads the event JSON on stdin, decides whether you have to act, launches the notifier in the background, and exits 0. Inside the desktop app, Claude Code sets `CLAUDE_CODE_HOST_SESSION_ID`. The hook uses it to build the click link, reads the app's session files in `~/Library/Application Support/Claude/claude-code-sessions` for the session title and last focus time, and asks `lsappinfo` which app is in front, so it can skip the session you're already looking at. For CLI sessions, it passes along the terminal's bundle id (`__CFBundleIdentifier`) so a click brings that terminal forward.

The desktop app also sends a `PermissionRequest` event for `AskUserQuestion` and `ExitPlanMode`. `PreToolUse` already announced those, so the hook ignores the second event and you get one notification. Each notification's id is `<session>:<kind>`, so a newer one replaces the older one of the same kind, and a clear removes all five kinds for that session.

[Sources/HeadsUp/main.swift](Sources/HeadsUp/main.swift) is a small background app with no Dock icon, built on Apple's UserNotifications framework. Launched with `--title`, it posts the notification and exits. A click makes macOS relaunch it to open the stored link, or to bring the stored terminal forward. The bell icon is drawn in code by [scripts/make-icon.swift](scripts/make-icon.swift) at build time. The alert sound is the Hero sound from your own macOS, which the installer copies into the app before re-signing it.

To see what the hook decides, check `~/Library/Logs/heads-up.log`, or run it by hand with `HEADSUP_DRYRUN=1`, which prints the notifier command and posts nothing:

```bash
echo '{"hook_event_name":"PreToolUse","session_id":"test","cwd":"/tmp/demo","tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Ship it?"}]}}' \
  | HEADSUP_DRYRUN=1 python3 ~/.claude/hooks/heads-up-notify.py notify
```

## Build From Source

You need the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/accountsFON/heads-up.git
cd heads-up
sh scripts/build.sh
sh scripts/install.sh
```

`scripts/build.sh` makes a universal app and packs it with the hook into `dist/HeadsUp.zip`, and `scripts/install.sh` installs that local build. Add `--local` to make sure it never downloads, and `--test` to skip Launch Services registration and the welcome notification when you point `HOME` at a temporary folder for testing. Releases are built automatically by GitHub Actions when a version tag like `v1.0.0` is pushed. See [CHANGELOG.md](CHANGELOG.md) for what changed in each version.

```
heads-up/
├── Sources/HeadsUp/     notifier app code (main.swift)
├── Resources/           the Claude Code hook (heads-up-notify.py)
├── scripts/             build.sh, install.sh, uninstall.sh, make-icon.swift
├── .github/workflows/   automated build, install test, and release
├── CHANGELOG.md
├── LICENSE
└── VERSION
```

## Made by Five One Nine Marketing

Heads Up was built by **Caleb Cody**, founder and CEO of [Five One Nine Marketing](https://www.fonmarketing.com). Five One Nine is a growth partner for businesses that want a clear marketing strategy, the systems to run it, and AI built into how the work gets done. We build tools like this in-house so a small team can punch well above its weight.

**The team:** Caleb Cody, Founder and CEO · Mollie Huebner, Operations Manager and Creative Director · Julio Aleman, Lead Developer and AI Engineer

**From a client, Zach Goodfellow:**

> "You'll have a hard time finding people more passionate about helping you build your business than Five One Nine."

Your strategy. Your system. Your growth partner. **[Let's talk](https://www.fonmarketing.com/contact)**

## License

[MIT](LICENSE). Free to use, change, and share. Heads Up is an independent project and isn't affiliated with or endorsed by Anthropic. Claude and Claude Code are trademarks of Anthropic.

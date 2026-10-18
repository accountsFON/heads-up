# Changelog

## 1.0.0 (2026-10-18)

First public release.

- Mac notifications for Claude Code questions, end of turn decisions, plan approvals, permission prompts, and MCP input forms. Finished turns and idle pings stay silent.
- A click opens the waiting session in the Claude desktop app, or brings the terminal forward for CLI sessions.
- Skips the session already on screen, keeps one notification per session per kind, and clears a session's notifications once you answer.
- A one-line installer that backs up `settings.json` and merges its hooks next to yours, safe to run again for updates.
- An uninstaller that removes only what Heads Up added.
- A bell icon drawn in code at build time.
- Universal build for Apple Silicon and Intel, macOS 12 or newer.

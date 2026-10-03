# Security policy

## What this tool is

A single-file Windows CLI that drives the real desktop: it takes screenshots,
moves the mouse, sends keystrokes, reads the clipboard, and writes text through
the OS accessibility layer. Those are powerful primitives — so the tool is built
so that every action is attributable and guardable, not sandboxed away:

- **Audit log.** Every executed act/text/clipboard/UIA-write command appends one
  line to `shots/actions.log`: UTC timestamp, command, arguments, resolved
  target. The log rotates at 512 KB keeping the 5 newest archives.
- **Redaction by default.** Typed payloads and guard needles are stored as
  `<redacted:Nchars>`; recording them verbatim requires an explicit opt-in flag
  on each call. File *paths* are logged; file and clipboard *contents* never are.
  `replay` refuses any step whose payload was redacted — replaying the
  placeholder would type the placeholder.
- **Foreground guards.** Keystrokes go out only after the target window is
  verified to actually own the foreground, and the foreground is re-checked
  after sending, so a mid-flight focus steal is a loud failure too.
- **Occlusion self-reporting.** Every pixel-reading command says what physically
  covers the region it measured; guard and assertion commands refuse when
  occluded rather than read a coverer's pixels as context.
- **No network.** The tool makes no network connections, has no telemetry, and
  nothing phones home. The one exception is a Chrome DevTools route that only
  ever talks to the local loopback address and refuses every other target
  explicitly.

This is a trust-of-the-operator model: whoever can run the commands can act on
the desktop. The guards exist to stop an *agent* (or a tired human) from sending
input to the wrong window or trusting a mis-measured screen — not to contain a
malicious operator.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting: open this repository's **Security**
tab and choose **Report a vulnerability**. Please include:

- the exact command line (redact window titles if they carry personal context);
- the echoed output — the echoes are the evidence;
- the offline self-test summary line from your run.

Do not attach screenshots of your own desktop. There is no telemetry in the
tool, so all evidence lives on your machine and you choose what to share.

## Scope

The single tool file, the loadable skill wrapper scripts (install/uninstall),
and the documentation. If a CI workflow is ever added, it must run the offline
self-test only and never exercise a desktop.

## Hardened-adjacent notes

- Screenshots and the audit log are written to the runtime directory next to the
  tool by default; on a shared machine, point the working directory somewhere
  with appropriate permissions before driving sensitive windows.
- A full-window `read-text` over a messaging app can surface secrets that happen
  to be on screen (this has been observed with a payment URL carrying a session
  key). Prefer `--max-lines` / `--filter`, and never log payloads you do not have
  to log.

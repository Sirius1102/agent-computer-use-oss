---
name: Feature request
about: propose a command, flag or guard
labels: enhancement
---

**Scenario** — what are you automating, against which *class* of app? Describe the kind
of window/interface, not a screenshot of your desktop.

**Expected behaviour** — the command shape you wish existed, and what it should echo
back. If it should refuse something, say under which conditions.

**Never-silently check** — this project refuses to return a bare number or a bare
"success". Does your proposal print how it knows what it knows (which road answered,
what was measured, what was refused)? If it cannot, explain why that is acceptable here.

**Cost** — what does the proposal add to the surface (new flags, new failure modes, new
state), and what would break if it failed quietly? A proposal that cannot name its own
costs is hard to accept.

**Runtime dependencies** — does it need anything beyond the current standard library?
Zero third-party runtime dependencies is a design invariant; proposals that need a
package manager should say so up front.

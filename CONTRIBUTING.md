# Contributing

Thanks for considering a contribution. This repository is a single-file Windows
desktop automation tool plus its documentation and engineering shell, so most
contributions are docs, tests and CI — and the tool's own regression gate is the
arbiter for all of them.

## Before you open a PR

1. **Run the offline self-test and paste the summary line.**

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File desktop.ps1 selftest
   ```

   It must end with `0 failed` (exit code 0). This is the arbiter for every change;
   if and when a CI workflow exists for this repository, it runs exactly this and
   nothing else. `selftest --live` drives real synthetic windows on a real desktop,
   so it is out of scope for CI by design and must never be added to a workflow.

2. **Run the outbound-content gate over every file you touched.** The gate and
   its rig deliberately live outside this repository (they encode this machine's
   private surface, which is exactly what must not enter a public tree). A
   "zero hits" result is only meaningful next to a known-dirty sample scoring
   non-zero in the same run — without that control, zero proves nothing.

3. **Version bits: bump by hand, one location at a time.** Feature work raises
   the Y bit, fixes raise the Z bit. Every bump must land in the same commit in
   all version carriers: the header comment near the top of the tool file, its
   usage banner, both README H1s, and the top entry of the changelog. Decide
   each occurrence of an old version number individually — historical numbers
   in changelog entries and review notes stay exactly as they are. Never
   bulk-replace.

4. **Tracked-file inventory.** Adding or removing a file changes what
   `git ls-files` reports. The count written in both README editions
   (`tracked=N`) and the repository layout trees must be updated in the same
   commit — the self-test compares the written number with reality and fails a
   stale inventory. Do not edit that lint's pinned set or loosen the criteria
   to make it pass; the pin follows the tree, not the other way around.

5. **Both README editions move together.** `README.md` and `README.zh-CN.md`
   must document the same command set — the self-test fails a one-language-only
   update. A command row changed in one language must land in the other in the
   same commit. The same goes for structural additions (sections, tables,
   diagrams): mirrored in both editions or in neither.

## Never commit

- Local machine paths (user-profile directories, drive-letter work roots),
  listening ports, window coordinates captured on your own desktop, names of
  other projects or sessions, credentials of any kind. The outbound gate looks
  for exactly these shapes; a red hit is a hard stop, not a warning.
- Binary screenshots or demo GIFs. The repository deliberately carries no
  binary assets; diagrams are Mermaid, badges are remote documentation images.
- New runtime dependencies. The tool is one file with zero third-party runtime
  dependencies; a contribution must not change that. Build-time or CI tooling
  is fine, but say so explicitly and keep it out of the tool's own surface.

## Style

- Claims must be falsifiable, and every design choice states its cost. "Better"
  is not an argument; a named difference with its trade-off is.
- Known limitations are the project's core asset. Do not trim them to make the
  project look better — a limitation you remove from the docs still exists on
  the desktop, just without a warning.
- The tool's source file is pure ASCII by invariant (PowerShell 5.1 decoding);
  do not add non-ASCII literals to it. Docs are UTF-8 and bilingual.

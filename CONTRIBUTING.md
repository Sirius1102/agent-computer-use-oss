# Contributing

Thanks for considering a contribution. This repository is a single-file Windows
desktop automation tool, its documentation and engineering shell, and the full source
the tool is stitched from (`src/`), so most contributions are docs, tests and CI — and
the tool's own regression gate is the arbiter for all of them.

## Before you open a PR

1. **Change `src/`, then rebuild the artifact — in the same commit.** The root `desktop.ps1` is a
   deterministic stitch product of `src/` (the `desktop.ps1` entry plus 22 `lib/*.ps1` modules);
   it is never edited by hand. Change the source, then regenerate it:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File skill/agent-computer-use/install.ps1 -StitchTo desktop.ps1
   ```

   The stitch is deterministic (identical sources yield a byte-identical artifact) and exits non-zero
   without writing anything when a declared source file is missing.

2. **Run the offline self-test and paste the summary line.**

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File desktop.ps1 selftest
   ```

   It must end with `0 failed` (exit code 0). This is the arbiter for every change;
   if and when a CI workflow exists for this repository, it runs exactly this and
   nothing else. `selftest --live` drives real synthetic windows on a real desktop,
   so it is out of scope for CI by design and must never be added to a workflow.

3. **Run the outbound-content gate over every file you touched.** The gate and
   its rig deliberately live outside this repository (they encode this machine's
   private surface, which is exactly what must not enter a public tree). A
   "zero hits" result is only meaningful next to a known-dirty sample scoring
   non-zero in the same run — without that control, zero proves nothing.

4. **Version bits: bump by hand, one location at a time.** The definition site is
   the `$script:ToolVersion` constant in `src/desktop.ps1`; the file header comment
   and the usage banner must carry the same value, and a repo-contract lint fails
   any drift. Feature work raises the Y bit, fixes raise the Z bit. Every bump must
   land in the same commit in all version carriers: the constant, both README H1s,
   and the top entry of the changelog. Decide
   each occurrence of an old version number individually — historical numbers
   in changelog entries and review notes stay exactly as they are. Never
   bulk-replace.

5. **Tracked-file inventory.** Adding or removing a file changes what
   `git ls-files` reports. The count written in both README editions
   (`tracked=N`) and the repository layout trees must be updated in the same
   commit — the self-test compares the written number with reality and fails a
   stale inventory. Do not edit that lint's pinned set or loosen the criteria
   to make it pass; the pin follows the tree, not the other way around.

6. **Both README editions move together.** `README.md` and `README.zh-CN.md`
   must document the same command set — the self-test fails a one-language-only
   update. A command row changed in one language must land in the other in the
   same commit. The same goes for structural additions (sections, tables,
   diagrams): mirrored in both editions or in neither.

## Never commit

- Edits to the root `desktop.ps1`. It is a build product; change `src/` and re-stitch (step 1).
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

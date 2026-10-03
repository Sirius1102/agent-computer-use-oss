**What changed** — one sentence per item.

**selftest** — paste the offline summary line and confirm it ends with `0 failed`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File desktop.ps1 selftest
# ----- selftest: N passed, N failed, N skipped -----
```

**Outbound gate** — confirm every touched file was scanned by the outbound-content gate
in a run whose dirty-sample control scored non-zero. A zero-hits result without that
control is not evidence; say so rather than skipping the control.

**Version bits and tracked inventory** — did this PR touch a version carrier (tool
header comment, usage banner, either README H1, the changelog top entry) or add/remove
tracked files (the `tracked=N` line in both README editions)? If yes, state old → new
for each location, decided one occurrence at a time (no bulk replacement). If not,
write "untouched".

**README editions** — if a command row or structural section changed, confirm the same
change landed in both `README.md` and `README.zh-CN.md` in this PR.

**Checklist**

- [ ] offline selftest: `0 failed`
- [ ] outbound gate run with dirty-sample control non-zero, all touched files 0 hits
- [ ] version carriers and tracked inventory consistent (or explicitly untouched)
- [ ] both README editions updated together (or explicitly untouched)
- [ ] no new runtime dependencies; no binary assets

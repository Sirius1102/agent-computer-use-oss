---
name: Bug report
about: something the tool did (or refused to do) that contradicts its documentation
labels: bug
---

**Command** — the exact command line (redact window titles or text if they carry
personal context):

```
<paste the command here>
```

**Actual output** — stdout and stderr, unmodified. The echoes are the evidence: do not
summarize them.

```
<paste output here>
```

**selftest result** — the offline gate's summary line from this machine (no `--live`
needed for a bug report):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File desktop.ps1 selftest
# ----- selftest: N passed, N failed, N skipped -----
```

**Environment**

- Windows edition and build:
- PowerShell version (`$PSVersionTable.PSVersion`):
- single or multiple monitors, and the display scaling of each:

**What you expected, and what the docs say** — link the README section you followed, so
a docs bug and a tool bug can be told apart.

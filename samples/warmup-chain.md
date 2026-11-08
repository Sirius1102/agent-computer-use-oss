# warmup-chain: one chain, two invocation forms (A4, v4.11.0)

`warmup-chain.json` is a read-only 5-step chain (two shots, one full-screen OCR
locate via `assert-text`, one pixel read, one sleep) with the `warmup` pre-flight
written as the FIRST step. The same chain can also be run with the `--warmup`
switch and a file that does NOT start with a warmup step - the switch prepends
one, and a file that already starts with `warmup` is never double-prepended.

```text
# form 1: the warmup step written by hand (this file as-is)
desktop.ps1 script samples/warmup-chain.json

# form 2: the switch, with a chain file whose first step is NOT warmup
desktop.ps1 script my-chain.json --warmup

# plan only: prints the step list including probes=foreground,dpi,ocr, runs nothing
desktop.ps1 script samples/warmup-chain.json --dry-run
```

Before running it for real, replace the `assert-text` needle with text that is
actually on YOUR screen (the shipped needle is a placeholder and the step will
fail on it by design - an assert is a measurement, not a suggestion).

Measured on the authoring machine (3840x2160, PowerShell 5.1, 10 runs, median,
chain = 5 steps incl. one full-screen OCR locate):

| invocation form                              | median per chain |
|----------------------------------------------|------------------|
| five separate desktop.ps1 calls               | 10036 ms         |
| `script`, one process, no warmup              | 3455 ms          |
| `script --warmup`, one process, pre-flight    | 3488 ms          |

The warmup step itself is read-only (foreground identity, DPI mode, OCR engine)
and a probe that cannot produce its value aborts the chain before any real step
runs. The `MEASURED-*` values are recorded in the repository CHANGELOG for the
release that shipped this sample; re-measure on your own machine before quoting
them.

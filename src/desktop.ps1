# desktop.ps1 - Windows desktop automation helper. One fresh process per invocation,
# no resident process: each invocation writes a local active/history record, recovered after a crash;
# there is no daemon to attack or orphan. Long chains batch in-process via `script`.
# version: 4.6.1  (version sync list lives in the project overview doc)
#
# Source layout since the A-beta split (v4.4.0, cards A-01..A-25): this entry PLUS the files under
# lib/, dot-imported in $script:StSourceFiles order. The DELIVERED tool is still one file -
# install.ps1 stitches entry+lib back into a single .ps1 - so "single-file" is now a statement about
# the artifact, not about the repository. selftest announces which source shape it measured
# ("aggregate source mode, N file(s)" vs "single-file source mode (no lib/ beside the entry)"); the
# discriminator is a lib/ directory next to the entry and nothing else.
# The git-managed project folder (repo agent-computer-use) lives on the D: work drive; see README.md.
#
# NOTE: this file carries a UTF-8 BOM, so PowerShell 5.1 decodes it as UTF-8;
# the content still stays pure ASCII by convention (no non-ASCII literals).
# BOM rule scope is .ps1 ONLY: .bat files must NEVER carry a BOM (cmd.exe
# fails on it) - do not extend this convention to .bat.
# Non-ASCII text does NOT need the clipboard: since v1.3.0 `type` sends each
# character as a Unicode code unit (SendInput + KEYEVENTF_UNICODE), which is
# also what the README and the overview say. Long text, or text carrying quotes /
# backticks / $, still prefers `paste <file>` - that is a shell-quoting choice, not
# an IME limitation, and the script source itself stays pure ASCII either way.
#
# Usage: powershell -ExecutionPolicy Bypass -File desktop.ps1 <cmd> [args...]

param(
  [Parameter(Position = 0)][string]$Cmd = 'help',
  [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Rest = @()
)

$script:ToolVersion = '4.6.1'

$ErrorActionPreference = 'Stop'
# X-02 (2026-10-06, landed after 6 batches of measurement): StrictMode is ON for this entire file.
# An absent property, an unset variable or a method on $null is now a FAILING COMMAND (ERROR + exit 1)
# rather than a silent empty string - that is the whole point of the change. Reads that are meant to
# be optional go through Get-OptValue, which is byte-equivalent to the bare read it replaced.
Set-StrictMode -Version Latest

# v3.0.0 (S-4): the offline check total is DECLARED here and pinned by a contract at the end
# of selftest, so "how many checks does this version have" stops being a number somebody
# types into a README from memory (every earlier round's 664/669 was a hand-copied snapshot,
# and the OSS badge only got a lint because the badge is public). Adding or removing a check
# REQUIRES editing this line, and the run prints the number it expected. The declaration is
# the discipline; the value is just what it happens to be equal to right now.
# Placed after param() because PowerShell allows only comments before it (measured: an
# assignment up there is a parse error for the whole file).
# Sync list: this line and the iteration-log entry. It is NOT a version number.
# v4.1.3 (external review K): the number used to carry no record of where it came from, so
# when the environment moved nobody could tell a drifted machine from a lost check. It now
# has one: measured 2026-10-07 on this box, PowerShell 5.1 AND pwsh 7.6.6, PATH normal AND
# PATH without System32/WindowsPowerShell/git, OCR language pack reachable AND not - all
# four contexts print this same total. That is what the region mechanism above buys; if a
# future run reports a different number, the tree lost or gained a check, not a machine.
# v4.2.2: 847 -> 852, RAISING AN EXPECTED COUNT (it does not loosen any check): +3 explicit
# checks for the process-entry environment normalizer (F2) and +2 that the comma-return audit
# emits automatically for the new helper Get-DuplicateCaseEnvNames. Nothing was deleted,
# relaxed or excused.
# v4.2.3: 852 -> 853, again a RAISE (nothing relaxed): +1 check - the newcomer guide's taught
# commands must exist in this tree (the third carrier of the stale-reference disease).
# v4.2.4: 853 -> 854, again a RAISE: +1 check - the --timing plumbing lint (one flag assignment,
# consulted by exactly the two emitters; a cost profile that could change a verdict would be a
# different feature).
# v4.2.4 (second): 854 -> 855, again a RAISE: +1 check - no for-condition may carry @(array).Count
# (the O(n^2) trap that cost fourteen scan lints ~250 s of the gate; hoisting the count changes
# no verdict, and the lint keeps the shape from coming back).
# v4.3.0: 855 -> 866, again a RAISE (nothing relaxed): +2 lang-trap lints (production keys-member
# reads go through Get-HashKeys; three unsafe text shapes pinned with planted samples each)
# and +9 contracts for selftest --index / --only (subset vs emitted names, full line-accuracy
# pass, matcher/resolver/summary units, one wiring lint, two child-process e2e refusals).
# v4.4.0 (A-25): the version POSITION moves 4.3.2 -> 4.4.0. This card adds NO check, so the number
# below does not move - the bump is the structural one the design reserved for A-25 (v6 3.6, ruling B):
# multi-file source loading, dual-mode execution, the stitcher and the family split all landed
# underneath it while the branch still declared 4.3.2. Carriers synced in the same commit: this
# header line, the Usage banner, README H1, the overview header and the iteration-log entry. The
# repo-contract family's four `version:` checks are what make "forgot a carrier" impossible; A-25
# reverted each carrier one at a time in a throwaway detached tree and read the named red, then
# restored by byte copy and compared sha256 (never `git checkout --`).
# v4.4.0 (A-14a): 902 -> 905, again a RAISE (nothing relaxed): the selftest body is now attributed to
# families by BANNER TEXT (never by line number), with the precedence itself declared as data, and
# every family measured against a registered banner-count/line-span. This is the card v7 B.3 set up
# by warning that the keyword sketch left 3,610 lines unclaimed - so all 137 banners in the body are
# enumerated and claimed here, and the gate names a family that shrinks, empties, or is unclaimed
# rather than letting the next card discover it by hand.

# v4.4.0 (A-12): 900 -> 902, again a RAISE (nothing relaxed): the section that moved must now say
# WHICH FILE every line number belongs to. Seven readings still echoed raw aggregate indices after
# A-11b put the section at the end of the aggregate - they go through the resolver, which stays
# bare in single-file mode so the installed product does not change shape. The second gate pins
# the thing the move actually altered: the audited command lives in the entry while its test
# double is installed inside the moved section, so the seam is asserted by attribution, not by a
# remembered number.

# v4.4.0 (A-11a): 897 -> 900, again a RAISE (nothing relaxed): the tool publishes its own entry
# path and root at load time, because $PSCommandPath and $PSScriptRoot inside a dot-sourced file
# name THAT file (measured on both engines), and the selftest section reads them 91 times -
# 63 of them to spawn a child through the entry. All 91 go through the anchors now, so the
# section can move without repointing a single probe into lib/, and the readers that remain are
# registered per section: a row must vanish in the commit that moves its owner.

# v4.4.0 (A-09): 894 -> 897, again a RAISE (nothing relaxed): the two lints the design doc calls 6
# and 7 land - the audited command body may not read a caller-scope command variable, and every
# use of the dispatcher variable has to sit in a scope that DECLARES it (the entry parameter block
# owns the top-level uses). Measured first, then registered: two owners were borrowing - the
# script runner (four uses) and three selftest fixtures - and both were fixed instead of exempted.
# The declare-check answers yes / no / absent as three verdicts, so a misspelled function name
# cannot read as compliance, and the top-level exemption is itself counter-sampled.

# v4.4.0 (A-08): 890 -> 894, again a RAISE (nothing relaxed): the audit command name stops coming
# out of caller scope and becomes an argument at all 55 sites. Four gates account for the move -
# the three sources that fill the column, the five helpers that hand their own formal onward,
# the test double whose arity must match the real function (planted short stub refused), and one
# real write to a temporary log whose four columns are read back, so the shape of the audit line
# is evidence rather than an assumption while A-20 stays unauthorised.

# v4.4.0 (A-07): 883 -> 890, again a RAISE (nothing relaxed): the four families this split keeps
# editing (who calls the audited command, which mentions of it are not calls, the function-table
# test doubles, what runs at load time) are registered as AST-derived tables with three planted
# unit gates and four live gates, counted case-sensitively - so a handler that loses its audit
# call, or a card that adds load-time state without saying so, fails by key name.
# v4.4.0 (A-06): 881 -> 883, again a RAISE (nothing relaxed): the run now says which source mode it
# measured, and that sentence is tied to the discriminator by a predicate planted to fail three ways.
# v4.4.0 (A-05): 877 -> 881, again a RAISE (nothing relaxed): the source set and the dot-import list
# get predicates that are planted-tested both ways today (declared-missing, on-disk-undeclared,
# swapped order, missing stitch marker) and two live gates that SKIP out loud until a lib/ exists.
# v4.4.0 (A-04): 874 -> 877, again a RAISE (nothing relaxed): the aggregate line number gains a
# file (resolver unit measured on a planted two-file span map, the "no bare index left" scan with
# a planted canary proving the scan can match, and a span-vs-first-line gate that SKIPS out loud
# in single-file mode instead of vanishing). See the A-03 note below for what the machine is.
# v4.4.0 (A-03): 866 -> 874, again a RAISE (nothing relaxed, nothing deleted): the source-set
# machine lands with its own guards - aggregator order measured both ways, declared-but-missing
# refusal, mode discriminator read on planted roots both ways, the entry-first lint plus its
# planted counter-sample, the eleven load-time assignments pinned by NAME plus a planted-missing
# probe, and one proof that a one-file aggregate equals the raw entry (so A-03 cannot have
# changed what selftest measures).
# v4.4.0 (A-25) ACQUISITION ENVIRONMENT, re-measured 2026-10-20 on this box - this REPLACES nothing
# above, the v4.1.3 paragraph stays as the history of its own round. Method = the same four contexts
# v4.1.3 used, with the PATH trim living only in the child's environment (the system environment is
# never touched: 61 PATH entries -> 52 after dropping System32, WindowsPowerShell and git), and each
# context's engine version self-reported by the process that ran it (G-18), not copied from a label:
# PowerShell 5.1.26100.9711 and pwsh 7.6.7. ALL FOUR print the SAME total below: 939, as
# 936 passed / 0 failed / 3 skipped (5.1, normal PATH), 911 / 0 / 28 (pwsh, normal PATH),
# 929 / 1 / 9 (5.1, trimmed PATH) and 904 / 1 / 34 (pwsh, trimmed PATH).
# HONEST EXCEPTION, measured for the first time this round and NOT fixed by this card (registered
# as ledger item G-21): the two trimmed contexts are not exit 0 any more. One check,
# 'live: --out still never reaches the parser (PowerShell eats it)', spawns `powershell` BY BARE NAME,
# so with System32\WindowsPowerShell off PATH the spawn throws CommandNotFoundException, while its
# assertion only recognises the AmbiguousParameter / OutVariable tokens - it goes RED where the
# family it belongs to would SKIP. That family is v4.1.3 finding D ($script:PsChildOk + ST-Skip with
# a reason, installed on three child-powershell checks); this is the fourth site, missed there. The
# TOTAL is still machine-independent, which is the claim the number below exists to carry; what is no
# longer true is "four contexts, four exit 0", so the old wording is left as history rather than
# quietly rewritten. Fix belongs to the measuring tool, not to a version-position card.
# v4.4.0 (MERGE PEN, 2026-10-20 15:2x): this branch now carries the sister gauge-repair tip
# f844aa3 (A-24 offline child-probe runner, G-19 mechanism) as a real merge commit. The sister
# round adds ONE offline check (939 -> 940) and still carries the OLD live-suite registration
# 151, while this branch carries G-20's 156 - so the merged tree is declared 940 AND
# LiveSuite=156, and both numbers were re-measured on this box after the merge, not inherited
# from either parent. Readings, self-reported by the process that ran them (G-18):
#   PowerShell 5.1.26100.9711 = 937 passed / 0 failed / 3 skipped (sum 940, exit 0);
#   pwsh 7.6.7 = 912 / 0 / 28 (sum 940, exit 0). Each version was read back from the SAME binary in the
#   same pen (engine-identity record next to the two runs), not copied from a label (G-18). Both engines
#   print the same total.
#   The same pen reconciles the overview header against the declaration: doc=940 declared=940 (5.1)
#   and doc=940 declared=940 (pwsh). Tracked-file inventory re-counted in the SAME pen: git ls-files = 34
#   and the overview states 34 (the lint that compares them is the one that caught the mid-merge index stages, so it is proof
#   the merge was finished, not that the tree grew).
# The paragraph above is the A-25 round's own acquisition record and is left exactly as it
# was, per the owner: keep the historical environment notes, APPEND the new readings.
# v4.4.0 (G-21, 2026-10-20 17:2x): the honest exception above is CLOSED for the offline gate, and the
# wording it broke is repaired. The four contexts are re-measured on tip 4dec5eb (implementation pen;
# this comment pen only adds comments) with the same harness A-25 used - the PATH trim lives in the
# child's environment only (61 -> 52 entries), and each engine version is self-reported by the process
# that ran it (G-18). Readings: 5.1 normal PATH = 939 passed / 0 failed / 3 skipped (sum 942, exit 0);
# pwsh 7.6.7 normal PATH = 914 / 0 / 28 (sum 942, exit 0); 5.1 trimmed PATH = 931 / 0 / 11 (sum 942,
# exit 0); pwsh 7.6.7 trimmed PATH = 906 / 0 / 36 (sum 942, exit 0). So "four contexts, four exit 0"
# is true again on the offline face - and the same four contexts printed 929/1/10 and 904/1/35 with
# exit 1 on the parent tip, which is what the paragraph above recorded.
# WHAT CHANGED: that one check asked its child through the call operator, so it needed a resolvable
# powershell.exe; the pre-flight that answers that question already existed (v4.1.3 finding D) and this
# was the fourth site that never asked it. It now asks, and when the answer is no it SKIPs under its
# OWN name (the total is unchanged - nothing is absorbed) carrying the measured reason.
# MEASURED, and this is why the pre-flight is now TWO probes: with System32\WindowsPowerShell off PATH
# the PATH face dies (Get-Command powershell.exe answers nothing, a bare `& powershell` returns an
# empty face) while `Start-Process powershell -Wait -PassThru` still runs the child and reads back its
# exit code, because Start-Process resolves through App Paths. Both engines agree; the two readings
# (start-process-face-ps51.json / -pwsh7.json) sit in the G-21 evidence directory registered in the
# construction ledger. A block that raises its fixture with Start-Process and drives the tool with
# `& powershell` therefore needs BOTH answers separately, which is what $script:PsStartOk adds beside
# $script:PsChildOk. The step-probe block in the live family gates on both, BEFORE it writes temp files
# or starts a fixture, and an exception raised after that still reports RED - the gate is not a blanket.
# NOT covered by this pen, stated plainly: the live face of that block could not be exercised under a
# trimmed PATH (no desktop window was granted for it), so "PATH-broken + --live" remains unverified.
# The two new checks (940 -> 942) pin the gating structure and give the pinning itself planted teeth;
# lint (A-14a)/(A-14b) and the tracked inventory were re-measured in the same pen as the line counts.
# v4.4.1 (CU-REL-01): 942 -> 962, again a RAISE (nothing relaxed): +20 for the two guards this
# behaviour card had to make measurable offline - 10 units over the landing verdict, its
# refusal/relaxation renderer, the focus state reader plus usable gate (five planted single-face
# breaks, one planted pass), and two planted counterexamples proving the stale-origin scan and the
# no-force scan are not blind; 10 lints over the relclick and focus command bodies (wiring scan sees
# both spans, common target path, by-handle rect, select-time origin gone, pre-send refusals name the
# no-op, positional form kept, focus re-measures all four faces, the usable guard sits ahead of the
# echo, fg_ok= has exactly one producer, focus takes no --force while the shared guard keeps its own
# advice) - 10+10 = 20. Every live face of this card still needs a granted window and is reported
# NOT VERIFIED, not as a pass.
# v4.4.1 (CU-REL-01) ACQUISITION READINGS, measured 2026-10-20 22:05-22:33 +0800 on tip bf1df8b (the
# implementation pen; the pen that writes these lines only records them). Harness = the accepted
# A-25/G-21 gate.cjs copy, with ONE change: DTX_QUARANTINE points OUTSIDE the repository (the g20
# quarantine directory under the document-operations tree, absolute path registered in the ledger row).
#   5.1.26100.9711 normal PATH (61 entries)  = 959 / 0 / 3  (sum 962, exit 0, stdout 118870 bytes)
#   5.1.26100.9711 trimmed PATH (52 entries) = 951 / 0 / 11 (sum 962, exit 0, stdout 119735 bytes)
#   pwsh 7.6.7     normal PATH (61 entries)  = 934 / 0 / 28 (sum 962, exit 0, stdout 121714 bytes)
#   pwsh 7.6.7     trimmed PATH (52 entries) = 926 / 0 / 36 (sum 962, exit 0, stdout 122529 bytes)
# Each engine string is self-reported by the process that ran the gate (G-18), read inside the very
# environment the gate ran in; the strict '^FAIL ' line count is 0 in all four cells; the G-21 child
# probe keeps its own PASS (normal) / same-name SKIP with the measured reason (trimmed) shape, so no
# cell was absorbed to make the totals agree. The PATH trim lives in the CHILD environment only - the
# system environment was never touched. What these four cells do NOT cover: the live face of this card
# (the four planted counterexamples need a granted window), which stays unverified.
# v4.4.2 (CU-REL-01 hardening): 962 -> 963, a RAISE, and the supervisor own mutation is why.
# Deleting the hit-window call line from relclick went red at once; COMMENTING that line out kept
# all four cells green, because the wiring lint of the previous pen was a text-existence scan and
# a comment keeps every literal. Both wiring lints now count live call lines (a line whose first
# non-space character is # is skipped) over six names in relclick and five in focus, the
# guard-ahead-of-echo lint compares line numbers on the same census instead of character offsets,
# and one new unit check plants a space-indented comment, a flush-left comment and two live calls
# so the census itself is counterexampled. No handler byte changed in this pen:
# lib/handlers-act.ps1 and lib/handlers-read.ps1 stay exactly as of tip de4212b.
# v4.4.2 (CU-REL-01 hardening) ACQUISITION READINGS, measured 2026-10-21 00:28-00:43 +0800 on tip
# 1f6ff43 (the hardening pen; this pen only writes them down, plus the two overview ruler errata).
# Harness = the accepted A-25/G-21 gate copy, DTX_QUARANTINE still OUTSIDE the repository (the g20
# directory under the document-operations tree); the PATH trim is applied to the CHILD only, the
# system environment is never touched, and every engine string is self-reported by the process
# that ran the gate (G-18).
#   5.1.26100.9711 normal PATH (61 entries)  = 960 / 0 / 3  (sum 963, exit 0, stdout 119300 bytes)
#   5.1.26100.9711 trimmed PATH (52 entries) = 952 / 0 / 11 (sum 963, exit 0, stdout 120164 bytes)
#   pwsh 7.6.7     normal PATH (61 entries)  = 935 / 0 / 28 (sum 963, exit 0, stdout 122144 bytes)
#   pwsh 7.6.7     trimmed PATH (52 entries) = 927 / 0 / 36 (sum 963, exit 0, stdout 122959 bytes)
# Registration first, then green: the probe run of this pen came back 957 / 3 / 3 and the three
# reds were exactly the three tallies that had to move (A-14a measured window-targeting
# banners=11 lines=986 against the declared 959, A-14b got 141 emitters against 140, the contract
# check refused 962 against 963). No number was edited to fit a run - the run was re-taken.
# Mutation proof for this pen, three runs on COPIES of a stitched single file, each in its own
# directory (the delivery tree is never mutated; single-file mode has its own skip profile, so its
# sums read 962 for the old artifact and 963 for the new one):
#   old 8bc4093e + hit-window line commented out = 938/0/24 exit 0  - the blind spot, first-hand
#   new fa137fb0 + the same line commented out   = 938/1/24 exit 1  - red is the relclick wiring
#     lint and the published census reads Invoke-HitWindowCheck=0 while the other five read 1
#   new fa137fb0 untouched                      = 939/0/24 exit 0  - control, census all 1
# v4.4.2 (CU-REL-01 comment-census teeth) ACQUISITION READINGS, measured 2026-10-21 09:12-09:24 +0800 on tip
# 3f73a78 (fc410c8 cut the teeth, 0730799 moved the one tally they drove, 3f73a78 is wording in a
# document only). The four lines below are generated from
# _tmp/sup/curel04-mat2/curel04b.matrix.json by the pen script, not typed from memory. Harness =
# the same accepted A-25/G-21 gate copy, DTX_QUARANTINE OUTSIDE the repository (the g20 directory
# under the document-operations tree), the PATH trim applied to the CHILD only, every engine string
# self-reported by the process that ran the gate (G-18); the strict ^FAIL line count is 0 in all
# four cells and the G-21 child probe keeps its own PASS (normal) / same-name SKIP (trimmed) shape.
#   5.1.26100.9711 normal PATH (61 entries) = 960 / 0 / 3  (sum 963, exit 0, stdout 119363 bytes)
#   5.1.26100.9711 trimmed PATH (52 entries) = 952 / 0 / 11  (sum 963, exit 0, stdout 120218 bytes)
#   pwsh 7.6.7     normal PATH (61 entries) = 935 / 0 / 28  (sum 963, exit 0, stdout 122198 bytes)
#   pwsh 7.6.7     trimmed PATH (52 entries) = 927 / 0 / 36  (sum 963, exit 0, stdout 123013 bytes)
# Registration first, then green: the teeth pen probe came back 959 / 1 / 3 and the single red was
# A-14a (gate-meta measured banners=24,lines=1363 against the declared 1355 - the eight new lines
# fall inside that family banner span in the selftest body). 0730799 moved that one number;
# declared stayed 963, because the plants carry the SAME check name - teeth add no name.
# The census reports its own plant size: index plant census found=3 of 6 planted lines - three live
# names recovered, the space-indented, tab-indented and flush-left comment plants all rejected.
# Before this pen the plant set had exactly one comment shape (space-indented): the shape a /^#/
# filter passes, which is what the offline name census actually carried.
# Off-tree counterexample for that tool (Node, so named by artifact, not by check name): rebuilt
# with the backslash restored and its own plant test, it refuses to print when the plant is wrong -
# SELFTEST plant: counted=4 (want 1) -> REFUSE, exit 1, zero artifacts
# (_tmp/sup/curel04-teeth-refusal.txt). Six-tip phantom-free name series re-taken with it:
# 1,014 / 1,034 / 1,034 / 1,035 / 1,035 / 1,035; the two archived census artifacts kept their shas
# (6a2545632c3c / 9b72cc520732) - the rebuilt tool writes under new file names only.
# What these four cells still do NOT cover: the live face of CU-REL-01 - four counterexample live
# checks, the positive relative click, the --json envelope and the focus two-state read - all
# reported as NOT VERIFIED, not as a pass.
# v4.4.2 (G-23 whole-stream evidence) ACQUISITION READINGS, taken 2026-10-21 at the four per-cell
# TAKEN stamps 2026-10-21T14:22:11 / 2026-10-21T14:25:26 / 2026-10-21T14:28:34 / 2026-10-21T14:31:58 (each stamp is self-reported by the process that ran the cell).
# The four lines below are generated from _tmp/sup/curel15-mat3/curel15mat3.matrix.json by
# _tmp/sup/curel15-register-pen.cjs, not typed from memory. Harness = the accepted A-25/G-21 gate copy,
# DTX_QUARANTINE OUTSIDE the repository (the g20 directory under the document-operations tree), the PATH
# trim applied to the CHILD only, every engine string self-reported by the process that ran the gate
# (G-18). Registration moved in this same pen, first red then registered (no reading was edited to fit a
# run): audit-output banners=10 with lines 750->856 (the 106 lines G-23 adds land inside that family
# banner span), gate-meta 1363->1365 (the two comment lines the S-89 census edit adds), audit-output
# emitters 75->78, S-89 consumers 2->4 (2 child gates + 2 plants), declared 963->966 (+3 checks). The
# A-14a census still self-prints banners=153 for 15 families. The evidence directory is named per process
# (json-probe-evidence-<pid>, under TEMP, outside the repository) and the plant check removes it again when
# it is empty, so a healthy run leaves no trace at all and two gates running at once cannot count each
# other's litter (dir-state=gone is asserted, not printed only).
# The hardening above is the SECOND commit of this card: the four cells below were taken AFTER it, on the
# content this pen commits. The per-pid directory name is built from a .NET call rather than $PID because
# the A-14b context lint forbids a lifted body from reading a variable it did not declare - writing $PID
# read `A-14b state gap: pid=free-read-at-19777` (a true reach-outside, caught by the gate, first-hand).
# Registration after that edit: audit-output lines 856->873 (the two added comment lines plus the cleanup
# block land inside that family's banner span), banner census unchanged at 153 for 15 families.
# HARDENED-RUN CELLS, measured after the per-pid evidence directory and the cleanup landed (the
# four lines above were taken on the content before these comment lines existed - the difference is
# comments only, and the committed tip is re-measured in a detached worktree, see the receipt):
#   5.1.26100.9711 normal PATH (61 entries) = 963 / 0 / 3  (sum 966, exit 0, stdout 120599 bytes, TAKEN 2026-10-21T15:13:16)
#   5.1.26100.9711 trimmed PATH (52 entries) = 955 / 0 / 11  (sum 966, exit 0, stdout 121465 bytes, TAKEN 2026-10-21T15:16:32)
#   7.6.7 normal PATH (61 entries) = 938 / 0 / 28  (sum 966, exit 0, stdout 123451 bytes, TAKEN 2026-10-21T15:19:39)
#   7.6.7 trimmed PATH (52 entries) = 930 / 0 / 36  (sum 966, exit 0, stdout 124260 bytes, TAKEN 2026-10-21T15:23:02)
#   5.1.26100.9711 normal PATH (61 entries) = 963 / 0 / 3  (sum 966, exit 0, stdout 120513 bytes, strict ^FAIL 0)
#   5.1.26100.9711 trimmed PATH (52 entries) = 955 / 0 / 11  (sum 966, exit 0, stdout 121377 bytes, strict ^FAIL 0)
#   7.6.7 normal PATH (61 entries) = 938 / 0 / 28  (sum 966, exit 0, stdout 123357 bytes, strict ^FAIL 0)
#   7.6.7 trimmed PATH (52 entries) = 930 / 0 / 36  (sum 966, exit 0, stdout 124172 bytes, strict ^FAIL 0)

# What this pen adds that a red can now point at: Write-JsonProbeEvidence writes BOTH streams whole,
# with the child real exit code and the parse exception text, BEFORE the dump formatter cuts a head -
# measured: the two planted shapes print heads that both end in the same cut marker and neither head
# carries the tail token, while the evidence file does.
# v4.4.2 (G-22 fold) REGISTRATION READINGS, taken 2026-10-21 at the four per-cell TAKEN stamps 2026-10-21T16:38:39 / 2026-10-21T16:42:12 / 2026-10-21T16:45:41 / 2026-10-21T16:49:17 (each stamp is self-reported by the process that ran the cell).
# The four cell lines below are generated from _tmp/sup/curel20-mat2/curel20mat2.matrix.json by
# _tmp/sup/curel20-register-pen.cjs, not typed from memory.
# What this pen changes: the live ladder emitted the OCR-unavailable skip from inside a one-line
# `if (-not $ocrOk) { ... }`, so the anchored index rule (a name counts when the emitter starts the line)
# never saw it - the name was in the source, was NOT in the published index, and the run could skip under a
# name the index cannot list. The emitter now stands on its own line. This adds no check to the COUNT
# (declared stays at the number below), it only lets an existing name enter the index - which is why the
# ledger says "no new check count", not "the name set is unchanged".
# Registration moved in this same pen, first red then registered (no reading was edited to fit a run): A-14a
# printed the drift verbatim as
#   family attribution drift: live-suite=gotbanners=20,lines=3144-wantbanners=20,lines=3142
# and the two added lines are the fold itself; the registered tally is that printed value, not an arithmetic
# guess. The gate ran clean afterwards in all four contexts (harness = the accepted A-25/G-21 gate copy,
# DTX_QUARANTINE outside the repository, PATH trim applied to the CHILD only, engine strings self-reported
# by the process that ran the gate (G-18)).
# NOT taken in this pen: the --live evidence that the run really skips under that name. Get-OcrEngine has no
# environment switch, so the only honest shape is a one-off tree with $ocrOk pinned false, and that ladder
# needs the desktop - which is a separate window, so this stays unverified and is not written as verified.
#   5.1.26100.9711 normal PATH (61 entries) = 963 / 0 / 3  (sum 966, exit 0, strict ^FAIL lines 0, stdout 120609 bytes, TAKEN 2026-10-21T16:38:39)
#   5.1.26100.9711 trimmed PATH (52 entries) = 955 / 0 / 11  (sum 966, exit 0, strict ^FAIL lines 0, stdout 121467 bytes, TAKEN 2026-10-21T16:42:12)
#   7.6.7 normal PATH (61 entries) = 938 / 0 / 28  (sum 966, exit 0, strict ^FAIL lines 0, stdout 123454 bytes, TAKEN 2026-10-21T16:45:41)
#   7.6.7 trimmed PATH (52 entries) = 930 / 0 / 36  (sum 966, exit 0, strict ^FAIL lines 0, stdout 124261 bytes, TAKEN 2026-10-21T16:49:17)
# v4.4.3 (G-24): two offline checks pin exit-watchdog JSON stream routing and Release-Press receipt handling.
# v4.4.4 (G-25): one offline check pins owned-path evidence cleanup and foreign-sentinel survival.
# v4.5.0 (CU-CALL) CORRECTED 2026-10-24 (supervisor K4 item 5a, the 1c0a30c/8e3cb4b tips keep the old line): nine offline checks ride this label - eight CU-CALL runtime checks pin caller identity, overlap state, recovery, privacy and bounds, plus the TB-7 real desktop identity API cell that carries the CU-CALL label.
# TB-7 adds one real desktop identity API check to the cumulative offline total.
# v4.5.1 (CU-REL-02): seven offline checks pin wheel unit conversion, axis selection and preflight rejection.
# v4.5.2 (CU-REL-03): seven offline checks pin wheel target guards, SendInput counts and truthful receipts.
# v4.5.3 (CU-REL-04): nine offline checks pin bounded scroll-effect observation and honest fallback states.
# v4.5.4 (CU-REL-05): three offline checks pin shot path preservation, parameter rejection and pre-capture ordering.
# The parent emitted 970 outcomes despite declaring 966; the current added check emitters contribute 38.
# A-25 compares the complete offline run to the measured 1008, including its unique result-name set.
# v4.5.5 (TB-1, no version bump): three offline checks pin the version definition, the entry header,
# the Usage banner and the runtime source_version as one source - the constant had drifted to 4.5.3
# under a 4.5.5 header, and planted missing/wrong/frozen copies are rejected. Measured 2026-10-24 on
# this box, PS 5.1 full offline, clean child environment (inherited PSModulePath removed); the
# four-context matrix stays with the final candidate gate.

# v4.4.2 (TB-6 fold) REGISTRATION READINGS, taken 2026-10-23. This block is deliberately NOT shaped
# like the two above it, and says so rather than borrowing their shape: those record a four-cell
# matrix (engine x PATH) taken on a clean tree; this one records ONE run of the dirty candidate tree
# plus what the product's own rulers measure after the edit. The four-cell matrix on a clean detached
# snapshot at this commit is the step that follows the commit, and its readings land in this pen's
# iteration-log entry - nothing here is claimed for a context that was not run.
# What this pen adds to the count: four gate NAMES in the docs-contract family, each of them written
# as a check/skip pair - two in the skill-package block (the guide ships inside the package as a
# byte-for-byte copy of the root document and the installer refuses the install BEFORE its first
# write; the delivery predicate flags the planted installer that drops both the refusal and the copy
# step) and two in the new repository-face block (the entry document links the guide as a sibling and
# the guide carries the messaging red line; the predicate flags each planted copy). 35 -> 51 static
# emitters is +16 SITES = 8 NAMES, and 8 names is the +8 that took 966 -> 974.
# CORRECTED in the TB-3 pen (2026-10-23), because the sentence above said two wrong things. First: the
# +8 was NOT this pen alone. Four of those eight names are TB-4 and TB-5 checks that already EMITTED on
# the parent tip - bd26f2b measured 970 run-time against a declaration of 966, which is the +4 that pen
# registered rather than wrote - and this pen contributed the other four. Second: a name does not emit
# "from both arms of its if". The arms are mutually exclusive, so each name contributes exactly ONE
# emitted line per run; what makes a skip arm count in the total is ST-SkipRegion emitting the same name
# on the arm that cannot run, which is why the [passed/failed/skipped] triple sums to the same 977 in
# every engine and PATH context while only the passed part moves. Both facts are the product's own
# numbers, not prose: the per-cell triples below and the A-14b emitter census (registered=1106 ast=1106).
# First red, then registered - no reading was edited to fit a run. The dirty-tree run
# (tb6-gate-dirtytree-ps51.txt, log mtime 2026-10-23T08:30:54, aggregate mode 22 files) ended
#   ----- selftest: 968 passed, 3 failed, 3 skipped -----
# and the three reds were exactly the three registration lints this pen closes, each quoting its own
# numbers instead of a chosen one:
#   lint (A-14a)  docs-contract=gotbanners=7,lines=293-wantbanners=7,lines=294;unclaimed-banners=4-lines=231
#   lint (A-14b)  notes=[Invoke-SelftestFamily-DocsContract-want35-got51]
#   contract      declared=966 this-run-would-be=974
# Read that first line twice, because it is two separate facts and only one of them is this pen: the
# 4 unclaimed banners with 231 lines are the banners this pen added, and 293 against the registered 294
# is the OLD span having moved by one line when the installer half of the family was rewritten. The
# registered value is now the measured one for the whole body: 11 banners / 524 lines = 293 + 231, and
# that arithmetic is a print, not a guess - tb6-banner-predict-ps51.txt runs the product's own rulers
# (Parse-SourceForInventory, Get-FamilyBannerRecords, Get-FamilyAssignText, Get-FamilyAgreement) over
# the post-edit aggregate and reports BANNERS-TOTAL=157 with all fourteen other families byte-equal to
# their registered rows and no banner left unclaimed. The same file carries the total-banner move
# 153 -> 157 that the hard-coded count in the split-machine family was pinned to.
# Why the comment lines added HERE move nothing: A-14a measures a span as the difference between
# banner lines inside one family body, and the aggregate span map is recomputed from the files at run
# time (Get-SourceLineSpans), so growing the entry shifts absolute line numbers and no registered
# number. Verified against the run above, which already carried this pen's family edits.
# TB-3 (2026-10-23): same discipline, one more round, and the gate printed the number for me. The
# dirty-tree probe cell (tb3-cand/tb3cand.ps51.normal.*, exit 1 in 216.794 s, aggregate mode 22 files)
# ended
#   ----- selftest: 971 passed, 3 failed, 3 skipped -----
# with stdout:1134 carrying `declared=974 this-run-would-be=977`. 974 + 3 = 977 is that print, not my
# arithmetic, and the three are this card's e2e checks (the fault landing mid-loop, the planted pre-TB-3
# shape, the failed move); no other emitter moved. stdout:105 printed the other half of the pair,
# `overview check total: doc=974 declared=974`, so the document line moves with the declaration.
# Two of the three reds were this pen's own defects rather than registration drift, and both were
# repaired from the gate's print:
#   lint (A-14b) `A-14b state gap: this=free-read-at-26165` (stdout:62) - the first version of the
#     fixture wrapper used $this inside ScriptProperty getters. $this is automatic for such a getter but
#     is not a name this lifted body binds, so the gate is right to read it as a reach outside the body
#     (same trap the split-out families were caught on before: desktop.ps1:294). The getters now close
#     over the wrapper's own parameters via .GetNewClosure(); tb3-fix-probe-{ps51,pwsh7}.txt measured the
#     replacement forwarding Name/FullName/Length identically on 5.1.26100.9711 and 7.6.7.
#   e2e (TB-3) case 2 printed `midloop=midloop-rows=0 destFiles=4 rowsOnDisk=4 returned=True escape=[]`
#     (stdout:596): the vacuity guard was itself not carrying a fault. SetAttributes on a path that does
#     not exist yet blocks nothing, and the planted copy's one after-the-loop AppendAllText therefore
#     SUCCEEDED - four rows written, nothing refused. The fault now creates a missing MANIFEST read-only
#     instead of skipping it, and the same fixture measures back destFiles=4 with rows=0 and a non-empty
#     escape on both engines (tb3-fix-probe A-shape) - which is precisely the pre-TB-3 behaviour the card
#     asks to be shown: every move made, no record written, the run dying on its own single flush.
# The registration numbers come from the product's own rulers, re-measured after those repairs. Round 1
# (tb3-measure-ps51.txt, tb3-measure-pwsh7.txt, byte-identical) printed got=25 banners / 1506 lines and
# ast=127 emitters against the pre-registration tables; those were the values registered. The two
# repairs then added 16 body lines and no emitter, and the final round
# (tb3-measure-r2-ps51.txt / -pwsh7.txt / -pwsh765.txt - all three byte-identical, sha256
# 16bbb3938319f27285f54eef0447f62e1ca700e31e786e17e8e33041812f7275, i.e. the third named binary on this
# box measured with the other two) prints BANNERS-TOTAL=158, ASSIGN gate-meta/25/1522, A14B-SUM
# registered=1106 ast=1106 with no drift row, A23-GAP=[] at shots-cleanup=5 / handler-cases=13 /
# total=24, and INDEX entries=1110 with all three TB-3 names indexed. The numbers that moved are
# therefore two: gate-meta lines 1506 -> 1522, and the declared total 974 -> 977.
# v4.4.2 (TB-2, 2026-10-24, no version bump): one dynamic cell pins the send-side half of the shared
# CDP budget - a loopback peer that handshakes and then never read keeps SendAsync pending until
# the budget expires during the send phase, and the call returns bounded with the phase named.
# Measured on this box, PS 5.1 full offline, clean child environment; the four-context matrix
# stays with the integration gate.

# v4.5.5 CONVERGENCE PEN (2026-10-24, candidate codex/cu-candidate = 8e3cb4b x 248c940): both lines' declarations and
# family tables above were registered against their own line only; this candidate re-measures everything on the
# merged tree - the declared value below is provisional until the first gate run prints this-run-would-be, and every
# registered tally moves to that printed value, not to arithmetic (no 1011+979, no max).
# CU-OPS-COMPLETE-20261026-01: 1020 -> 1022. The four mouse/keyboard handlers gained their
# modifier and button guards and package A added the five process commands; the two new checks
# are the private-flag table's raised expectation (13 -> 18 entries) and the action --json table
# now closing over the three native-keyboard commands. Measured, not computed: this is the value
# the gate printed for this tree.
# v4.6.1: +5 for package G's format-list branch, the named-extra gate, the restore-outcome map and
# the clip-info metadata-only body lint (1038 -> 1043). Measured again on the 13:41 clean-host run:
# the offline run emits 1044 checks, so the declaration is the measured total (1043 -> 1044).
$script:DeclaredCheckTotal = 1044
# ---------- v4.4.0 (A-03): the source set - ONE list, four consumers ----------
# Three pure leaves first, because the configuration block below runs at LOAD time and a
# function defined further down the file does not exist yet when it runs. Each leaf takes
# an explicit root or list and reads no global, which is the only reason the aggregate
# path can be tested at all before the first lib/ file exists.
function Get-SourceModeBeside([string]$Root) {
  if (Test-Path -LiteralPath (Join-Path $Root 'lib') -PathType Container) { return 'aggregate' }
  return 'single-file'
}

function Test-EntryFirstSource([string[]]$Files) {
  return (@($Files).Count -ge 1 -and "$($Files[0])" -ceq 'desktop.ps1')
}

# !! A declared file missing on disk THROWS instead of being skipped. "Cannot see it" must
#    never be reported as "nothing wrong" - v4.1.3 watched thirteen tracked names vanish from
#    the working tree while the gate printed green, and a half-landed split fails the same way.
function Get-AggregatedSource([string]$Root, [string[]]$Files) {
  $parts = @()
  foreach ($fName in @($Files)) {
    $fPath = Join-Path $Root "$fName"
    if (-not (Test-Path -LiteralPath $fPath -PathType Leaf)) {
      throw "source set: '$fName' is declared in StSourceFiles but is not on disk at $fPath - the declaration and the file must land in the same commit"
    }
    $parts += [System.IO.File]::ReadAllText($fPath, [System.Text.Encoding]::UTF8)
  }
  return ($parts -join "`n")
}

# Name-based inventory of the statements that run at LOAD TIME. Moving a section is only a
# pure move if these come along; dropping one changes state initialisation with no behaviour
# difference and no other gate would notice. Pinned by the WHOLE STATEMENT (name and
# value) at column zero, never by a line number - a move that also rewrites a literal is
# not a pure move, and a value read through a nested indentation is not a load-time write.
function Get-LoadTimeInitsMissing([string[]]$Lines, [string[]]$Expected) {
  $seen = @{}
  foreach ($ln in @($Lines)) {
    $k = "$ln"; if ($k.StartsWith('$script:')) { $seen[$k] = $true }
  }
  $miss = @()
  foreach ($nm in @($Expected)) { if (-not $seen.ContainsKey($nm)) { $miss += $nm } }
  # !! Returns a COMMA-JOINED STRING, never an array. A PowerShell function that returns a
  #    one-element array hands the caller a scalar, so @($x).Count reads 1 for 'one missing'
  #    while the empty case's shape depends on the engine - the exact ambiguity that lets a
  #    counting gate lie. A string has no second shape.
  return ($miss -join ',')
}

# !! StSourceFiles is at once (a) the dot-import order at the entry, (b) the order selftest
#    aggregates its own text in, (c) install.ps1's stitcher concatenation order and (d) the
#    basis of StFileMap. Deliberately one list: a second copy is how the four drift apart in
#    silence - the tree still runs while the line anchors and the installed product do not.
# !! desktop.ps1 comes FIRST: the entry's line numbers must not move when a lib/ split lands.
# !! Same-commit rule: a new lib file needs +1 here AND +1 dot-import line at the entry AND
#    +1 in the overview's tracked list. Each missing half fails differently - a file absent
#    from this list is never read by the gates, a list entry without its file throws above.
$script:StSourceFiles = @('desktop.ps1', 'lib/handlers-read.ps1', 'lib/handlers-act.ps1', 'lib/handlers-ui.ps1', 'lib/handlers-batch.ps1', 'lib/caller-runtime.ps1', 'lib/selftest.ps1', 'lib/selftest-split-machine.ps1', 'lib/selftest-repo-contract.ps1', 'lib/selftest-clipboard-input.ps1', 'lib/selftest-challenge-workflow.ps1', 'lib/selftest-capture-ocr.ps1', 'lib/selftest-flags-grammar.ps1', 'lib/selftest-window-targeting.ps1', 'lib/selftest-chrome-cdp.ps1', 'lib/selftest-docs-contract.ps1', 'lib/selftest-popup-occlusion.ps1', 'lib/selftest-audit-output.ps1', 'lib/selftest-expect-family.ps1', 'lib/selftest-drag-press.ps1', 'lib/selftest-live-suite.ps1', 'lib/selftest-gate-meta.ps1', 'lib/help.ps1')
$script:StFileMap = @{}
foreach ($sfName in @($script:StSourceFiles)) { $script:StFileMap[$sfName] = (Join-Path $PSScriptRoot "$sfName") }
# ---------- v4.4.0 (A-11a): the path anchors ----------
# Measured on BOTH engines before writing a line of it: inside a function defined in a dot-sourced
# file, $PSCommandPath is THAT file and $PSScriptRoot is ITS directory - not the entry and not the
# tool root. The selftest section reads those two variables 91 times (63 spawns a child through the
# entry, 28 locates the repo root, the README, git and its own aggregated source), so moving the
# section as written would repoint every one of them into lib/. The entry publishes what the whole
# tree means by "the tool" and the section reads the anchors instead; the three occurrences inside
# single-quoted fixtures are text, not reads, and stay exactly as they are.
$script:ToolRootPath = $PSScriptRoot
$script:ToolEntryPath = $PSCommandPath

function Get-PathReadOwnerList($Parsed) {
  # ';'-joined 'owner::variable' keys, duplicates kept. Owners are the same shape as the command-name
  # inventory: '<script>' for the entry's own top level, 'fn:<name>' inside a function. String
  # fixtures do not appear here because they are not reads - that is the whole reason this walks the
  # AST instead of grepping.
  if ($null -eq $Parsed) { return '' }
  $root = $Parsed.Root
  if ($null -eq $root) { return '' }
  $out = @()
  foreach ($v in @($root.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true))) {
    $t = [string]$v.Extent.Text
    if (($t -cne '$PSCommandPath') -and ($t -cne '$PSScriptRoot')) { continue }
    $fn = Get-AstFunctionName $v
    if ($fn -eq '') { $out += ('<script>::' + $t) } else { $out += ('fn:' + $fn + '::' + $t) }
  }
  return ($out -join ';')
}

function Get-CodeTextWithoutComments([string]$Path) {
  # A-23 (criterion-10): the file's own text with every Comment token the PARSER recognised blanked to
  # spaces, length and line structure preserved so an offset still means what it said.
  # Ruling 2026-10-19 (option A) revised the design's "no current-version literal anywhere in lib" to
  # "none in lib CODE", because the collaboration spec requires a dated comment to name the version it
  # landed in - the tree already carries 141 such mentions of the next version number, and rewriting them
  # in bulk to keep a counter happy would destroy the very provenance the spec asks for.
  # Only comments are excluded. String literals, here-strings and nested script blocks stay in scope:
  # they are code that can carry a version value, which is what the claim is about.
  $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
  $toks = $null
  $perr = $null
  [void][System.Management.Automation.Language.Parser]::ParseInput($raw, [ref]$toks, [ref]$perr)
  $chars = $raw.ToCharArray()
  $comments = 0
  $blanked = 0
  foreach ($tk in @($toks)) {
    if (("$($tk.Kind)") -cne 'Comment') { continue }
    $comments = $comments + 1
    $from = [int]$tk.Extent.StartOffset
    $to = [int]$tk.Extent.EndOffset
    if (($from -lt 0) -or ($to -le $from) -or ($to -gt $chars.Length)) { continue }
    for ($i = $from; $i -lt $to; $i++) {
      if ($chars[$i] -eq "`n") { continue }
      if ($chars[$i] -eq "`r") { continue }
      $chars[$i] = ' '
      $blanked = $blanked + 1
    }
  }
  # The face of the scan has to be reported, not assumed: 'no hit' only means something when the caller can
  # see how much was actually searched and how many literals were in range. A blanked file that yields zero
  # code tokens is an empty ruler, and an empty ruler is what the ruling calls out as the failure to guard.
  $toks2 = $null
  $perr2 = $null
  $blank = (-join $chars)
  [void][System.Management.Automation.Language.Parser]::ParseInput($blank, [ref]$toks2, [ref]$perr2)
  $codeTokens = 0
  $literals = 0
  foreach ($tk in @($toks2)) {
    $k2 = "$($tk.Kind)"
    if (($k2 -ceq 'NewLine') -or ($k2 -ceq 'EndOfInput') -or ($k2 -ceq 'LineContinuation')) { continue }
    $codeTokens = $codeTokens + 1
    if (($k2 -ceq 'StringConstant') -or ($k2 -ceq 'StringExpandable') -or ($k2 -ceq 'Number')) { $literals = $literals + 1 }
  }
  return @{ Text = $blank; Bytes = [System.Text.Encoding]::UTF8.GetByteCount($raw); Lines = @(($raw -split "`n").Count);
    CommentTokens = $comments; BlankedChars = $blanked; ParseErrors = @($perr).Count;
    CodeTokens = $codeTokens; LiteralSamples = $literals; SearchedChars = $blank.Length }
}

function Get-ExitOwnerList($Parsed) {
  # A-23 (criterion-5): ';'-joined owner keys, one per `exit` statement, duplicates kept. A statement inside a
  # moved handler body is keyed by the CASE name ('Invoke-Handler-type' -> 'type'), because which FILE a
  # body sits in is exactly the thing this refactor keeps moving, and a stitched artifact has no files at
  # all - the same list has to mean the same thing on both sides of the stitch. Anything else keeps its
  # function name ('fn:Invoke-ScriptBatch') or '<script>' for the entry's own top level, so an exit
  # planted somewhere the whitelist has never heard of shows up as a key, not as a quieter total.
  # AST, not text: the case body fixtures in the selftest quote command lines as data.
  # '-no-parse' rather than '': a source that could not be parsed has to show up as a key the whitelist
  # does not know, because an empty string and a failed measurement would otherwise read the same.
  if ($null -eq $Parsed) { return '-no-parse' }
  $root = $Parsed.Root
  if ($null -eq $root) { return '-no-parse' }
  $out = @()
  foreach ($e in @($root.FindAll({ param($n) $n -is [System.Management.Automation.Language.ExitStatementAst] }, $true))) {
    $fn = Get-AstFunctionName $e
    if ($fn.StartsWith('Invoke-Handler-')) { $out += $fn.Substring(15) }
    elseif ($fn -eq '') { $out += '<script>' }
    else { $out += ('fn:' + $fn) }
  }
  return ($out -join ';')
}

function Get-StitchResidue([string[]]$Lines) {
  # A-23 (criterion-9): the claim a source tree cannot make about itself - "nothing is still being imported at
  # run time, and no stitch instruction survived". Two named shapes: a stitch marker attached to CODE
  # (the expander left one, or somebody planted one), and a dot-source of a lib path that still executes.
  # The needle is assembled from code points because this tree legitimately mentions the marker as DATA
  # (the split-machine fixtures quote a whole dot-import line, the aggregation helper names the marker in
  # a comment); a literal here would be counted by the scan it configures - P-05/P-06/X-01 precedents.
  # "Inside a string literal or a comment" is decided from the parser's own extents, line AND column:
  # a line-anchored text rule would flag those fixtures (false red on every installed copy) and still
  # miss a marker hiding beside a quote on a line of code (false green). It costs one parse of the
  # artifact, and this gate only runs in single-file mode, where the run is measuring one file anyway.
  # The spans come off the TOKEN stream by Kind: a comment is Kind=Comment (its class is a plain Token,
  # there is no CommentToken type), a single-quoted literal is StringLiteral and a double-quoted one
  # StringExpandable. The first draft asked for [..Language.CommentToken] and [..StringLiteralAst];
  # neither exists, and both fail loudly only when the gate actually runs - which is once per install.
  $needle = Get-CharCodeWord @(0x3C, 0x3C, 0x20, 0x73, 0x74, 0x69, 0x74, 0x63, 0x68, 0x3A, 0x20)
  $text = (@($Lines) -join "`n")
  $toks = $null
  $perr = $null
  [void][System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$toks, [ref]$perr)
  $spans = @()
  foreach ($tk in @($toks)) {
    $k = "$($tk.Kind)"
    if (($k -ceq 'Comment') -or ($k -ceq 'StringLiteral') -or ($k -ceq 'StringExpandable')) {
      $spans += , @($tk.Extent.StartLineNumber, $tk.Extent.StartColumnNumber, $tk.Extent.EndLineNumber, $tk.Extent.EndColumnNumber)
    }
  }
  $out = @()
  $n = 0
  foreach ($l in @($Lines)) {
    $n = $n + 1
    $t = [string]$l
    $at = $t.IndexOf($needle)
    while ($at -ge 0) {
      $col = $at + 1
      $endCol = $col + $needle.Length - 1
      $isData = $false
      foreach ($p in @($spans)) {
        if (@($p).Count -lt 4) { continue }
        $sl = [int]$p[0]; $sc = [int]$p[1]; $el = [int]$p[2]; $ec = [int]$p[3]
        if (($sl -lt $n -and $n -lt $el) -or
            ($sl -eq $n -and $sc -le $col -and ($n -lt $el -or ($el -eq $n -and $ec -ge $endCol))) -or
            ($el -eq $n -and $sl -lt $n -and $ec -ge $endCol)) { $isData = $true; break }
      }
      if (-not $isData) { $out += ('marker-at-' + $n + ':' + $col) }
      $at = $t.IndexOf($needle, $at + $needle.Length)
    }
    if (($t -match '^\s*[\.&]\s') -and ($t -match 'lib[\\/][A-Za-z0-9._-]+\.ps1')) { $out += ('dot-import-at-' + $n) }
  }
  return @{ Needle = $needle; Breaches = ($out -join ';'); Count = @($out).Count; DataSpans = @($spans).Count; ParseErrors = @($perr).Count }
}

function Get-PathReadCountInFunction($Parsed, [string]$FunctionName) {
  # String again, for the same reason as every other count here: an int and a -1 are indistinguishable
  # from a scalar once the caller wraps the result, and a measuring gate has to be able to tell
  # "measured zero" from "did not measure".
  if ($null -eq $Parsed) { return '-no-parse' }
  $root = $Parsed.Root
  if ($null -eq $root) { return '-no-parse' }
  $target = $null
  foreach ($fd in @($root.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
    if (([string]$fd.Name) -cne $FunctionName) { continue }
    $target = $fd
    break
  }
  if ($null -eq $target) { return '-absent' }
  $c = 0
  foreach ($v in @($target.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true))) {
    $t = [string]$v.Extent.Text
    if (($t -ceq '$PSCommandPath') -or ($t -ceq '$PSScriptRoot')) { $c = $c + 1 }
  }
  return ([string]$c)
}

# Who still reads the automatic paths, after the selftest section stopped. Two rows are the anchors
# themselves - they can only be assigned at the top level of the entry, which is exactly where the
# automatic variable still means the entry. The rest are sections that have NOT moved yet, so the
# variable still names the right thing inside them. Each such row has to disappear in the commit that
# moves its owner - a stale row reads as compliance for a function that no longer exists.
$script:StPathReadOwners = @(
  '<script>::$PSCommandPath=1',
  '<script>::$PSScriptRoot=26',
  'fn:Get-WorkspaceSummary::$PSCommandPath=1',
  'fn:Get-WorkspaceSummary::$PSScriptRoot=1',
  'fn:Invoke-ReplayLog::$PSCommandPath=1',
  'fn:Write-TabManifest::$PSScriptRoot=1'
)
# The ONLY mode discriminator is a lib/ directory beside the entry: an installed skill copy
# is one stitched file and measures itself, never the tree it was assembled from.
# v4.4.0 A-04: an aggregate line number is only worth printing if a reader can tell WHICH
#    file owns it. The span map uses the same per-file line counts the loader splits by, and
#    the +1 per boundary is the joiner's own extra line break - pinned by a gate that compares
#    each file with itself, not by this comment.
function Resolve-SourceLineFromSpans([int]$Line, [object]$Spans) {
  foreach ($sp in @($Spans)) {
    if (($Line -ge [int]$sp.Start) -and ($Line -lt ([int]$sp.Start + [int]$sp.Count))) {
      return ([string]$sp.File + ':' + ($Line - [int]$sp.Start + 1))
    }
  }
  return ('beyond-aggregate:' + $Line)
}

# !! Single-file mode keeps printing a bare number: that is what the installed product
#    prints today, and a diagnostic is not permission to change a stream a caller matches on.
function Format-SourceLineRef([int]$Line) {
  if ("$script:StSourceMode" -cne 'aggregate') { return "$Line" }
  return Resolve-SourceLineFromSpans $Line $script:StSourceSpans
}

# !! Accepts a list of 1-based source lines; a negative entry means "not found" and is
#    printed as such rather than resolved, so a scan that found nothing stays visible.
function Format-SourceLineList([object]$Items) {
  $out = @()
  foreach ($it in @($Items)) {
    $n = [int]$it
    if ($n -lt 1) { $out += ([string]$n) } else { $out += Format-SourceLineRef $n }
  }
  return ($out -join ', ')
}

function Get-SourceLineSpans([string]$Root, [string[]]$Files) {
  $spans = @()
  $acc = 0
  foreach ($f in @($Files)) {
    $fPath = Join-Path $Root "$f"
    if (-not (Test-Path -LiteralPath $fPath -PathType Leaf)) { throw "span map: declared file is not on disk: $fPath" }
    $t = [System.IO.File]::ReadAllText($fPath, [System.Text.Encoding]::UTF8)
    $n = @($t -split "`r?`n").Count
    $spans += [pscustomobject]@{ File = "$f"; Start = ($acc + 1); Count = $n }
    # !! No extra +1 per boundary: each file text ends with its own line break, and the empty
    #    segment that break produces IS the boundary the joiner would otherwise add. Measured on
    #    a planted pair (a=4 segments, b=3, aggregate=7, b starts at aggregate line 5).
    $acc = $acc + $n
  }
  return @($spans)
}
# v4.4.0 A-05: the two things a split can get wrong in silence - the declared list drifting
#    away from what is on disk, and the entry's dot-import lines drifting away from the declared
#    list. Both are pure predicates over explicit input so they can be planted-tested today,
#    before a lib/ directory exists to break.
function Get-SourceSetDiscrepancy([string]$Root, [string[]]$Declared) {
  $notes = @()
  $decl = @{}
  foreach ($d in @($Declared)) { $decl[[string]$d] = $true }
  foreach ($d in @($Declared)) {
    $p = Join-Path $Root ([string]$d)
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { $notes += ("declared-missing:" + [string]$d) }
  }
  $libDir = Join-Path $Root 'lib'
  $onDisk = @()
  if (Test-Path -LiteralPath $libDir -PathType Container) {
    $onDisk = @(Get-ChildItem -LiteralPath $libDir -Filter '*.ps1' -File | ForEach-Object { 'lib/' + $_.Name })
  }
  foreach ($o in $onDisk) { if (-not $decl.ContainsKey([string]$o)) { $notes += ("on-disk-undeclared:" + [string]$o) } }
  return ($notes -join ',')
}

# !! Both markers are assembled at run time: a scan token written as a literal is present in
#    the text this predicate reads (P-05/P-06/X-01 precedent, and A-04 hit it for real).
function Get-DotImportDiscrepancy([string[]]$Lines, [string[]]$Declared) {
  $head = '. (Join-Path ' + '$PSScriptRoot '
  $mark = '<<< ' + 'stitch: '
  $sq = [string][char]39
  $found = @()
  $actual = @()
  foreach ($l in @($Lines)) {
    $t = [string]$l
    if (-not $t.StartsWith($head)) { continue }
    # v4.4.0 (S-93): the path between the quotes is what the loader ACTUALLY reads. Before this the
    # predicate compared only the `# <<< stitch:` tail, so two lines could swap their real files, keep
    # their markers in declared order, and report clean - the comment was certifying itself.
    $rest = $t.Substring($head.Length)
    $o1 = $rest.IndexOf($sq)
    $o2 = -1
    if ($o1 -ge 0) { $o2 = $rest.IndexOf($sq, $o1 + 1) }
    if ($o1 -ge 0 -and $o2 -gt $o1) { $actual += $rest.Substring($o1 + 1, $o2 - $o1 - 1) } else { $actual += 'NO-PATH' }
    $mi = $t.IndexOf($mark)
    if ($mi -lt 0) { $found += ('NO-MARKER:' + $t.Trim()); continue }
    $found += $t.Substring($mi + $mark.Length).Trim()
  }
  $want = @(@($Declared) | Select-Object -Skip 1)
  $notes = @()
  if (@($found).Count -ne @($want).Count) { $notes += ("count-found=" + @($found).Count + "-want=" + @($want).Count) }
  if (@($actual).Count -ne @($want).Count) { $notes += ("count-actual=" + @($actual).Count + "-want=" + @($want).Count) }
  $lim = [Math]::Min(@($found).Count, @($want).Count)
  for ($i = 0; $i -lt $lim; $i++) {
    if ([string]$found[$i] -cne [string]$want[$i]) { $notes += ("order-at-" + $i + "=" + $found[$i] + "/" + $want[$i]) }
  }
  $aim = [Math]::Min(@($actual).Count, @($want).Count)
  for ($i = 0; $i -lt $aim; $i++) {
    if ([string]$actual[$i] -cne [string]$want[$i]) { $notes += ("path-at-" + $i + "=" + $actual[$i] + "/" + $want[$i]) }
  }
  return ($notes -join ',')
}
# v4.4.0 A-14r: the named hand-back chain, judged per name over the text BETWEEN the family that
#    produces a value and the family that consumes it. Registering a key in $script:StCtxKeys does not
#    prove a consumer can read a value that exists - the owner's boundary for this card is that the
#    write has to run produce -> named re-bind -> publish -> consume. Four notes are possible and all
#    four are planted: a missing re-bind, a missing publish, a publish that carries a DIFFERENT variable
#    than the re-bind bound (the interleaved value), and an order in which the consume line sits above
#    the publish. Comment lines are skipped, and the needles are built by concatenation so this body
#    never starts a line the scan could mistake for the chain it hunts.
function Get-HandbackChainGap([string[]]$Lines, [string]$Produce, [string]$Consume, [string[]]$Names) {
  $ls = @($Lines)
  # a blank needle would make StartsWith match every line, and an empty name list would answer
  # "nothing to check" for a chain that was never described - both are refusals, not readings.
  if (([string]$Produce -eq '') -or ([string]$Consume -eq '') -or ([string]$Produce -ceq [string]$Consume)) { return 'bad-needles' }
  if (@($Names).Count -eq 0) { return 'bad-names' }
  $notes = @()
  $notes = @()
  $notes = @()
  $p = -1; $c = -1
  for ($i = 0; $i -lt $ls.Count; $i++) {
    $t = ([string]$ls[$i]).Trim()
    if ($t.StartsWith('#')) { continue }
    if (($p -lt 0) -and $t.StartsWith($Produce)) { $p = $i }
    if (($c -lt 0) -and $t.StartsWith($Consume)) { $c = $i }
  }
  if ($p -lt 0) { $notes += ('no-produce:' + $Produce) }
  if ($c -lt 0) { $notes += ('no-consume:' + $Consume) }
  if (@($notes).Count -gt 0) { return ($notes -join ',') }
  if ($c -le $p) { return ('order-produce-consume=' + $p + '/' + $c) }
  $lo = $p + 1; $hi = $c - 1
  foreach ($n in @($Names)) {
    $rn = '$' + $n + ' = $Ctx['
    $pn = '$Ctx[''' + $n + '''] = $' + $n
    $alt = '$Ctx[''' + $n + '''] = $'
    $r = -1; $u = -1; $x = ''
    for ($i = $lo; $i -le $hi; $i++) {
      $t = ([string]$ls[$i]).Trim()
      if ($t.StartsWith('#')) { continue }
      if (($r -lt 0) -and $t.StartsWith($rn)) { $r = $i }
      if (($u -lt 0) -and $t.StartsWith($pn)) { $u = $i }
      if (($x -eq '') -and ($u -lt 0) -and $t.StartsWith($alt)) {
        $vid = ($t.Substring($alt.Length) -replace '[^A-Za-z0-9_].*$', '')
        if ($vid -ne $n) { $x = $vid }
      }
    }
    if ($r -lt 0) { $notes += ('no-rebind:' + $n); continue }
    if ($x -ne '') { $notes += ('publish-name-' + $n + '=$' + $x); continue }
    if ($u -lt 0) { $notes += ('no-publish:' + $n); continue }
    if ($u -lt $r) { $notes += ('order-rebind-publish-' + $n + '=' + $r + '/' + $u) }
  }
  return ($notes -join ',')
}
# v4.4.0 A-15 (design gate 12): the dispatcher case shape, judged from the AST and compared against the
#    TEXT shape every case scan in this tool uses. Three gates count dispatcher cases today (the flag
#    scan, the help index, F-00-A) and all three use the same regex over a "from this function to the
#    next ^function" interval, and none of them pinned the number. That is how a case can vanish twice
#    over: move a brace off the end of a case line and the strict scan stops seeing it while the switch
#    still dispatches it, so the count a later card compares against silently moves and no gate names
#    why. This predicate answers from what the switch REALLY has and reports every difference BY CASE
#    NAME, including the two registered exception shapes. Pure over explicit input, so the breach
#    shapes are plantable - measured live: AST clauses=79, strict-shape=76, single-line=3.
function Get-CaseShapeGap($Parsed, [string[]]$Lines, [string]$FunctionName, [string[]]$AllowedInline, [int]$ExpectedStrict, [int]$ExpectedTotal) {
  if ($null -eq $Parsed) { return '-no-parse' }
  if ($null -eq $Parsed.Root) { return '-no-parse' }
  if ([int]$Parsed.ErrorCount -gt 0) { return ('-parse-errors=' + [int]$Parsed.ErrorCount) }
  $ls = @($Lines)
  if (@($ls).Count -eq 0) { return '-no-lines' }
  $fn = $null
  foreach ($cand in @($Parsed.Root.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
    if (([string]$cand.Name) -cne [string]$FunctionName) { continue }
    $fn = $cand
  }
  if ($null -eq $fn) { return ('-absent-body:' + $FunctionName) }
  $sws = @($fn.Body.FindAll({ param($n) $n -is [System.Management.Automation.Language.SwitchStatementAst] }, $true))
  if (@($sws).Count -ne 1) { return ('switch-count=' + @($sws).Count) }
  $clauses = @($sws[0].Clauses)
  $rxStrict = '^    ''([a-z0-9-]+)'' \{$'
  $rxInline = '^    ''([A-Za-z0-9-]+)'' \{ .*\}$'
  $notes = @()
  $strict = @()
  $inline = @()
  foreach ($c in $clauses) {
    $cond = $c.Item1
    if ($cond -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $label = [string]$cond.Value }
    else { $notes += ('non-literal-label-at-' + [int]$cond.Extent.StartLineNumber); continue }
    $ln = [int]$cond.Extent.StartLineNumber
    if (($ln -lt 1) -or ($ln -gt @($ls).Count)) { $notes += ('label-line-outside-text:' + $label + '=' + $ln); continue }
    $t = [string]$ls[$ln - 1]
    if ([regex]::IsMatch($t, $rxStrict)) { $strict += $label; continue }
    if ([regex]::IsMatch($t, $rxInline)) { $inline += $label; continue }
    $notes += ('odd-shape=' + $label + '@' + $ln)
  }
  $allow = @{}
  foreach ($a in @($AllowedInline)) { $allow[[string]$a] = 1 }
  foreach ($nm in $inline) { if (-not $allow.ContainsKey([string]$nm)) { $notes += ('inline-not-allowed=' + [string]$nm) } }
  $inlineHas = @{}
  foreach ($nm in $inline) { $inlineHas[[string]$nm] = 1 }
  foreach ($a in @($AllowedInline)) { if (-not $inlineHas.ContainsKey([string]$a)) { $notes += ('allowed-not-inline=' + [string]$a) } }
  if (@($strict).Count -ne $ExpectedStrict) { $notes += ('strict-count=' + @($strict).Count + '-want=' + $ExpectedStrict) }
  if (@($clauses).Count -ne $ExpectedTotal) { $notes += ('total-count=' + @($clauses).Count + '-want=' + $ExpectedTotal) }
  return ($notes -join ',')
}
# v4.4.0 A-15 (G-17 ruling): the handler naming map and the case-shape judge for the named-stub conversion.
#    The name is the raw label behind one prefix - strip the prefix and you have the command name -
#    because a PascalCase map would add a case-folding step that nothing checks, and v6 sec 2.2 wrote the
#    re-key as 'fn:Invoke-Handler-x' in that same raw form. Measured on BOTH engines before writing:
#    ParameterAst exposes Attributes, DefaultValue, Extent, Name, Parent, StaticType - there is NO
#    TypeConstraint and NO Variable property (the trap is assuming one; it bit A-14q and S-92), so the
#    [ref] third parameter is recognised from the parameter's own extent text.
function Get-HandlerName([string]$Cmd) {
  return ('Invoke-Handler-' + [string]$Cmd)
}
# Four shapes are legal and every clause must be exactly one of them, so a case cannot be lost between
# two cards: inline (a single statement that is not a handler call, legal ONLY for the registered
# selftest / script / replay); plain (one handler call carrying this label as a literal, then $Rest);
# flag (three statements - the flag set to $false, the handler call passing ([ref]$flag), and
# `if ($flag) { return }` - the protocol for a body that must skip the dispatcher tail); and unwrapped
# (the original body, still legal while the card runs, counted against a registered number that every
# card lowers). A clause that is none of the four is named, never absorbed into the count.
function Get-HandlerParamName($Param) {
  # ParameterAst.Name keeps the sigil ('$Cmd'), so a comparison written against the bare name can never
  # match - measured here on both engines. One helper, used everywhere a parameter name is judged.
  $n = [string]$Param.Name
  if ($n.StartsWith('$')) { $n = $n.Substring(1) }
  return $n
}
function Get-StubCommandAst($Stmt) {
  if ($null -eq $Stmt) { return $null }
  if (([string]$Stmt.GetType().Name) -cne 'PipelineAst') { return $null }
  $els = @($Stmt.PipelineElements)
  if (@($els).Count -ne 1) { return $null }
  if (([string]$els[0].GetType().Name) -cne 'CommandAst') { return $null }
  return $els[0]
}
function Get-TopFunction([object]$Parsed, [string]$Name) {
  # top level only: a nested function of the same name is not the thing the dispatcher calls
  foreach ($f in @($Parsed.Root.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
    if (([string]$f.Name) -cne $Name) { continue }
    $p = $f.Parent; $nested = $false
    while ($null -ne $p) {
      if ($p -is [System.Management.Automation.Language.FunctionDefinitionAst]) { $nested = $true; break }
      $p = $p.Parent
    }
    if (-not $nested) { return $f }
  }
  return $null
}
function Get-FlagProtocolGap([object]$Parsed, [string]$HandlerName) {
  # the handler side of the protocol: three parameters with [ref] on the third, every return that
  # returns from THIS handler marked immediately before it, and the flag never reachable by output.
  $notes = @()
  $hd = Get-TopFunction $Parsed $HandlerName
  if ($null -eq $hd) { return ('handler-absent=' + $HandlerName) }
  $ps = @($hd.Parameters)
  if (@($ps).Count -ne 3) { return ('handler-params=' + $HandlerName + '=' + @($ps).Count) }
  if ((Get-HandlerParamName $ps[0]) -cne 'Cmd') { $notes += ('handler-p0=' + $HandlerName + '=' + [string]$ps[0].Name) }
  if ((Get-HandlerParamName $ps[1]) -cne 'Rest') { $notes += ('handler-p1=' + $HandlerName + '=' + [string]$ps[1].Name) }
  # the protocol's parameter name is a convention, not something each side may invent: the dispatcher
  # local and the handler parameter are DIFFERENT variables, and letting either name float is how the
  # first draft of this gate read the good fixture as broken.
  if ((Get-HandlerParamName $ps[2]) -cne 'SkipTail') { $notes += ('handler-p2=' + $HandlerName + '=' + [string]$ps[2].Name) }
  $FlagVar = 'SkipTail'
  $p2 = (([string]$ps[2].Extent.Text) -replace '\s+', '')
  if ($p2 -cne ('[ref]$' + $FlagVar)) { $notes += ('handler-not-ref=' + $HandlerName + '=' + $p2) }
  $mine = @()
  foreach ($r in @($hd.FindAll({ param($n) $n -is [System.Management.Automation.Language.ReturnStatementAst] }, $true))) {
    # a return belongs to this handler only when no nested scriptblock sits between it and the body -
    # this is the distinction that turned the design's seven sites into the four that really matter
    $p = $r.Parent; $nested = $false
    while ($null -ne $p -and ($p -ne $hd)) {
      $tn = [string]$p.GetType().Name
      if ($tn -ceq 'ScriptBlockExpressionAst') { $nested = $true; break }
      $p = $p.Parent
    }
    if (-not $nested) { $mine += [pscustomobject]@{ Node = $r; Line = [int]$r.Extent.StartLineNumber } }
  }
  foreach ($m in $mine) {
    $par = $m.Node.Parent
    if ($null -eq $par) { $notes += ('flag-return-unmarked=' + $HandlerName + '@' + [int]$m.Line); continue }
    $sibs = @($par.Statements)
    $sibN = @($sibs).Count
    $idx = -1
    for ($i = 0; $i -lt $sibN; $i++) { if ($sibs[$i] -eq $m.Node) { $idx = $i; break } }
    if ($idx -lt 1) { $notes += ('flag-return-unmarked=' + $HandlerName + '@' + [int]$m.Line); continue }
    $prev = (([string]$sibs[$idx - 1].Extent.Text) -replace '\s+', ' ')
    if ($prev -cne ('$' + $FlagVar + '.Value = $true')) { $notes += ('flag-return-unmarked=' + $HandlerName + '@' + [int]$m.Line) }
  }
  foreach ($v in @($hd.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true))) {
    if (([string]$v.VariablePath.UserPath) -cne $FlagVar) { continue }
    $mp = $v.Parent
    if ($null -eq $mp) { $notes += ('flag-escape=' + $HandlerName + '@' + [int]$v.Extent.StartLineNumber); continue }
    $mt = [string]$mp.GetType().Name
    if ($mt -ceq 'ParameterAst') { continue }                       # the declaration itself
    if ($mt -cne 'MemberExpressionAst') { $notes += ('flag-escape=' + $HandlerName + '@' + [int]$v.Extent.StartLineNumber); continue }
    if (([string]$mp.Member.Extent.Text) -cne 'Value') { $notes += ('flag-escape=' + $HandlerName + '@' + [int]$v.Extent.StartLineNumber); continue }
    $ap = $mp.Parent
    if (($null -eq $ap) -or (([string]$ap.GetType().Name) -cne 'AssignmentStatementAst') -or (-not ($ap.Left -eq $mp))) {
      $notes += ('flag-escape=' + $HandlerName + '@' + [int]$v.Extent.StartLineNumber)
    }
  }
  return ($notes -join ',')
}
function Get-HandlerGroupGap([object]$Parsed, [hashtable]$Groups, [hashtable]$Files, $Spans) {
  # A-16 (v7 note to v6 3.1/3.3): the handler groups and the file each one lives in are DECLARED, and this
  #    says what does not match. Which file a definition came from is answered through the span map the
  #    product already builds for line references - extents do not carry file names, and the aggregate is
  #    parsed as ONE source, so anything else is a guess. A group with no file declared is expected in the
  #    entry; once a file is named, every one of its handlers must be defined exactly once and IN that
  #    file: none left in the entry, none missing, none duplicated, none living in a group nobody declared.
  if ($null -eq $Parsed) { return 'no-parse' }
  $root = $Parsed.Root
  if ($null -eq $root) { return 'no-parse' }
  $notes = @()
  $count = @{}
  $where = @{}
  foreach ($fd in @($root.FindAll({ param($n) ($n -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($n.Name -clike 'Invoke-Handler-*') }, $true))) {
    $ln = [int]$fd.Extent.StartLineNumber
    $file = 'unknown'
    foreach ($sp in @($Spans)) {
      if (($ln -ge [int]$sp.Start) -and ($ln -lt ([int]$sp.Start + [int]$sp.Count))) { $file = [string]$sp.File; break }
    }
    $nm = [string]$fd.Name
    if ($count.ContainsKey($nm)) { $count[$nm] = $count[$nm] + 1 } else { $count[$nm] = 1 }
    if (-not $where.ContainsKey($nm)) { $where[$nm] = @($file) } else { $where[$nm] += $file }
  }
  $known = @()
  $total = 0
  foreach ($g in @(Get-HashKeys $Groups)) {
    $grp = @($Groups[$g])
    $total = $total + $grp.Count
    $want = [string]$Files[$g]
    if ($want -eq '') { $want = 'desktop.ps1' }
    foreach ($n in $grp) { $known += ('Invoke-Handler-' + $n) }
    foreach ($n in $grp) {
      $h = 'Invoke-Handler-' + [string]$n
      $c = 0
      if ($count.ContainsKey($h)) { $c = [int]$count[$h] }
      if ($c -ne 1) { $notes += ($h + '=defines' + $c); continue }
      $at = (@($where[$h]) | Sort-Object -Unique) -join ','
      if ($at -cne $want) { $notes += ($h + '=in:' + $at + '-want:' + $want) }
    }
  }
  foreach ($f2 in @(Get-HashKeys $Files)) { if (-not $Groups.ContainsKey($f2)) { $notes += ('file-without-group=' + $f2) } }
  foreach ($h2 in @(Get-HashKeys $count)) { if ($h2 -notin $known) { $notes += ('ungrouped-handler=' + $h2) } }
  if ($total -ne 91) { $notes += ('names-total=' + $total + '-want91') }
  return ($notes -join ';')
}

function Get-HandlerStubGap([object]$Parsed, [string[]]$AllowedInline, [string[]]$FlagCases, [int]$ExpectedUnwrapped) {
  if ($null -eq $Parsed) { return '-no-parse' }
  if ($null -eq $Parsed.Root) { return '-no-parse' }
  $fnName = 'Invoke-DesktopCommand'
  $fn = Get-TopFunction $Parsed $fnName
  if ($null -eq $fn) { return ('-absent-body:' + $fnName) }
  $sws = @($fn.Body.FindAll({ param($n) $n -is [System.Management.Automation.Language.SwitchStatementAst] }, $true))
  if (@($sws).Count -ne 1) { return ('switch-count=' + @($sws).Count) }
  $notes = @()
  $allowMap = @{}
  foreach ($a in @($AllowedInline)) { $allowMap[[string]$a] = 1 }
  $flagMap = @{}
  foreach ($f in @($FlagCases)) { $flagMap[[string]$f] = 1 }
  $seenFlag = @{}
  $called = @{}
  $unwrapped = 0
  foreach ($c in @($sws[0].Clauses)) {
    if (-not ($c.Item1 -is [System.Management.Automation.Language.StringConstantExpressionAst])) { continue }
    $label = [string]$c.Item1.Value
    $want = Get-HandlerName $label
    $stmts = @($c.Item2.Statements)
    if (@($stmts).Count -eq 1) {
      $ca = Get-StubCommandAst $stmts[0]
      if ($null -eq $ca) { $unwrapped = $unwrapped + 1; continue }
      $els = @($ca.CommandElements)
      $ename = ''
      if ((@($els).Count -gt 0) -and ($els[0] -is [System.Management.Automation.Language.StringConstantExpressionAst])) { $ename = [string]$els[0].Value }
      if ($ename.StartsWith('Invoke-Handler-')) {
        if ($ename -cne $want) { $notes += ('stub-name=' + $label + '=' + $ename); continue }
        if (-not $called.ContainsKey($want)) { $called[$want] = 0 }
        $called[$want] = [int]$called[$want] + 1
        if (@($els).Count -ne 3) { $notes += ('stub-args=' + $label + '=' + @($els).Count); continue }
        if (-not ($els[1] -is [System.Management.Automation.Language.StringConstantExpressionAst])) { $notes += ('stub-cmdname=' + $label + '=not-literal'); continue }
        if (([string]$els[1].Value) -cne $label) { $notes += ('stub-cmdname=' + $label + '=' + [string]$els[1].Value) }
        if (-not ($els[2] -is [System.Management.Automation.Language.VariableExpressionAst])) { $notes += ('stub-rest=' + $label + '=not-var'); continue }
        if (([string]$els[2].VariablePath.UserPath) -cne 'Rest') { $notes += ('stub-rest=' + $label + '=' + [string]$els[2].VariablePath.UserPath) }
        $hh = Get-TopFunction $Parsed $want
        if ($null -eq $hh) { $notes += ('handler-absent=' + $want) } else {
          $hp = @($hh.Parameters)
          if (@($hp).Count -ne 2) { $notes += ('handler-params=' + $want + '=' + @($hp).Count) }
          if ((@($hp).Count -eq 2) -and ((Get-HandlerParamName $hp[0]) -cne 'Cmd')) { $notes += ('handler-p0=' + $want + '=' + [string]$hp[0].Name) }
          if ((@($hp).Count -eq 2) -and ((Get-HandlerParamName $hp[1]) -cne 'Rest')) { $notes += ('handler-p1=' + $want + '=' + [string]$hp[1].Name) }
        }
        continue
      }
      if ($allowMap.ContainsKey($label)) { continue }
      $notes += ('inline-not-allowed=' + $label)
      continue
    }
    if (@($stmts).Count -eq 3) {
      $flagVar = ''
      $ok = (([string]$stmts[0].GetType().Name) -ceq 'AssignmentStatementAst')
      if ($ok) {
        $l0 = $stmts[0].Left
        if ($l0 -is [System.Management.Automation.Language.VariableExpressionAst]) { $flagVar = [string]$l0.VariablePath.UserPath } else { $ok = $false }
        if ($ok -and ((([string]$stmts[0].Right.Extent.Text) -replace '\s+', '') -cne '$false')) { $ok = $false }
      }
      $ca1 = $null
      if ($ok) { $ca1 = Get-StubCommandAst $stmts[1] }
      if ($null -eq $ca1) { $ok = $false }
      $els1 = @()
      if ($ok) { $els1 = @($ca1.CommandElements) }
      if ($ok -and (((@($els1).Count -ne 4) -or (([string]$els1[0].Value) -cne $want)))) { $ok = $false }
      if ($ok) {
        $paren = (([string]$els1[3].Extent.Text) -replace '\s+', '')
        if ($paren -cne ('([ref]$' + $flagVar + ')')) { $ok = $false }
        if (([string]$els1[1].Value) -cne $label) { $notes += ('stub-cmdname=' + $label + '=' + [string]$els1[1].Value) }
        if (([string]$els1[2].VariablePath.UserPath) -cne 'Rest') { $notes += ('stub-rest=' + $label + '=' + [string]$els1[2].VariablePath.UserPath) }
      }
      if ($ok -and (([string]$stmts[2].GetType().Name) -cne 'IfStatementAst')) { $ok = $false }
      if ($ok) {
        $cls = @($stmts[2].Clauses)
        if ((@($cls).Count -ne 1) -or ((([string]$cls[0].Item1.Extent.Text) -replace '\s+', '') -cne ('$' + $flagVar))) { $ok = $false }
        if ($ok) {
          $bs = @($cls[0].Item2.Statements)
          if ((@($bs).Count -ne 1) -or (([string]$bs[0].GetType().Name) -cne 'ReturnStatementAst')) { $ok = $false }
        }
      }
      if ($ok) {
        if (-not $called.ContainsKey($want)) { $called[$want] = 0 }
        $called[$want] = [int]$called[$want] + 1
        if (-not $flagMap.ContainsKey($label)) { $notes += ('flag-not-registered=' + $label); continue }
        $seenFlag[$label] = 1
        $fg = Get-FlagProtocolGap $Parsed $want
        if ($fg -cne '') { $notes += $fg }
        continue
      }
    }
    $unwrapped = $unwrapped + 1
  }
  foreach ($f in @($FlagCases)) { if (-not $seenFlag.ContainsKey([string]$f)) { $notes += ('flag-registered-missing=' + [string]$f) } }
  foreach ($f in @($Parsed.Root.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
    $nm = [string]$f.Name
    if (-not $nm.StartsWith('Invoke-Handler-')) { continue }
    $p = $f.Parent; $nested = $false
    while ($null -ne $p) { if ($p -is [System.Management.Automation.Language.FunctionDefinitionAst]) { $nested = $true; break }; $p = $p.Parent }
    if ($nested) { continue }
    if (-not $called.ContainsKey($nm)) { $notes += ('handler-orphan=' + $nm); continue }
    if ([int]$called[$nm] -gt 1) { $notes += ('handler-double=' + $nm + '=' + [int]$called[$nm]) }
  }
  if ($unwrapped -ne $ExpectedUnwrapped) { $notes += ('unwrapped=' + $unwrapped + '-want=' + $ExpectedUnwrapped) }
  return ($notes -join ',')
}
# v4.4.0 A-15: where a command's CODE lives, now that a case body may be a stub pointing at a handler.
#    Gates that promise something about a command (it builds its endpoint through the loopback gate,
#    it echoes the hit window before the click, its wiring really calls the guard it claims) used to
#    find that code by scanning the dispatcher case body, so a pure move made each of them report the
#    promise as missing - three of them did, on the first four wraps. They ask this helper instead:
#    the case range, plus the handler range when the case is a stub for it. Ranges are 0-based and
#    inclusive, matching the scans that consume them; the quote characters are built from code points
#    so no line of this body starts with the case shape it is looking for.
function Get-CommandCodeRanges([string[]]$Lines, [string]$Cmd) {
  $ls = @($Lines)
  $out = @()
  if (@($ls).Count -eq 0) { return $out }
  $q = [string][char]39
  $pre = '    ' + $q + $Cmd + $q + ' {'
  $open = -1
  for ($i = 0; $i -lt $ls.Count; $i++) { if (([string]$ls[$i]) -ceq $pre) { $open = $i; break } }
  if ($open -lt 0) { return $out }
  $close = $open
  for ($i = $open + 1; $i -lt $ls.Count; $i++) { if (([string]$ls[$i]) -ceq '    }') { $close = $i; break } }
  $out += ,@($open, $close)
  $stub = '      Invoke-Handler-' + $Cmd + ' '
  $isStub = $false
  for ($i = $open + 1; $i -lt $close; $i++) { if (([string]$ls[$i]).StartsWith($stub)) { $isStub = $true } }
  if (-not $isStub) { return $out }
  $head = 'function Invoke-Handler-' + $Cmd + '('
  $hs = -1
  for ($i = 0; $i -lt $ls.Count; $i++) { if (([string]$ls[$i]).StartsWith($head)) { $hs = $i; break } }
  if ($hs -lt 0) { return $out }
  $he = $hs
  for ($i = $hs + 1; $i -lt $ls.Count; $i++) { if (([string]$ls[$i]) -ceq '}') { $he = $i; break } }
  $out += ,@($hs, $he)
  return $out
}
function Get-CommandCodeText([string[]]$Lines, [string]$Cmd) {
  $ls = @($Lines)
  $parts = @()
  foreach ($rg in @(Get-CommandCodeRanges $Lines $Cmd)) { $parts += (@($ls[[int]$rg[0]..[int]$rg[1]]) -join "`n") }
  return ($parts -join "`n")
}
# v4.4.0 A-06: whichever mode the split picked, the run has to SAY it - a reading taken from a
#    single stitched file is not a reading of the source tree, and a caller comparing 881
#    numbers across the two would otherwise have nothing to tell them apart. Kept as a pure
#    predicate so the agreement can be planted-tested in both directions.
function Get-SourceModeLine([string]$Mode, [int]$Files) {
  if ($Mode -ceq 'aggregate') { return ('selftest: aggregate source mode, ' + $Files + ' file(s) measured as one source') }
  return 'selftest: single-file source mode (no lib/ beside the entry)'
}

function Test-ModeLineAgreement([string]$Mode, [string]$Line) {
  $l = [string]$Line
  if ($Mode -ceq 'aggregate') { return $l.StartsWith('selftest: aggregate source mode') }
  if ($Mode -ceq 'single-file') { return $l.StartsWith('selftest: single-file source mode') }
  return $false
}
$script:StSourceSpans = @()
$script:StSourceMode = Get-SourceModeBeside $PSScriptRoot
# !! Double-quoted with every dollar escaped: these statements contain both a dollar and
#    single quotes, and a single-quoted literal cannot carry the value's own quotes.
$script:StLoadTimeInits = @(
  "`$script:CdpPort = 9222",
  "`$script:PressSeq = 0",
  "`$script:PressId = ''",
  "`$script:PressTopLevel = `$true",
  "`$script:UiaActionAllowRe = '^(Button|MenuItem|Edit|CheckBox|RadioButton|ComboBox|ListItem|TabItem|TreeItem|Hyperlink|Slider|SplitButton)`$'",
  "`$script:JsonSchemaVersion = 3",
  "`$script:NoAutoTrim = `$false",
  "`$script:ActivationLine = ''",
  "`$script:ActivationNotice = ''",
  "`$script:ResolveNote = ''",
  "`$script:StHandlerInlineCases = @('selftest', 'script', 'replay')",
  "`$script:StHandlerFlagCases = @('chrome-click', 'uia-click', 'uia-focus', 'uia-settext')",
  "`$script:StHandlerUnwrapped = 0",
  "`$script:OcrCapNoteShown = `$false"
)

# ---------- v4.4.0 (A-07): the AST-authoritative inventory ----------
# Four families that this split keeps editing are pinned by STRUCTURE instead of by line number:
# who calls the audited command, which textual mentions of it are not calls, which functions get
# swapped out through the function table, and what runs at load time. A pure move shifts every
# line below the moved block, so a reading keyed on line numbers would look lossy when it is not.
# The keys below come from the AST; line numbers travel with a failure only to help diagnose it.
# This is the table A-08..A-19 have to agree with: moving a case body into a handler re-keys
# 'case:x' to 'fn:Invoke-Handler-x' and that edit belongs in the same commit as the move, or the
# gate names the key. A handler that silently loses its audit call cannot pass.
# Counting is case-sensitive throughout (v6 1.7): the dispatcher's loop variable differs from the
# audited command's name by case alone, so an insensitive count would absorb the first into the
# second and report the same tidy total for both shapes.
function Get-CharCodeWord([int[]]$Codes) {
  # Assembled from code points. A literal of the scanned word anywhere in this file would itself
  # be a mention of it - and the mention table below has to account for every one (P-05, P-06,
  # X-01 and the A-04 scan tokens are this file's named precedents for that trap).
  $w = ''
  foreach ($c in @($Codes)) { $w = $w + [string][char]$c }
  return $w
}

function Parse-SourceForInventory([string]$Text) {
  # One parse, several readers: the four extractors below all take this object, so the whole
  # source is never walked more than a few times per run.
  $toks = $null
  $errs = $null
  $root = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$toks, [ref]$errs)
  return [pscustomobject]@{ Root = $root; ErrorCount = @($errs).Count }
}

function Get-AstFunctionName($Node) {
  $p = $Node
  while ($null -ne $p) {
    if ($p -is [System.Management.Automation.Language.FunctionDefinitionAst]) { return [string]$p.Name }
    $p = $p.Parent
  }
  return ''
}

function Get-CommandSiteList($Parsed, [string]$CommandName) {
  # A-07 contract, now derived from the one walk: "owner@line" pairs, ";" joined, duplicates kept
  # (a count of references is a count, not a set). Owner is the enclosing switch clause when there
  # is one - that is what separates the calls made from the dispatcher from the ones made inside a
  # helper, which is the split A-08 depends on.
  $out = @()
  foreach ($rec in @((Get-CommandSiteRecords $Parsed $CommandName) -split "`n")) {
    if ($rec -eq '') { continue }
    $f = @([string]$rec -split "`t", 4)
    $out += ([string]$f[0] + '@' + [string]$f[1])
  }
  return ($out -join ';')
}

function Get-FunctionScopeNameList($Parsed) {
  # 5.1 leaves Name and UserPath EMPTY for the braced ${function:x} form, so the name is read off
  # the extent text. This family is the test-double seam: a stub swapped in here has to keep the
  # shape the production call uses, or the fixture breaks while the product still runs.
  if ($null -eq $Parsed) { return '' }
  $root = $Parsed.Root
  if ($null -eq $root) { return '' }
  $out = @()
  $vars = @($root.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true))
  foreach ($v in $vars) {
    $t = [string]$v.Extent.Text
    if ($t -match '^\$\{function:([^}]+)\}$') { $out += [string]$Matches[1] }
  }
  return ($out -join ';')
}

function Get-TopLevelAssignmentNameList($Parsed) {
  # Every assignment with no function definition above it: it runs while the script is being
  # dot-read, so it is state the split inherits (or loses). Sections 3 and 5 of the design doc
  # assume a section is pure functions; the count here is the standing counter-example.
  if ($null -eq $Parsed) { return '' }
  $root = $Parsed.Root
  if ($null -eq $root) { return '' }
  $out = @()
  $as = @($root.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true))
  foreach ($a in $as) {
    if ((Get-AstFunctionName $a) -ne '') { continue }
    $t = ''
    if ($null -ne $a.Left) { $t = [string]$a.Left.Extent.Text }
    if ($t -match '^\$\{?([^}]+)\}?$') { $out += [string]$Matches[1] } else { $out += ('OTHER:' + $t) }
  }
  return ($out -join ';')
}

function Get-LoadTimeInitNameList([string[]]$Statements) {
  # The move-marked statements are already pinned verbatim by A-03; this maps them to the same
  # key form the AST inventory uses, so 'marked for a move' and 'present at load time' are
  # compared on one shape instead of two that can each be right for the wrong reason.
  $out = @()
  foreach ($s in @($Statements)) {
    $t = [string]$s
    if ($t -match '^\$\{?([^}\s=]+)') { $out += [string]$Matches[1] } else { $out += ('BAD:' + $t) }
  }
  return ($out -join ';')
}

function Get-InventoryDiscrepancy([string]$ObservedList, [string[]]$Declared) {
  # Observed: ';' joined keys with duplicates. Declared: 'key=count'. ';' cannot appear inside a
  # key, which is why the tables below are safe to write as plain arrays.
  $obs = @()
  $o = [string]$ObservedList
  if ($o -ne '') { $obs = @($o -split ';') }
  $notes = @()
  $names = @()
  foreach ($d in @($Declared)) {
    $ds = [string]$d
    $eq = $ds.LastIndexOf('=')
    if ($eq -lt 1) { $notes += ('bad-entry:' + $ds); continue }
    $nm = $ds.Substring(0, $eq)
    $want = -1
    if (-not [int]::TryParse($ds.Substring($eq + 1), [ref]$want)) { $notes += ('bad-count:' + $ds); continue }
    $names += $nm
    $got = 0
    foreach ($k in $obs) { if ([string]$k -ceq $nm) { $got = $got + 1 } }
    if ($got -ne $want) { $notes += ($nm + ':got' + $got + '-want' + $want) }
  }
  foreach ($k in $obs) {
    $hit = 0
    foreach ($nm in $names) { if ([string]$k -ceq [string]$nm) { $hit = $hit + 1 } }
    if ($hit -ne 1) { $notes += ('observed:' + [string]$k + '-declared=' + $hit) }
  }
  $dups = 0
  foreach ($n1 in $names) {
    $c = 0
    foreach ($n2 in $names) { if ([string]$n1 -ceq [string]$n2) { $c = $c + 1 } }
    if ($c -gt 1) { $dups = $dups + 1 }
  }
  if ($dups -gt 0) { $notes += ('duplicate-declared=' + $dups) }
  return ($notes -join ';')
}

function Get-MentionExclusionDiscrepancy([string[]]$Lines, [string]$Token, [string]$CallLines, [string[]]$Anchors) {
  # A line that mentions the command but is not one of its AST call sites is only allowed to be
  # there if it matches exactly one registered exclusion - and that anchor may be used by exactly
  # one such line. Both directions are checked, because an anchor that went stale would otherwise
  # keep certifying whatever line replaced it. Anchors are token-free strings by construction: a
  # registration carrying the token would add a mention it then had to excuse.
  $calls = @{}
  $cl = [string]$CallLines
  if ($cl -ne '') { foreach ($x in @($cl -split ';')) { $calls[[int]$x] = $true } }
  $arr = @($Lines)
  $notes = @()
  $hits = @{}
  for ($i = 0; $i -lt $arr.Count; $i++) {
    $t = [string]$arr[$i]
    if (-not $t.Contains($Token)) { continue }
    if ($calls.ContainsKey($i + 1)) { continue }
    $m = 0
    foreach ($a in @($Anchors)) {
      if ($t.Contains([string]$a)) {
        $m = $m + 1
        $k = [string]$a
        if ($hits.ContainsKey($k)) { $hits[$k] = [int]$hits[$k] + 1 } else { $hits[$k] = 1 }
      }
    }
    if ($m -ne 1) { $notes += ('line' + [string]($i + 1) + '-anchor-hits=' + $m) }
  }
  foreach ($a in @($Anchors)) {
    $k = [string]$a
    $h = 0
    if ($hits.ContainsKey($k)) { $h = [int]$hits[$k] }
    if ($h -ne 1) { $notes += ('anchor-hits=' + $h + ':' + $k) }
  }
  return ($notes -join ';')
}

# !! A-08: the label map became a leaf of its own because two readers now need it. Two copies of
#    the clause-attribution rule is how a gate ends up measuring a shape the other gate does not.
function Get-SwitchLabelMap($Parsed) {
  # Clause-body start offset -> label(s). The default branch is registered too, and it is NOT a
  # clause in this AST (it hangs off SwitchStatementAst.Default), so forgetting it would attribute
  # a default-branch call to the enclosing function and read as if a handler made it.
  $labels = @{}
  if ($null -eq $Parsed) { return $labels }
  $root = $Parsed.Root
  if ($null -eq $root) { return $labels }
  foreach ($sw in @($root.FindAll({ param($n) $n -is [System.Management.Automation.Language.SwitchStatementAst] }, $true))) {
    foreach ($cl in @($sw.Clauses)) {
      # Clauses surface as Tuple[ExpressionAst,StatementBlockAst]; Item1 is the case label.
      $blk = $cl.Item2
      if ($null -eq $blk) { continue }
      $parts = @()
      $item = $cl.Item1
      if ($null -ne $item) {
        $cs = @($item.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true))
        foreach ($c in $cs) { $parts += [string]$c.Value }
      }
      if (@($parts).Count -lt 1) { $parts = @('NONLITERAL') }
      $labels[[int64]$blk.Extent.StartOffset] = ($parts -join '|')
    }
    if ($null -ne $sw.Default) { $labels[[int64]$sw.Default.Extent.StartOffset] = 'DEFAULT' }
  }
  return $labels
}

function Get-CommandSiteRecords($Parsed, [string]$CommandName) {
  # One walk, four fields per site: 'owner<TAB>line<TAB>argCount<TAB>lastArgument', records joined
  # by newline. The tab keeps a multi-label owner (which contains a pipe) in one piece, and the
  # split is capped at four so an argument that itself contains a tab cannot forge a field.
  $out = @()
  if ($null -eq $Parsed) { return '' }
  $root = $Parsed.Root
  if ($null -eq $root) { return '' }
  $labels = Get-SwitchLabelMap $Parsed
  $cmds = @($root.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true))
  foreach ($cm in $cmds) {
    if (([string]$cm.GetCommandName()) -cne $CommandName) { continue }
    $owner = ''
    $p = $cm
    while ($null -ne $p) {
      $k = [int64]$p.Extent.StartOffset
      if ($labels.ContainsKey($k)) { $owner = 'case:' + [string]$labels[$k]; break }
      if ($p -is [System.Management.Automation.Language.FunctionDefinitionAst]) { break }
      $p = $p.Parent
    }
    if ($owner -eq '') {
      $fn = Get-AstFunctionName $cm
      if ($fn -eq '') { $owner = 'entry-top-level' } else { $owner = 'fn:' + $fn }
    }
    $els = @($cm.CommandElements)
    $n = $els.Count - 1
    $last = 'ABSENT'
    if ($n -ge 1) { $last = [string]$els[$els.Count - 1].Extent.Text }
    $out += ($owner + "`t" + [string]([int]$cm.Extent.StartLineNumber) + "`t" + [string]$n + "`t" + $last)
  }
  return ($out -join "`n")
}

function Get-FunctionParamNameList($Parsed, [string]$FunctionName) {
  if ($null -eq $Parsed) { return '' }
  $root = $Parsed.Root
  if ($null -eq $root) { return '' }
  $out = @()
  foreach ($fd in @($root.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
    if (([string]$fd.Name) -cne $FunctionName) { continue }
    foreach ($p in @($fd.Parameters)) { $out += [string]$p.Name.VariablePath.UserPath }
  }
  return ($out -join ';')
}

function Get-StubParamNameList($Parsed, [string]$FunctionName) {
  # The test double is an assignment to the function-table variable; the needle is assembled here
  # from the name being looked for, so this line never spells the command it is about.
  if ($null -eq $Parsed) { return '' }
  $root = $Parsed.Root
  if ($null -eq $root) { return '' }
  $needle = '$' + '{function:' + [string]$FunctionName + '}'
  $out = @()
  foreach ($a in @($root.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true))) {
    if ($null -eq $a.Left) { continue }
    if (([string]$a.Left.Extent.Text) -cne $needle) { continue }
    if ($null -eq $a.Right) { continue }
    $a08sRight = $a.Right
    # The double is `${function:<name>} = { param(...) ... }`: the assignment's Right is a command
    # expression wrapping the script block, and an anonymous script block keeps its formals under
    # ParamBlock - a ScriptBlockAst has no Parameters property, so reading that gives $null and the
    # lint would pass by measuring nothing at all.
    if ($a08sRight -is [System.Management.Automation.Language.CommandExpressionAst]) { $a08sRight = $a08sRight.Expression }
    if (-not ($a08sRight -is [System.Management.Automation.Language.ScriptBlockExpressionAst])) { continue }
    if ($null -eq $a08sRight.ScriptBlock) { continue }
    $a08sPb = $a08sRight.ScriptBlock.ParamBlock
    if ($null -eq $a08sPb) { continue }
    foreach ($p in @($a08sPb.Parameters)) { $out += [string]$p.Name.VariablePath.UserPath }
  }
  return ($out -join ';')
}

function Get-StubAlignmentDiscrepancy($Parsed, [string]$FunctionName) {
  # A stub with fewer formals than the production function binds fine until a caller passes the
  # extra argument, and then the fixture that swaps it is the thing that crashes - which is the
  # opposite of what a fixture is for. Counted, not compared by name: the double is free to call
  # its parameters whatever it likes as long as the arity matches.
  $real = @()
  foreach ($x in @((Get-FunctionParamNameList $Parsed $FunctionName) -split ';')) { if ($x -ne '') { $real += $x } }
  $stub = @()
  foreach ($x in @((Get-StubParamNameList $Parsed $FunctionName) -split ';')) { if ($x -ne '') { $stub += $x } }
  if (@($real).Count -lt 1) { return ('no-function:' + [string]$FunctionName) }
  if (@($stub).Count -lt 1) { return ('no-stub:' + [string]$FunctionName) }
  if (@($stub).Count -ne @($real).Count) { return ($FunctionName + ':stub=' + @($stub).Count + '-real=' + @($real).Count) }
  return ''
}
function Get-VarUseOwnerList($Parsed, [string]$VarText) {
  # Owner key per USE of one exact variable spelling: 'fn:<name>' inside a function, '<script>' at the
  # top level, duplicates kept (the count is what is accounted for, not the set). A parameter
  # declaration is not a use - the node under a ParameterAst is where the name is being introduced,
  # and counting it would let a function buy compliance by declaring the variable it never reads.
  if ($null -eq $Parsed) { return '' }
  $root = $Parsed.Root
  if ($null -eq $root) { return '' }
  $out = @()
  foreach ($v in @($root.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true))) {
    if (([string]$v.Extent.Text) -cne $VarText) { continue }
    $par = $v.Parent
    if ($null -ne $par) {
      $pn = [string]$par.GetType().Name
      if ($pn.EndsWith('ParameterAst')) { continue }
    }
    $fn = Get-AstFunctionName $v
    if ($fn -eq '') { $out += '<script>' } else { $out += ('fn:' + $fn) }
  }
  return ($out -join ';')
}

function Get-EntryParamNameString($Parsed) {
  # The entry parameter block is what makes a top-level use legal. Read from the AST, so the
  # exemption cannot be granted by a comment or by a variable that is assigned instead of declared.
  if ($null -eq $Parsed) { return '' }
  $root = $Parsed.Root
  if ($null -eq $root) { return '' }
  if ($null -eq $root.ParamBlock) { return '' }
  $out = @()
  foreach ($p in @($root.ParamBlock.Parameters)) { $out += [string]$p.Name.VariablePath.UserPath }
  return ($out -join ';')
}

function Get-FunctionDeclaresParameter($Parsed, [string]$FunctionName, [string]$ParamName) {
  # Three verdicts, never a boolean: 'absent' (no such function - a typo must not read as
  # non-compliance) and 'no-parse' are distinguishable from 'no', which is the actual violation.
  if ($null -eq $Parsed) { return 'no-parse' }
  $root = $Parsed.Root
  if ($null -eq $root) { return 'no-parse' }
  $found = $false
  foreach ($fd in @($root.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
    if (([string]$fd.Name) -cne $FunctionName) { continue }
    $found = $true
    foreach ($p in @($fd.Parameters)) {
      if (([string]$p.Name.VariablePath.UserPath) -ceq $ParamName) { return 'yes' }
    }
  }
  if (-not $found) { return 'absent' }
  return 'no'
}

function Get-UndeclaredVarUseDiscrepancy($Parsed, [string]$VarText, [bool]$EntryDeclares) {
  # A use of a variable the reader does not declare is a read of somebody else's scope. Today it
  # resolves by luck of the call chain; after the split the chain is shorter and the value is simply
  # not there, which for the audit column means an empty field rather than an error.
  $owners = @()
  foreach ($o in @((Get-VarUseOwnerList $Parsed $VarText) -split ';')) { if ($o -ne '') { $owners += [string]$o } }
  $notes = @()
  $param = $VarText
  if ($param.StartsWith('$')) { $param = $param.Substring(1) }
  $seen = @()
  foreach ($o in $owners) {
    $dup = $false
    foreach ($s in $seen) { if ([string]$s -ceq $o) { $dup = $true } }
    if ($dup) { continue }
    $seen += $o
    $c = 0
    foreach ($x in $owners) { if ([string]$x -ceq $o) { $c = $c + 1 } }
    if ($o -ceq '<script>') {
      if (-not $EntryDeclares) { $notes += ('script-uses' + $c + '-without-entry-param') }
      continue
    }
    $fn = $o
    if ($fn.StartsWith('fn:')) { $fn = $fn.Substring(3) }
    $d = Get-FunctionDeclaresParameter $Parsed $fn $param
    if ($d -ceq 'no') { $notes += ($o + '=uses' + $c + '-undeclared') }
    if ($d -ceq 'absent') { $notes += ($o + '=function-absent') }
    if ($d -ceq 'no-parse') { $notes += ($o + '=no-parse') }
  }
  return ($notes -join ';')
}

function Get-VarUseCountInFunction($Parsed, [string]$FunctionName, [string]$VarText) {
  # Returned as a STRING, and negative for the two ways this can fail to measure anything: a caller
  # that compared an int would read '-1' as 1 and '-absent' as a number.
  if ($null -eq $Parsed) { return '-no-parse' }
  $root = $Parsed.Root
  if ($null -eq $root) { return '-no-parse' }
  $target = $null
  foreach ($fd in @($root.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
    if (([string]$fd.Name) -cne $FunctionName) { continue }
    $target = $fd
    break
  }
  if ($null -eq $target) { return '-absent' }
  $c = 0
  foreach ($v in @($target.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true))) {
    if (([string]$v.Extent.Text) -cne $VarText) { continue }
    $par = $v.Parent
    if ($null -ne $par) {
      $pn = [string]$par.GetType().Name
      if ($pn.EndsWith('ParameterAst')) { continue }
    }
    $c = $c + 1
  }
  return ([string]$c)
}

function Get-FamilyFunctionName([string]$Key) {
  # 'split-machine' -> 'Invoke-SelftestFamily-SplitMachine', and the file is 'lib/selftest-<key>.ps1'.
  # One mapping shared by the loader reconciliation and the banner scan: if the function name were
  # spelled per card, a card could register a file that nothing resolves to and stay green.
  $out = 'Invoke-SelftestFamily-'
  foreach ($part in @($Key -split '-')) {
    if ($part -eq '') { continue }
    $out += ([string]$part).Substring(0, 1).ToUpperInvariant() + ([string]$part).Substring(1).ToLowerInvariant()
  }
  return $out
}

function Get-CtxPublishedKeys($Parsed, [string[]]$Lines) {
  # The keys the orchestrator hands down, read out of its own body: the left-hand side of
  # $Ctx['<key>' ] assignments inside Invoke-SelfTest. Measured from the publish side instead of
  # copied into a table, so a family cannot gain an input by editing a list.
  if ($null -eq $Parsed) { return '-no-parse' }
  if ($null -eq $Parsed.Root) { return '-no-parse' }
  $ls = @($Lines)
  $out = @()
  foreach ($cand in @($Parsed.Root.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
    if (([string]$cand.Name) -cne 'Invoke-SelfTest') { continue }
    # Assembled from code points, not written out: "`$" in a PowerShell string yields a bare $, which
    # the regex engine then reads as an end-of-line anchor - the pattern would match nothing and the
    # gate would report a clean section. Backslash-dollar is the literal, and [char] keeps it visible.
    $d = [string][char]0x24
    $q = [string][char]39
    $pat = '^\s*\' + $d + 'Ctx\[' + $q + '([^' + $q + ']+)' + $q + '\]\s*='
    $f = [int]$cand.Extent.StartLineNumber
    $t = [int]$cand.Extent.EndLineNumber
    for ($i = $f; $i -le [Math]::Min($t, $ls.Count); $i++) {
      $m = [regex]::Match([string]$ls[$i - 1], $pat)
      if (-not $m.Success) { continue }
      $out += [string]$m.Groups[1].Value
    }
    break
  }
  if (@($out).Count -eq 0) { return '-none' }
  return ($out -join ',')
}

  # v4.4.0 (S-92): one shared way to name the context keys an AST node touches. The key has to be a
  # constant string in either quote style (IndexExpressionAst exposes Target/Index - measured on both engines,";
  #   it has no Expression), and a double-quoted key that interpolates ($) is skipped because
  # its value is not knowable statically, and pretending otherwise would invent a name to report.
  function Get-CtxIndexKey($Node) {
    if ($null -eq $Node) { return '' }
    if (-not ($Node -is [System.Management.Automation.Language.IndexExpressionAst])) { return '' }
    $tgt = $Node.Target
    if (-not ($tgt -is [System.Management.Automation.Language.VariableExpressionAst])) { return '' }
    if (([string]$tgt.VariablePath.UserPath) -cne 'Ctx') { return '' }
    $vk = [string]$Node.Index.Extent.Text
    if ($vk.Length -lt 3) { return '' }
    $fc = $vk.Substring(0, 1)
    $lc = $vk.Substring($vk.Length - 1, 1)
    if ((-not (($fc -ceq "'") -and ($lc -ceq "'"))) -and (-not (($fc -ceq '"') -and ($lc -ceq '"')))) { return '' }
    $k = $vk.Substring(1, $vk.Length - 2)
    if (($fc -ceq '"') -and ($k.Contains('$'))) { return '' }
    if ($k -eq '') { return '' }
    return $k
  }
function Get-FamilyCtxGap($Parsed, [string[]]$Lines, [string]$FunctionName, [string]$AllowedKeys) {
  # One lifted family's state contract, measured: every context key it touches - read or written -
  # must be on the allowed surface (the keys the orchestrator publishes, plus this family's own
  # declared hand-backs since A-14l), and no plain variable may still be reaching into the caller's
  # scope. '' means clean; the two sentinels mean the measurement could not run, which is never the
  # same answer as 'nothing wrong'.
  if ($null -eq $Parsed) { return '-no-parse' }
  if ($null -eq $Parsed.Root) { return '-no-parse' }
  $fd = $null
  foreach ($cand in @($Parsed.Root.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
    if (([string]$cand.Name) -cne [string]$FunctionName) { continue }
    $fd = $cand
    break
  }
  if ($null -eq $fd) { return '-absent' }
  $ls = @($Lines)
  $f = [int]$fd.Extent.StartLineNumber
  $t = [int]$fd.Extent.EndLineNumber
  $last = [Math]::Min($t, $ls.Count)
  $pub = @{}
  foreach ($pk in @([string]$AllowedKeys -split ',')) { if (([string]$pk) -ne '') { $pub[[string]$pk] = 1 } }
  $notes = @()
  $asked = @{}
  # v4.4.0 (S-92): the asks are read out of the AST, not the text. A text pattern had two failures at
  # once: it missed every double-quoted ask ($Ctx["wins"]), and it could not tell a real ask from the
  # word inside a string - which is how this card's own planted fixture was reported as a breach
  # (measured: unpublishedPlanted=asked-not-published-at-13616). Neither quote is a constant key unless
  # the AST says so, and a literal can never be an IndexExpressionAst.
  foreach ($ix in @($fd.FindAll({ param($x) $x -is [System.Management.Automation.Language.IndexExpressionAst] }, $true))) {
    $k = Get-CtxIndexKey $ix
    if ($k -eq '') { continue }
    if ($asked.ContainsKey($k)) { continue }
    $asked[$k] = 1
    if (-not $pub.ContainsKey($k)) { $notes += ($k + '=asked-not-published-at-' + [string]([int]$ix.Extent.StartLineNumber)) }
  }
  # bindings are collected from the text as well as the AST: this machine's ForEachStatementAst
  # reported an empty Variables list for real foreach headers, and a lint that trusts that reading
  # would call every loop variable a scope leak.
  $auto = '_,true,false,null,matches,lastexitcode,args,input,error,foreach,pscommandpath,psscriptroot,psboundparameters,psitem,myinvocation,pwd,home,host,ctx,psversiontable'
  $autoSet = @{}
  foreach ($an in @($auto -split ',')) { $autoSet[[string]$an] = 1 }
  $bind = @{}
  $rx = @('\$\s*([A-Za-z_][A-Za-z0-9_]*)\s*(\+|\-|\*|/)?=(?!=)',
          '\$\s*[A-Za-z_][A-Za-z0-9_]*\s*,\s*\$\s*([A-Za-z_][A-Za-z0-9_]*)',
          'foreach\s*\(\s*\$\s*([A-Za-z_][A-Za-z0-9_]*)',
          '\[\s*ref\s*\]\s*\$\s*([A-Za-z_][A-Za-z0-9_]*)')
  for ($i = $f; $i -le $last; $i++) {
    $tl = [string]$ls[$i - 1]
    if ($tl -match '^\s*#') { continue }
    # v4.4.0 (S-92): single-quoted spans are LITERAL text, so a "$x = 1" inside one binds nothing -
    # and a scan that counts it as a binding will happily report clean after the real adapter line is
    # deleted (measured by the review, and by my own rig which was stricter than the gate it was
    # predicting). Double-quoted spans are left alone because PowerShell interpolates them.
    $tl = [regex]::Replace($tl, "'[^']*'", "''")
    foreach ($r in $rx) {
      foreach ($m in @([regex]::Matches($tl, $r))) { $bk = ([string]$m.Groups[1].Value).ToLowerInvariant(); $bind[$bk] = 1 }
    }
    foreach ($m in @([regex]::Matches($tl, 'param\s*\(([^)]*)\)'))) {
      foreach ($pp in @([regex]::Matches([string]$m.Groups[1].Value, '\$\s*([A-Za-z_][A-Za-z0-9_]*)'))) {
        $bk = ([string]$pp.Groups[1].Value).ToLowerInvariant()
        $bind[$bk] = 1
      }
    }
  }
  foreach ($a in @($fd.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true))) {
    foreach ($l in @($a.Left)) {
      if ($l -is [System.Management.Automation.Language.VariableExpressionAst]) {
        $nm = [string]$l.VariablePath.UserPath
        if ($nm -ne '') { $bk = ([string]$nm).ToLowerInvariant(); $bind[$bk] = 1 }
      }
    }
  }
  # v4.4.0 (A-14q): a NESTED function binds its own parameters, and neither the four text patterns
  # above nor AssignmentStatementAst says so. Without this a family that carries a helper (A-14q lifts
  # ST-MkShot, the first case) is accused of reading the caller for names it owns. Measured on both
  # engines: FunctionDefinitionAst exposes Name/Parameters/Body/Extent/Parent and NO ScriptBlock, so
  # the parameters are taken from ParameterAst nodes - which also cover an inline signature, because
  # `function F([string]$p)` and `param([string]$p)` parse to the same ParameterAst.
  foreach ($npa in @($fd.FindAll({ param($x) $x -is [System.Management.Automation.Language.ParameterAst] }, $true))) {
    if ($null -eq $npa.Name) { continue }
    $nnm = [string]$npa.Name.VariablePath.UserPath
    if ($nnm -ne '') { $bind[$nnm.ToLowerInvariant()] = 1 }
  }
  $seenFree = @{}
  foreach ($u in @($fd.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true))) {
    $vp = $u.VariablePath
    if ($null -eq $vp) { continue }
    if ($vp.IsGlobal -or $vp.IsScript) { continue }
    # PS 5.1 has no IsConstant/IsLocal on this object, so every other qualified form ($env:, $using:,
    # ${function:}) is caught by the sigil in the extent text - a name cannot contain a colon.
    if (([string]$u.Extent.Text).Contains(':')) { continue }
    $nm = ([string]$vp.UserPath).ToLowerInvariant()
    if ($nm -eq '') { continue }
    if ($autoSet.ContainsKey($nm)) { continue }
    if ($bind.ContainsKey($nm)) { continue }
    if ($seenFree.ContainsKey($nm)) { continue }
    $seenFree[$nm] = 1
    $notes += ($nm + '=free-read-at-' + [string]([int]$u.Extent.StartLineNumber))
  }
  return ($notes -join ';')
}

function Get-CheckCallCountInFunction($Parsed, [string]$FunctionName) {
  # How many check emitters a body actually calls. A family that lost its gates on the way out reads
  # as 0 here, which is the one number this card must not have to eyeball.
  if ($null -eq $Parsed) { return '-no-parse' }
  if ($null -eq $Parsed.Root) { return '-no-parse' }
  $found = $false
  $n = 0
  foreach ($cand in @($Parsed.Root.FindAll({ param($n2) $n2 -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
    if (([string]$cand.Name) -cne [string]$FunctionName) { continue }
    $found = $true
    foreach ($c in @($cand.FindAll({ param($x) $x -is [System.Management.Automation.Language.CommandAst] }, $true))) {
      $cn = [string]$c.GetCommandName()
      foreach ($want in @('ST-Check', 'ST-Skip', 'ST-SkipRegion', 'ST-ReconcileRegion')) {
        if ($cn -ceq $want) { $n = $n + 1 }
      }
    }
    break
  }
  if (-not $found) { return '-absent' }
  return ([string]$n)
}

function Get-CommaReturningHelperNames([string]$Code, [string[]]$ExemptNames) {
  # Which functions this source looks "comma-returning" to, minus the names the caller exempts. This is
  # the one copy of that judgement (A-14f pulled it out of the lint so the exemption can be TESTED -
  # a gate that can never be reached is decoration, and a lifted family invented as a helper emits two
  # gates for itself and breaks the declared total, which is exactly what happened in A-14e).
  $want = @{}
  foreach ($n in @($ExemptNames)) { if (([string]$n) -ne '') { $want[[string]$n] = 1 } }
  $out = @()
  foreach ($m in @([regex]::Matches([string]$Code, '(?m)^function\s+([A-Za-z][A-Za-z0-9_-]*)\b[\s\S]*?^\}'))) {
    $nm = [string]$m.Groups[1].Value
    if ($want.ContainsKey($nm)) { continue }
    if (([string]$m.Value) -match 'return\s+,') { $out += $nm }
  }
  return ($out -join ',')
}

function Get-WindowCopyCountInBodies($Parsed, [string[]]$Lines, [string[]]$Names) {
  # How many times a selftest body re-derives the production window instead of taking the published one.
  # One source of truth exists (Get-SelftestWindow -> $Ctx); the second copy went stale the moment its
  # body moved into its own file, and that is what reddened the truncation lint during A-14i. The needle
  # is assembled from code points so this leaf can never be the hit it reports (P-05/P-06/X-01 lineage).
  if ($null -eq $Parsed) { return '-no-parse' }
  if ($null -eq $Parsed.Root) { return '-no-parse' }
  $ls = @($Lines)
  $nameTok = Get-CharCodeWord @(0x49, 0x6E, 0x76, 0x6F, 0x6B, 0x65, 0x2D, 0x53, 0x65, 0x6C, 0x66, 0x54, 0x65, 0x73, 0x74)
  $needle = '-match ' + [string][char]39 + '^function ' + $nameTok + [string][char]39
  $want = @{}
  foreach ($n in @($Names)) { if (([string]$n) -ne '') { $want[[string]$n] = 1 } }
  if ($want.Count -eq 0) { return '-absent' }
  $out = @()
  $seen = 0
  foreach ($fd in @($Parsed.Root.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
    if (-not $want.ContainsKey([string]$fd.Name)) { continue }
    $isTop = $true
    $pp = $fd.Parent
    while ($null -ne $pp) {
      if ($pp -is [System.Management.Automation.Language.FunctionDefinitionAst]) { $isTop = $false; break }
      $pp = $pp.Parent
    }
    if (-not $isTop) { continue }
    $seen = $seen + 1
    $c = 0
    $f = [int]$fd.Extent.StartLineNumber
    $t = [int]$fd.Extent.EndLineNumber
    for ($i = $f; $i -le [Math]::Min($t, $ls.Count); $i++) {
      if (([string]$ls[$i - 1]).Contains($needle)) { $c = $c + 1 }
    }
    if ($c -gt 0) { $out += (([string]$fd.Name) + '=' + [string]$c) }
  }
  # a scan that matched no body at all could not have found anything - say so, do not report 'clean'
  if ($seen -eq 0) { return '-absent' }
  return ($out -join ';')
}

function Get-PressWarnRouteNote([string[]]$Lines) {
  # The same question the trim gate asks, for a different sentence: is the warning routed by the JSON
  # flag, and does each road speak EXACTLY once? Exactly-once is the teeth: a scan happy with "at least
  # one success-stream echo" would still pass with the plain road deleted, because the assignment line
  # also mentions the variable. The plain road is additionally pinned to its EXACT words, because the
  # ruling's promise was 'the non-JSON road keeps behaving as it did' - counting echoes alone would let a
  # rewrite of the sentence pass while still looking routed. Tokens are assembled because this file is part
  # of what gets read, and
  # the line numbers in the notes are positions inside the array handed in (the caller scopes it).
  $ls = @($Lines)
  $errTok = 'Error.WriteLine([string]$pressWar' + 'n)'
  $plainTok = 'Output $pressWar' + 'n'
  $flagTok = [string][char]0x24 + 'script:Json'
  $errAt = @()
  $plainAt = @()
  for ($i = 0; $i -lt $ls.Count; $i++) {
    $t = [string]$ls[$i]
    if ($t.Contains($errTok)) { $errAt += ($i + 1) }
    if ($t.Contains($plainTok)) { $plainAt += ($i + 1) }
  }
  if (@($errAt).Count -ne 1) { return 'press-error-route=' + @($errAt).Count + '-want1' }
  if (@($plainAt).Count -ne 1) { return 'press-plain-road=' + @($plainAt).Count + '-want1' }
  $plainTxt = ([string]$ls[[int]$plainAt[0] - 1]).Trim()
  if ($plainTxt -cne 'Write-Output $pressWarn') { return 'press-plain-words-changed-at-' + $plainAt[0] }
  $ln = [int]$errAt[0]
  $seen = $false
  for ($back = ($ln - 8); $back -le ($ln - 1); $back++) {
    if ($back -lt 1) { continue }
    if (([string]$ls[$back - 1]).Contains($flagTok)) { $seen = $true }
  }
  if (-not $seen) { return 'press-error-route-at-' + $ln + '-without-json-branch' }
  return ''
}

function Format-JsonProbeDump([string]$Text, [bool]$Parsed) {
  # Length, the parse verdict and the head of the stream with newlines folded, bounded so a large
  # envelope cannot flood the report and marked when it was cut. Printed whether the check passes or not:
  # a green with a hidden polluter is exactly as blind as a red without one.
  $t = [string]$Text
  $limit = 260
  $cut = ''
  if ($t.Length -gt $limit) { $cut = ' (cut)' }
  $head = $t.Substring(0, [math]::Min($limit, $t.Length)) -replace "`r?`n", ' | '
  return 'len=' + $t.Length + ' parsed=' + $Parsed + ' head=[' + $head + ']' + $cut
}

function Write-JsonProbeEvidence {
  param([string]$Label, [string]$Stdout, [string]$Stderr, [string]$Code, [bool]$Parsed,
        [string]$ParseWhy, [string]$Dir, [string]$Source)
  # G-23: the printed head is bounded on purpose, so BOTH shapes - a clean envelope and an envelope with
  # a tail polluter glued after it - end with the same ' (cut)' marker and the head cannot tell them apart
  # (measured, not assumed). This keeps the two streams whole on disk BEFORE any head is cut, with the
  # child's real exit code, the parse verdict and the parse exception text, and returns the one line the
  # reading prints so a red points at the file instead of at a truncation. Nothing here reads a global:
  # every input arrives as a parameter, and the only side effect is this file.
  if (-not $Label) { throw 'json-probe evidence: empty label - a file nobody can name is not evidence' }
  if (-not $Dir) { throw 'json-probe evidence: no directory given' }
  $so = [string]$Stdout
  $se = [string]$Stderr
  $hex = { param($Bytes) (($Bytes | ForEach-Object { $_.ToString('x2') }) -join '') }
  $sha = { param($Text)
    $alg = [System.Security.Cryptography.SHA256]::Create()
    try { return & $hex $alg.ComputeHash([System.Text.Encoding]::UTF8.GetBytes([string]$Text)) }
    finally { $alg.Dispose() }
  }
  New-Item -ItemType Directory -Force -Path $Dir | Out-Null
  $name = 'json-probe-' + $Label + '-' + ([Guid]::NewGuid().ToString('N')).Substring(0, 12) + '.txt'
  $path = Join-Path $Dir $name
  $body = @(
    ('JSON-PROBE-EVIDENCE label=' + $Label + ' parsed=' + $Parsed + ' exit=' + $Code),
    ('source=' + $Source),
    ('stdout-bytes=' + [System.Text.Encoding]::UTF8.GetByteCount($so) + ' stdout-sha256=' + (& $sha $so)),
    ('stderr-bytes=' + [System.Text.Encoding]::UTF8.GetByteCount($se) + ' stderr-sha256=' + (& $sha $se)),
    ('written=' + (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')),
    '---- STDOUT BEGIN ----', $so, '---- STDOUT END ----',
    '---- STDERR BEGIN ----', $se, '---- STDERR END ----',
    '---- PARSE EXCEPTION ----', [string]$ParseWhy
  ) -join "`n"
  [System.IO.File]::WriteAllText($path, $body, (New-Object System.Text.UTF8Encoding($false)))
  $fi = New-Object System.IO.FileInfo($path)
  return 'evidence=' + $path + ' file-bytes=' + $fi.Length +
    ' stdout-bytes=' + [System.Text.Encoding]::UTF8.GetByteCount($so) + ' stdout-sha=' + ((& $sha $so).Substring(0, 12)) +
    ' stderr-bytes=' + [System.Text.Encoding]::UTF8.GetByteCount($se) + ' stderr-sha=' + ((& $sha $se).Substring(0, 12))
}

function Get-TrimJsonRouteNote([string[]]$Lines) {
  # Does the auto-trim echo honour the JSON flag? Answer: '' when the error-stream route exists AND
  # the success-stream echo exists (both roads still speak), a named note otherwise. Line numbers in
  # the notes are positions inside the array handed in, so callers scope the array they scan. A route
  # that speaks to the host instead of the error stream is not counted as routed, and surfaces as
  # no-error-stream-route. The token is assembled from parts because this file is itself part of what
  # gets read - a literal here would match its own definition and every count would come out high.
  # The lookback is INCLUSIVE of the line directly above: the first version of this bound used -lt and
  # could not see a guard one line up, which is exactly how the route is actually written (measured on
  # the first full run: live=[error-route-at-2704-without-json-branch] with the guard sitting at 2703).
  $ls = @($Lines)
  $tok = '$trimNote' + '.Note'
  $errTok = 'Error.WriteLine'
  $flagTok = [string][char]0x24 + 'script:Json'
  $echoAt = @()
  for ($i = 0; $i -lt $ls.Count; $i++) {
    if (([string]$ls[$i]).Contains($tok)) { $echoAt += ($i + 1) }
  }
  if (@($echoAt).Count -lt 2) { return 'trim-note-echoes=' + @($echoAt).Count + '-want2-json-and-plain' }
  $routed = 0
  $plain = 0
  foreach ($ln in $echoAt) {
    $txt = [string]$ls[[int]$ln - 1]
    if ($txt.Contains($errTok)) {
      $seen = $false
      for ($back = ([int]$ln - 8); $back -le ([int]$ln - 1); $back++) {
        if ($back -lt 1) { continue }
        if (([string]$ls[$back - 1]).Contains($flagTok)) { $seen = $true }
      }
      if ($seen) { $routed = $routed + 1 } else { return 'error-route-at-' + $ln + '-without-json-branch' }
    } else {
      $plain = $plain + 1
    }
  }
  if ($routed -lt 1) { return 'no-error-stream-route' }
  if ($plain -lt 1) { return 'plain-road-echo-missing' }
  return ''
}

function Get-FamilyExportNames([string]$Key) {
  # The declared hand-back list for one lifted family, or an empty array when it declares none.
  if ($null -eq $script:StFamilyExports) { return @() }
  if (-not $script:StFamilyExports.ContainsKey($Key)) { return @() }
  return @($script:StFamilyExports[$Key])
}

function Get-FamilyExportGap($Parsed, [string]$FunctionName, [string[]]$Declared) {
  # Two directions, both must be empty: a declared export the body never writes (the orchestrator
  # would re-bind a key that is never set - a silent $null in the next body), and a key the body
  # writes that nobody declared (state leaving the family invisible to every table). Sentinels beat
  # an empty string, because "could not measure" must not read as "nothing to report".
  if ($null -eq $Parsed) { return '-no-parse' }
  if ($null -eq $Parsed.Root) { return '-no-parse' }
  $fd = $null
  foreach ($cand in @($Parsed.Root.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
    if (([string]$cand.Name) -cne [string]$FunctionName) { continue }
    $fd = $cand
    break
  }
  if ($null -eq $fd) { return '-absent' }
  $written = @{}
  # v4.4.0 (S-92): same hole, same repair on the write side - the text pattern knew only single quotes,
  # so $Ctx["wA"] = ... would have left the family with an undeclared hand-back nobody could see. The
  # AST is the source: an assignment whose LEFT is an index into $Ctx.
  foreach ($as in @($fd.FindAll({ param($x) $x -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true))) {
    foreach ($lft in @($as.Left)) {
      $k = Get-CtxIndexKey $lft
      if ($k -eq '') { continue }
      $written[$k] = 1
    }
  }
  $notes = @()
  foreach ($k in @($Declared)) {
    if (([string]$k) -eq '') { continue }
    if (-not $written.ContainsKey([string]$k)) { $notes += (([string]$k) + '=declared-not-written') }
  }
  foreach ($k in @(Get-HashKeys $written | Sort-Object)) {
    $decl = $false
    foreach ($d2 in @($Declared)) { if (([string]$d2) -ceq [string]$k) { $decl = $true } }
    if (-not $decl) { $notes += (([string]$k) + '=written-not-declared') }
  }
  return ($notes -join ';')
}

function Get-FamilyExportReadbackGap($Parsed, [string[]]$Lines, [string]$FunctionName, [string[]]$Declared) {
  # The other half of the hand-back channel, in three refusals:
  #  - a declared key with no line re-binding it below the call: the value stops at the context object
  #    and the bodies that were written against the inline scope still read the OLD name;
  #  - a re-bind ABOVE the call, which binds whatever the previous body left there - a plausible value
  #    is worse than $null because nothing downstream looks broken;
  #  - a key re-bound twice, or a family called twice (two bindings of one channel, one of them a copy).
  # Then the demand side: a declared export that nobody reads after its re-bind is a channel to nowhere,
  # so the table would carry a name forever that no body needs. Readers are counted out of the parse,
  # below the re-bind line and outside this family's own extent - inside the family the name is just its
  # local, and counting those would let a family export a value only it ever sees.
  if ($null -eq $Parsed) { return '-no-parse' }
  if ($null -eq $Parsed.Root) { return '-no-parse' }
  $fd = $null
  foreach ($cand in @($Parsed.Root.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
    if (([string]$cand.Name) -cne [string]$FunctionName) { continue }
    $fd = $cand
    break
  }
  if ($null -eq $fd) { return '-absent-body' }
  $ls = @($Lines)
  if (@($ls).Count -eq 0) { return '-no-lines' }
  $d = [string][char]0x24
  $q = [string][char]39
  # v4.4.0 (A-14r): a lifted family binding  $k = $Ctx[k]  in its own adapter is a CONSUMER binding,
  # not the read-back this predicate is asked to certify. A-14q could not reach that shape (a family
  # call above the publish cannot consume a hand-back); A-14r moved the call below it, so gate-meta
  # now carries it for three names and the scan read the channel as doubled. Bindings inside any
  # Invoke-SelftestFamily body are skipped; the orchestration still owes exactly one per key, and a
  # duplicate planted at top level still reddens (the plant fixtures have no family body).
  $famPre = 'Invoke-Selftest' + 'Family-'
  $famSpans = @()
  foreach ($fd2 in @($Parsed.Root.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
    if (([string]$fd2.Name).StartsWith($famPre)) { $famSpans += , @([int]$fd2.Extent.StartLineNumber, [int]$fd2.Extent.EndLineNumber) }
  }
  $b = [string][char]0x5C
  $callPat = '^\s*' + [string]$FunctionName + '\s+' + $b + $d + 'Ctx\s*$'
  $callLn = -1
  $callCount = 0
  for ($i = 0; $i -lt $ls.Count; $i++) {
    if ([regex]::IsMatch([string]$ls[$i], $callPat)) { $callCount = $callCount + 1; if ($callLn -lt 0) { $callLn = $i + 1 } }
  }
  if ($callLn -lt 0) { return ([string]$FunctionName + '-no-call') }
  $f = [int]$fd.Extent.StartLineNumber
  $t = [int]$fd.Extent.EndLineNumber
  $vars = @($Parsed.Root.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true))
  $notes = @()
  foreach ($k in @($Declared)) {
    if (([string]$k) -eq '') { continue }
    $rbPat = '^\s*' + $b + $d + ([string]$k) + '\s*=\s*' + $b + $d + 'Ctx\[' + $q + ([string]$k) + $q + '\]\s*$'
    $hits = @()
    for ($i = 0; $i -lt $ls.Count; $i++) {
      if (-not ([regex]::IsMatch([string]$ls[$i], $rbPat))) { continue }
      $inFam = $false
      foreach ($sp in @($famSpans)) { if ((@($sp).Count -eq 2) -and (($i + 1) -ge [int]$sp[0]) -and (($i + 1) -le [int]$sp[1])) { $inFam = $true } }
      if ($inFam) { continue }
      $hits += ($i + 1)
    }
    if (@($hits).Count -eq 0) { $notes += (([string]$k) + '=never-read-back'); continue }
    if (@($hits).Count -gt 1) { $notes += (([string]$k) + '=read-back-dup' + @($hits).Count); continue }
    if ([int]$hits[0] -lt $callLn) { $notes += (([string]$k) + '=read-before-call'); continue }
    $rd = 0
    foreach ($v in $vars) {
      if (([string]$v.VariablePath.UserPath) -cne ([string]$k)) { continue }
      $vl = [int]$v.Extent.StartLineNumber
      if ($vl -le [int]$hits[0]) { continue }
      if ($vl -ge $f -and $vl -le $t) { continue }
      $rd = $rd + 1
    }
    if ($rd -eq 0) { $notes += (([string]$k) + '=no-downstream-reader') }
  }
  if ($callCount -gt 1) { $notes += ('call-dup=' + $callCount) }
  return ($notes -join ';')
}

function Get-SelftestWindow($Parsed, [string[]]$Names) {
  # The aggregate line range every selftest body occupies: the first named body's first line through
  # the last named body's last line, both straight from AST extents. Deliberately NOT "up to the next
  # ^function" - that open interval stops at the first family file, so every family that moves out
  # silently re-enters the production side of every scan that uses this window.
  # 1-based inclusive: return is '<start>TAB<end>', or -no-parse / -absent (a scan that could not run
  # must never read as "nothing is exempt").
  if ($null -eq $Parsed) { return '-no-parse' }
  if ($null -eq $Parsed.Root) { return '-no-parse' }
  $want = @{}
  foreach ($n in @($Names)) { if (([string]$n) -ne '') { $want[[string]$n] = 1 } }
  if ($want.Count -eq 0) { return '-absent' }
  $lo = -1; $hi = -1
  foreach ($fd in @($Parsed.Root.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
    if (-not $want.ContainsKey([string]$fd.Name)) { continue }
    # a name may also appear as a nested definition; the window is about top-level bodies
    $isTop = $true
    $pp = $fd.Parent
    while ($null -ne $pp) {
      if ($pp -is [System.Management.Automation.Language.FunctionDefinitionAst]) { $isTop = $false; break }
      $pp = $pp.Parent
    }
    if (-not $isTop) { continue }
    $s = [int]$fd.Extent.StartLineNumber
    $t = [int]$fd.Extent.EndLineNumber
    if ($lo -lt 0 -or $s -lt $lo) { $lo = $s }
    if ($t -gt $hi) { $hi = $t }
  }
  if ($lo -lt 0) { return '-absent' }
  return (([string]$lo) + "`t" + ([string]$hi))
}

function Get-ForeignFunctionNames($Parsed, [string[]]$Names, [string]$Window) {
  # Function definitions that sit INSIDE the window but are not selftest bodies. The window is a
  # blanket exemption for every production scan, so a foreign body inside it would be invisible to
  # all of them at once - which is why the width of the window has to be checked, not trusted.
  # Returns '-no-parse' / '-bad-window' rather than an empty string when it could not measure.
  if ($null -eq $Parsed) { return '-no-parse' }
  if ($null -eq $Parsed.Root) { return '-no-parse' }
  $w = @([string]$Window -split "`t", 2)
  if (@($w).Count -lt 2) { return '-bad-window' }
  $lo = 0; $hi = 0
  if (-not [int]::TryParse([string]$w[0], [ref]$lo)) { return '-bad-window' }
  if (-not [int]::TryParse([string]$w[1], [ref]$hi)) { return '-bad-window' }
  $want = @{}
  foreach ($n in @($Names)) { if (([string]$n) -ne '') { $want[[string]$n] = 1 } }
  $out = @()
  foreach ($fd in @($Parsed.Root.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
    # nested definitions are not neighbours in the aggregate - a selftest body legitimately declares its
    # own helpers inside itself (ST-MkShot does), and counting those as intruders would demand the
    # window shrink to nothing. Only a TOP-LEVEL function between the bodies is an over-exemption.
    $isTop = $true
    $pp = $fd.Parent
    while ($null -ne $pp) {
      if ($pp -is [System.Management.Automation.Language.FunctionDefinitionAst]) { $isTop = $false; break }
      $pp = $pp.Parent
    }
    if (-not $isTop) { continue }
    $nm = [string]$fd.Name
    if ($want.ContainsKey($nm)) { continue }
    $s = [int]$fd.Extent.StartLineNumber
    if ($s -ge $lo -and $s -le $hi) { $out += $nm }
  }
  return ($out -join ',')
}

function Get-FamilyBannerRecords($Parsed, [string[]]$Lines, [string[]]$Names) {
  # Records 'title<TAB>span', one per family banner inside the selftest bodies, in source order.
  # The scope is the FUNCTION SET, taken from the AST - not "the rest of the file": in the installed
  # single-file product the dispatcher and the help section also carry banners, and a file-scoped
  # scan would quietly count them here (the registered numbers would then mean different things in
  # the two modes, which is the exact failure A-06 made the mode announce itself for).
  # A-14b widened one function into a set: as soon as a family lives in its own file its banners leave
  # Invoke-SelfTest, and a scan that still looked only there would read them as 0 - the loudest
  # possible way to lose a family is a gate that reports it as empty.
  $out = @()
  # '-no-parse', not '': a scan that could not run must not look like a scan that found nothing,
  # and the caller's -ceq test cannot tell those apart once both are empty strings.
  if ($null -eq $Parsed) { return '-no-parse' }
  $root = $Parsed.Root
  if ($null -eq $root) { return '-no-parse' }
  $want = @{}
  foreach ($n in @($Names)) { if (([string]$n) -ne '') { $want[[string]$n] = 1 } }
  if ($want.Count -eq 0) { $want['Invoke-SelfTest'] = 1 }
  $scopes = @()
  foreach ($fd in @($root.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
    if (-not $want.ContainsKey([string]$fd.Name)) { continue }
    $scopes += [pscustomobject]@{ From = [int]$fd.Extent.StartLineNumber; To = [int]$fd.Extent.EndLineNumber }
  }
  if (@($scopes).Count -eq 0) { return '-absent' }
  $ls = @($Lines)
  foreach ($sc in $scopes) {
    $marks = @()
    for ($i = [int]$sc.From; $i -le [Math]::Min([int]$sc.To, $ls.Count); $i++) {
      $t = [string]$ls[$i - 1]
      if ($t -match '^\s*#\s*-{6,}\s*(.+?)\s*-{0,}\s*$') {
        $title = [string]$Matches[1]
        if ($title.Length -ge 4) { $marks += [pscustomobject]@{ Line = $i; Title = $title } }
      }
    }
    $markCount = @($marks).Count
    for ($k = 0; $k -lt $markCount; $k++) {
      $nextLine = ([int]$sc.To + 1)
      if (($k + 1) -lt $markCount) { $nextLine = [int]$marks[$k + 1].Line }
      $span = $nextLine - [int]$marks[$k].Line
      if ($span -lt 1) { $span = 1 }
      $out += ([string]$marks[$k].Title + "`t" + [string]$span)
    }
  }
  return ($out -join "`n")
}

function Get-FamilyAssignText([string]$Records, [array]$Order, [hashtable]$Fragments) {
  # Precedence-resolved tallies: family<TAB>banners<TAB>lines, one row per family seen, plus an
  # '(unclaimed)' row when a banner matches no declared fragment. First match wins BY THE DECLARED
  # ORDER - the order is data, so a claim conflict is a decision someone made, not a race.
  $rows = @()
  if (([string]$Records -ceq '-absent') -or ([string]$Records -ceq '-no-parse')) { return [string]$Records }
  if ($Records -ne '') { $rows = @($Records -split "`n") }
  $counts = @{}
  $totals = @{}
  foreach ($r in $rows) {
    if ($r -eq '') { continue }
    $f = @([string]$r -split "`t", 2)
    $title = [string]$f[0]
    $span = 1
    if (@($f).Count -ge 2) { $sp = 0; if ([int]::TryParse([string]$f[1], [ref]$sp)) { $span = $sp } }
    $owner = '(unclaimed)'
    foreach ($k in @($Order)) {
      $hit = $false
      foreach ($fr in @($Fragments[$k])) { if ($title.Contains([string]$fr)) { $hit = $true; break } }
      if ($hit) { $owner = [string]$k; break }
    }
    $b = 0
    if ($counts.ContainsKey($owner)) { $b = [int]$counts[$owner] }
    $counts[$owner] = $b + 1
    $l = 0
    if ($totals.ContainsKey($owner)) { $l = [int]$totals[$owner] }
    $totals[$owner] = $l + $span
  }
  $out = @()
  foreach ($k in (@($Order) + @('(unclaimed)'))) {
    if (-not $counts.ContainsKey($k)) { continue }
    $out += ([string]$k + "`t" + [string]$counts[$k] + "`t" + [string]$totals[$k])
  }
  return ($out -join "`n")
}

function Get-FamilyAgreement([string]$AssignText, [array]$Order, [hashtable]$Registered) {
  # Compares the measured tallies with the registered table. Anything that shows up unregistered,
  # goes missing, changes size, or is claimed by nobody is named - a silent shrink of a family is
  # how a section would get lost when the selftest body is later carved into family files.
  $notes = @()
  if ([string]$AssignText -ceq '-absent') { return 'family-selftest-body-absent' }
  if ([string]$AssignText -ceq '-no-parse') { return 'family-no-parse' }
  if ([string]$AssignText -ceq '') { return 'family-no-records' }
  $seen = @()
  foreach ($r in @($AssignText -split "`n")) {
    if ($r -eq '') { continue }
    $f = @([string]$r -split "`t", 3)
    $k = [string]$f[0]
    $b = [string]$f[1]
    $l = [string]$f[2]
    $seen += $k
    if ($k -ceq '(unclaimed)') { $notes += ('unclaimed-banners=' + $b + '-lines=' + $l); continue }
    $declared = $false
    foreach ($o in @($Order)) { if ([string]$o -ceq $k) { $declared = $true } }
    if (-not $declared) { $notes += ($k + '=not-in-declared-order'); continue }
    if (-not $Registered.ContainsKey($k)) { $notes += ($k + '=not-registered'); continue }
    $want = [string]$Registered[$k]
    $got = 'banners=' + $b + ',lines=' + $l
    if ($got -cne $want) { $notes += ($k + '=got' + $got + '-want' + $want) }
  }
  foreach ($o in @($Order)) {
    $hit = $false
    foreach ($s in $seen) { if ([string]$s -ceq [string]$o) { $hit = $true } }
    if (-not $hit) { $notes += ([string]$o + '=registered-but-empty') }
  }
  return ($notes -join ';')
}

# The attribution table for the selftest body. Fragments are matched against the BANNER TITLE, never
# against a line number, so a move that shifts lines cannot change who owns what. live-suite is first
# on purpose: 'live: ' is a mode marker, and every live banner also repeats its topic family's words -
# precedence decides that, and the decision is data rather than a coincidence of hash ordering.
$script:StFamilyOrder = @('live-suite', 'split-machine', 'repo-contract', 'popup-occlusion', 'window-targeting', 'capture-ocr', 'expect-family', 'flags-grammar', 'audit-output', 'chrome-cdp', 'challenge-workflow', 'drag-press', 'clipboard-input', 'docs-contract', 'gate-meta')
$script:StFamilyFragments = @{
  'live-suite' = @('live: ')
  'split-machine' = @('a handler group leaves the entry only by naming the file it goes to', 'v4.4.0 (A-0', 'v4.4.0 (A-11', 'v4.4.0 (A-12', 'v4.4.0 (A-14', 'v4.4.0 (A-23', 'v4.4.0 (S-9', 'file encoding invariants')
  'repo-contract' = @('version number sync', 'v4.5.5 (TB-1)', 'tracked-file count', 'tracked in the INDEX', 'offline-check total')
  'popup-occlusion' = @('same-process popup', 'no---to send path must take the SAME popup baseline', 'occlusion self-proof', 'popup survival guard', 'popup delta merge', 'red-1/red-2', 'the operating rule, made mechanical')
  'window-targeting' = @('window label, including the anonymous', 'the main-window rule is a pure function', 'Resolve-Window selector semantics', 'the composite locator', 'idempotent activation', 'uia-tree file route', 'open-and-pick', 'the take-a-coordinate ladder', 'find --region''s inverted validator', 'the UIA-driven Chrome exit menu', 'the landing identity check and the post-activation state read')
  'capture-ocr' = @('OCR a saved capture', 'CJK spacing', 'OCR retry decision', 'tiled OCR planner', 'one OCR tail for every miss', 'sparse-read hint', 'needle sub-span aiming', 'folded-long-payload', 'folded long payload receipt')
  'expect-family' = @('the expect family names its patience', 'B-1/B-2/B-3', 'autoexpect', 'wiring (default-on must stay WIRED', 'the expectation anchor is fail-closed', 'the verbatim expectation legs', 'every verify call site passes the patience', '--verify-timeout', 'F-02: the 7th positional argument')
  'flags-grammar' = @('a flag must be REACHABLE', 'the named-stub conversion is machine-checked', 'Strip-OwnFlags', 'sibling-flag hint', 'Bool flags, per-command shared routing', 'the auto-grid decision', 'no miss message writes its own tail', 'truncation must self-report', 'the case shape is judged from the AST', 'a miss carries every premise', 'numeric arguments fail readably', 'the same hole elsewhere', 'the chrome family''s own promises', 'menu-pick target predicate', 'menu-pick''s extracted parser', 'the six "do not lose" contracts')
  'audit-output' = @('audit-log redaction + rotation', 'the two OCR --json top-level key sets', 'covering list is rendered in ONE place', 'the action family''s --json envelope', '--json must never be accepted and ignored', '--dump (write the bulk to a file', 'a stamp that CLAIMS UTC', 'resource hygiene', 'the line/occurrence gap must be spoken out loud', 'residual resolve sentences must not enter the envelope')
  'chrome-cdp' = @('CDP client and a11y route', 'the CDP viewport fallback had one axis', 'the UIA cold-start re-contact', 'action tokens + structural path handles', 'the Rect.Empty family', 'TB-2 (2026-10-24)')
  'challenge-workflow' = @('verification-challenge workflow', 'the process-entry environment normalizer')
  'drag-press' = @('the drag mid-state gate', 'the pairing id is HANDED OVER', 'drag''s landing guard')
  'clipboard-input' = @('clipboard kind branch', 'confusable fold is a marked SECOND pass', 'strict UTF-8 gate for sent files', 'a parked pick says parked')
  'docs-contract' = @('the usage PAGE itself is well-formed', 'advertises a ladder must walk the same one', 'document-consistency sweep', 'the skill loader''s command list is an outward', 'the quick-start guide is an outward contract', 'the skill loader scripts carry the project guards', 'help <command> - the page gets an index', 'TB-5: the uninstaller', 'TB-4: the outward docs', 'TB-6: the newcomer document', 'TB-6 (repository face)')
  'gate-meta' = @('every STATIC regex literal in the file must COMPILE', 'forbidden @()/$() wrapper', 'pure helpers', 'the exact return-shape semantics', 'call arity: a dead argument', 'every Test-* guard is called WITH the arguments', 'nothing in production is a PowerShell automatic variable', 'one owner per constant', 'the two copied BLOCKS', 'v4.2.4: --timing', 'no @(array).Count inside a for-condition', 'two preventive lints from the six-trap ledger', '--index / --only contracts', 'step assembly purity', 'the small-fix bundle', 'tab manifest reconciliation', 'replay flag parsing + redaction refusal', 'JSON array unwrapping', 'window model', 'shot cleanup plan', 'quarantine resolution', 'the automatic capture-folder trim', 'same @() trap, pipeline form', 'F-00-A: a guard promise', 'the live suite must not fail on its environment', 'workshop self-report', 'the line/occurrence', 'v4.5.0 (CU-CALL offline runtime)', 'v4.5.1 (CU-REL-02)', 'v4.5.2 (CU-REL-03)', 'v4.5.3 (CU-REL-04)', 'v4.5.4 (CU-REL-05)', 'TB-3: the MANIFEST row')
}
$script:StFamilyFragments['docs-contract'] += @('the uninstaller''s recursive delete is gated and bounded', 'the outward docs must not teach a send into a real conversation')
$script:StFamilyCounts = @{
  'split-machine' = 'banners=23,lines=1323'
  'repo-contract' = 'banners=5,lines=322'
  'gate-meta' = 'banners=30,lines=2793'
  'flags-grammar' = 'banners=16,lines=882'
  'capture-ocr' = 'banners=8,lines=757'
  'popup-occlusion' = 'banners=7,lines=348'
  'audit-output' = 'banners=10,lines=940'
  'window-targeting' = 'banners=11,lines=1081'
  'expect-family' = 'banners=9,lines=705'
  'clipboard-input' = 'banners=4,lines=181'
  'docs-contract' = 'banners=11,lines=524'
  'chrome-cdp' = 'banners=6,lines=475'
  'drag-press' = 'banners=3,lines=199'
  'challenge-workflow' = 'banners=2,lines=206'
  'live-suite' = 'banners=20,lines=3215'
}

# The families whose bodies have actually been lifted into lib/selftest-<key>.ps1 (A-14b onwards).
# This is the set the file/key reconciliation runs over: attribution is a topic table, a lifted family
# is a physical fact, and conflating them would let a card claim a split it did not do.
$script:StFamilyLifted = @('split-machine', 'repo-contract', 'clipboard-input', 'challenge-workflow', 'capture-ocr', 'flags-grammar', 'window-targeting', 'chrome-cdp', 'docs-contract', 'popup-occlusion', 'audit-output', 'expect-family', 'drag-press', 'live-suite', 'gate-meta')

# The context surface the selftest orchestrator publishes to lifted families (A-14c). This is the
# whole channel between an orchestration body and a family file, so it is a declared list reconciled
# by a lint - a card must not be able to hand over a fifth input, or withdraw one, silently.
# What each lifted family hands BACK through $Ctx (A-14l). A lifted body still produces state the
# orchestration reads afterwards; the return path is declared here rather than left to whatever the
# function scope happens to keep, because a value that never comes back reaches the next body as $null
# - the same silent-empty-column shape this case has caught three times on the way in.
$script:StFamilyExports = @{
  'popup-occlusion' = @('dcCase', 'dcKnown', 'wA', 'wB', 'wT')
}
# v4.4.0 A-15 (G-17 ruling): the three numbers the named-stub conversion is judged against. The inline
#    set is the design's own exception list (v6 sec 3.3: these three single-line bodies stay in the
#    skeleton); the flag set is the four bodies with a return that really returns from the dispatcher
#    (measured by ancestor chain in a15-probe7.ps1 - it is 4, not the 7 the first count claimed, and
#    the difference is three returns that live inside a value scriptblock); the unwrapped count is
#    lowered by every card that wraps cases, and a case that is neither shape is named, not counted.
$script:StHandlerInlineCases = @('selftest', 'script', 'replay')
$script:StHandlerFlagCases = @('chrome-click', 'uia-click', 'uia-focus', 'uia-settext')
$script:StHandlerUnwrapped = 0
# v4.4.0 A-16: the four handler groups, sized exactly as the design states (26/21/21/8 = all 76 lifted
#    cases), and the file each group lives in - '' means still in the entry. A-17..A-19 replace that empty
#    string with a file name IN THE SAME COMMIT that moves the code, because lint (A-16) fails on either
#    half alone (a file with no entry-side removal, or a removal with no declared file). The design fixes
#    the sizes and the category labels, not the name list, so the assignment is written down here rather
#    than re-derived differently by the next hand.
# CU-OPS-COMPLETE-20261026-01 (package C) moved the ui group from 21 to 24: 'key', 'key-state' and
#    'key-release' are three new native-keyboard cases in the same file, and the gate below now expects
#    80 names in total (27 read + 21 act + 24 ui + 8 batch).
# CU-OPS-COMPLETE-20261026-01 (package A) added the five process commands: 'proc-list'/'proc-info'/
#    'proc-wait' observe (read file) and 'proc-start'/'proc-kill' act (act file) - 30 read + 23 act
#    + 24 ui + 8 batch = 85 names. proc-kill is preview-by-default and is NOT in the replay whitelist.
# CU-OPS-COMPLETE-20261026-01 (package E) moved the ui group from 24 to 26: 'uia-state'
#    (read-only pattern report) and 'uia-do' (semantic action + readback) join the same
#    file - 30 read + 23 act + 26 ui + 8 batch = 87 names. uia-do logs one audit line;
#    uia-state is read-only and logs nothing.
# CU-OPS-COMPLETE-20261026-01 (packages D/F/H) moved read from 30 to 34: 'tpl-find'
#    (locates, never clicks), 'clip-info' (metadata only), 'wait-cond' (one bounded wait)
#    and 'capabilities' (surface derived from THIS table) - 34 read + 23 act + 26 ui
#    + 8 batch = 91 names.
$script:StHandlerGroups = @{ 'read' = @('help', 'wins', 'win', 'info', 'rect', 'rect-of', 'cursor', 'dpi', 'status-summary', 'shot', 'ocr-cap', 'hash', 'read-text', 'focus', 'find', 'find-text', 'find-color', 'color-at', 'wait-win', 'wait-gone', 'wait-stable', 'assert-changed', 'assert-window', 'assert-text', 'assert-color', 'assert-hash', 'assert-stable', 'proc-list', 'proc-info', 'proc-wait', 'tpl-find', 'clip-info', 'wait-cond', 'capabilities'); 'act' = @('move', 'hover', 'click', 'rclick', 'dblclick', 'wheel', 'relclick', 'drag', 'drag-to', 'press-down', 'press-up', 'find-click', 'win-move', 'win-resize', 'win-max', 'win-min', 'win-restore', 'win-close', 'dialog-cancel', 'menu-pick', 'open-and-pick', 'proc-start', 'proc-kill'); 'ui' = @('chrome-tabs', 'chrome-read', 'chrome-find', 'chrome-click', 'chrome-menu-read', 'chrome-debug-off', 'chrome-a11y', 'a11y-probe', 'uia-tree', 'uia-path', 'uia-find', 'uia-click', 'uia-focus', 'uia-settext', 'uia-state', 'uia-do', 'type', 'type-in', 'keys', 'key', 'key-state', 'key-release', 'ime', 'paste', 'paste-file', 'copy-file'); 'batch' = @('imgclick', 'zoom', 'ime-en', 'ime-cn', 'ime-state', 'challenge-probe', 'shots-cleanup', 'unmap') }
$script:StHandlerFiles = @{ 'read' = 'lib/handlers-read.ps1'; 'act' = 'lib/handlers-act.ps1'; 'ui' = 'lib/handlers-ui.ps1'; 'batch' = 'lib/handlers-batch.ps1' }
$script:StCtxKeys = @('actionLog', 'clCount', 'code', 'codeLines', 'commaFns', 'dcCase', 'dcKnown', 'evMark', 'evWire', 'gaCaseIdx', 'gaCases', 'gaCasesCount', 'gaDispStart', 'gaHelpEnd', 'gaHelpStart', 'hCaseStarts', 'hFnEnd', 'hFnStart', 'hLines', 'j5ProdEnd', 'j5ProdStart', 'j5SelfParsed', 'live', 'mvProd', 'outDir', 'self', 'src', 'srcLines', 'stDefIdx', 'stEndIdx', 'ToolVersion', 'w0', 'wA', 'wB', 'wins', 'wT')

# Check emitters per selftest body, counted from the AST of the aggregate. Registering the numbers is
# the point: after A-14b a family of gates can live in a file that never runs, and only a count that a
# card has to update in the same commit says so.
$script:StFamilyCheckCounts = @(
  'Invoke-SelfTest=29',
  'Invoke-SelftestFamily-CaptureOcr=101',
  'Invoke-SelftestFamily-FlagsGrammar=91',
  'Invoke-SelftestFamily-WindowTargeting=151',
  'Invoke-SelftestFamily-DocsContract=51',
  'Invoke-SelftestFamily-ChromeCdp=55',
  'Invoke-SelftestFamily-ChallengeWorkflow=18',
  'Invoke-SelftestFamily-ClipboardInput=30',
  'Invoke-SelftestFamily-RepoContract=26',
  'Invoke-SelftestFamily-SplitMachine=66',
  'Invoke-SelftestFamily-PopupOcclusion=48',
  'Invoke-SelftestFamily-AuditOutput=79',
  'Invoke-SelftestFamily-ExpectFamily=87',
  'Invoke-SelftestFamily-DragPress=22',
  'Invoke-SelftestFamily-LiveSuite=156',
  'Invoke-SelftestFamily-GateMeta=167'
)

# A-23 (criterion-5): every `exit` this tree can execute, named by the owner that holds it. Registered by CASE
# name, never by line or file: a line number moves with every card and a case name does not, and a
# stitched artifact has no files to name at all - so the same list has to read the same on both sides of
# the stitch. The handler cohort is the fourteen the design whitelists (shots-cleanup 5, challenge-probe 3,
# one each for ime-en / key / keys / paste / paste-file / type = eight cases); the entry cohort is the eleven
# that were never inside a moved body (Invoke-ScriptBatch 5, Invoke-ReplayLog 4, top level 2). A
# fifteenth handler exit is red, a new owner outside both cohorts is red, and so is any entry here that
# has gone stale. Both cohorts were measured from the AST on 2026-10-19 with both engines agreeing, and
# re-measured on 2026-10-23 when TB-3 gave shots-cleanup its fifth exit (the moved-without-a-record
# refusal) - key by key, again with both engines agreeing. CU-OPS package C added 'key=1': the native
# combination handler reuses the same post-send foreground guard as type/keys, which exits 1 so a script
# step records FAIL instead of dying.
$script:StHandlerExitAllowList = @('challenge-probe=3', 'ime-en=1', 'key=1', 'keys=1', 'paste=1', 'paste-file=1', 'shots-cleanup=5', 'type=1')
$script:StEntryExitAllowList = @('<script>=2', 'fn:Invoke-ReplayLog=4', 'fn:Invoke-ScriptBatch=5')

# '$script:' targets are keyed without the dollar (script:CdpPort), because the AST's left extent
# keeps the qualifier and dropping the sigil here is what makes the two sides comparable.
$script:StCommandToken = Get-CharCodeWord @(0x4C, 0x6F, 0x67, 0x2D, 0x41, 0x63, 0x74, 0x69, 0x6F, 0x6E)
$script:StCommandOwners = @(
  'fn:Invoke-Handler-challenge-probe=8',
  'fn:Invoke-Handler-chrome-a11y=1',
  'fn:Invoke-Handler-chrome-debug-off=1',
  'fn:Invoke-Handler-chrome-menu-read=1',
  'fn:Invoke-Handler-click=1',
  'fn:Invoke-Handler-copy-file=1',
  'fn:Invoke-Handler-dblclick=1',
  'fn:Invoke-Handler-dialog-cancel=1',
  'fn:Invoke-Handler-drag=1',
  'fn:Invoke-Handler-drag-to=1',
  'fn:Invoke-Handler-find-click=1',
  'fn:Invoke-Handler-focus=1',
  'fn:Invoke-Handler-hover=1',
  'fn:Invoke-Handler-imgclick=1',
  'fn:Invoke-Handler-keys=1',
  # CU-OPS package C: `key` names the command when it logs its one gesture receipt.
  'fn:Invoke-Handler-key=1',
  'fn:Invoke-Handler-menu-pick=1',
  'fn:Invoke-Handler-move=1',
  'fn:Invoke-Handler-open-and-pick=2',
  'fn:Invoke-Handler-paste=2',
  'fn:Invoke-Handler-paste-file=2',
  'fn:Invoke-Handler-press-down=2',
  # CU-OPS package A: proc-start logs its start, proc-kill logs only a real --go termination.
  'fn:Invoke-Handler-proc-kill=1',
  'fn:Invoke-Handler-proc-start=1',
  'fn:Invoke-Handler-rclick=1',
  'fn:Invoke-Handler-relclick=1',
  'fn:Invoke-Handler-shots-cleanup=1',
  'fn:Invoke-Handler-type=1',
  'fn:Invoke-Handler-type-in=1',
  'fn:Invoke-Handler-uia-do=1',
  'fn:Invoke-Handler-wheel=1',
  'fn:Invoke-Handler-win-close=1',
  'fn:Invoke-Handler-win-max=1',
  'fn:Invoke-Handler-win-min=1',
  'fn:Invoke-Handler-win-move=1',
  'fn:Invoke-Handler-win-resize=1',
  'fn:Invoke-Handler-win-restore=1',
  'fn:Close-PressHold=1',
  'fn:Invoke-Handler-chrome-click=1',
  'fn:Invoke-Handler-uia-settext=1',
  'fn:Invoke-PressWatchdog=1',
  'fn:Invoke-ScriptBatch=4',
  'fn:Invoke-UiaSettextByPath=1',
  'fn:Release-Press=1',
  'fn:Trim-ShotDir=1'
)
# The ten mentions that are not calls: the definition, comments, probes and function-table
# handles, plus the two CU-REL-04 wheel-probe source-rewrite lines. Each has its own anchor.
# A-08 changes the shape of the stubs; when it does, this table moves with it.
$script:StCommandExclusions = @(
  '([string[]]$restArgs, [string]$target, [string]$CmdName)',
  'challenge-probe | pid=N',
  '($ccBody.Contains(''Invoke-HitWindowCheck',
  '$dgLaReal = ${',
  'param($la, $detail, $cn)',
  '} = $dgLaReal',
  'dispatch switch stays a dispatch',
  'v1.5.2 WP-2 (audit R-03, HIGH)',
  'wheelProbeText = ',
  'New = ''Invoke-WheelProbeLog '
)
# '@LA@' stands for the audited command; the gate substitutes it from the assembled token, so the
# registration never contains the word the registration is about.
$script:StFunctionScopeRefs = @(
  '@LA@=3',
  'Find-OcrHitsScaled=7',
  'Format-OcclusionCovering=3',
  'Get-ExpectChangeBaseline=3',
  'Get-OcclusionVerdict=6',
  'Get-PasteReceipt=3',
  'Get-PasteReceiptOcclusionMax=4',
  'Get-SamePidWindowsAbove=6',
  'Invoke-Expectation=6',
  'Invoke-HitWindowCheck=5',
  'Resolve-Target=3'
)
# All load-time assignments, self-registration included: A-03 added six statements to the baseline
# count of 54, and the five tables above are the seventh through eleventh. A card that introduces
# load-time state adds its own line here in the same commit.
$script:StLoadTimeNames = @(
  'ActionLog=1',
  'ErrorActionPreference=1',
  'exitReleaseReceipt=1',
  'script:DpiMode=3',
  'MOUSE_LDOWN=1',
  'MOUSE_LUP=1',
  'MOUSE_RDOWN=1',
  'MOUSE_RUP=1',
  'MOUSE_WHEEL=1',
  'MOUSE_HWHEEL=1',
  'OTHER:[Console]::OutputEncoding=1',
  'OutDir=1',
  'actJson=1',
  'envDupes=1',
  'envRawNames=1',
  'needTrustNote=1',
  'pressWarn=1',
  'produced=3',
  'Rest=3',
  'script:ActivationLine=1',
  'script:ActivationNotice=1',
  'script:AsTaskM=1',
  'script:CallLease=2',
  'script:CdpPort=1',
  # CU-OPS package G (v4.6.1): the pure-format allowlist that decides whether a clipboard
  # can be put back. Load-time state, so it is registered here by name in the same write.
  'script:ClipboardPureFormats=1',
  'script:DeclaredCheckTotal=1',
  'script:DumpPath=2',
  'script:EnvDedupError=2',
  'script:EnvDedupRemoved=2',
  'script:InvocationErrorCategory=3',
  'script:InvocationExitCode=3',
  'script:InvocationResult=3',
  'script:Json=2',
  'script:JsonSchemaVersion=1',
  'script:NoAutoTrim=1',
  'script:OcrCapNoteShown=1',
  'script:OcrEngine=1',
  'script:OcrLang=2',
  'script:OcrTried=1',
  'script:PressId=1',
  'script:PressSeq=1',
  'script:PressTopLevel=1',
  # CU-OPS-COMPLETE-20261026-01: load-time tables added by packages A/B/C - the mouse button
  # and modifier maps plus the receipt slot, the protected-process name list and the key map.
  'script:KeyVk=1',
  'script:LastMouseReceipt=1',
  'script:ModifierVk=1',
  'script:MouseButtonNames=1',
  'script:ProcSystemNames=1',
  'script:ProcNameCache=1',
  'script:ResolveNote=1',
  'script:StCommandExclusions=1',
  'script:StCommandNameArgs=1',
  'script:StFamilyCounts=1',
  'script:StFamilyCheckCounts=1',
  'script:StFamilyExports=1',
  'script:StFamilyFragments=1',
  'script:StFamilyLifted=1',
  'script:StFamilyOrder=1',
  'script:StHandlerExitAllowList=1',
  'script:StEntryExitAllowList=1',
  'script:StPathReadOwners=1',
  'script:ToolEntryPath=1',
  'script:ToolVersion=1',
  'script:ToolRootPath=1',
  'script:StCmdVarUses=1',
  'script:StCtxKeys=1',
  'script:StHandlerFlagCases=1',
  'script:StHandlerInlineCases=1',
  'script:StHandlerUnwrapped=1',
  'script:StHandlerGroups=1',
  'script:StHandlerFiles=1',
  'script:StCommandOwners=1',
  'script:StCommandToken=1',
  'script:StFileMap=1',
  'script:StFileMap[$sfName]=1',
  'script:StFunctionScopeRefs=1',
  'script:StLoadTimeInits=1',
  'script:StLoadTimeNames=1',
  'script:StFamilyFragments[''docs-contract'']=1',
  'script:StSourceFiles=1',
  'script:StSourceMode=1',
  'script:StSourceSpans=1',
  'script:UiaActionAllowRe=1',
  'skipD=3',
  'skipNext=3',
  'tmp=1',
  'tmpD=1'
)

# '$Cmd' travels by argument now, so the shape of that argument is what has to be accounted for:
# fifty-three calls take the name from the dispatcher parameter, four from a formal the helper
# received, one from the watchdog's lower-case formal. 'ABSENT' has no row here, so a call that
# still reads caller scope fails the lint by name instead of writing a column that only looks
# like a command.
$script:StCommandNameArgs = @(
  '3|$Cmd=54',
  '3|$CmdName=4',
  '3|$cmdName=1'
)

# Every use of the dispatcher's own command variable, by owner, with the entry parameter block
# counted as the owner of the top-level uses. A row here is a licence that the lint re-checks
# against the declaration site: the dispatcher and the script runner may use it because they
# DECLARE it, and a new row only appears when somebody starts reading a scope they do not own.
$script:StCmdVarUses = @(
  '<script>=15',
  'fn:Invoke-DesktopCommand=5',
  'fn:Get-HandlerName=1',
  'fn:Get-CommandCodeRanges=3',
  'fn:Get-CommandCodeText=1',
  'fn:Invoke-Handler-chrome-click=1',
  'fn:Invoke-Handler-uia-settext=2',
  'fn:Invoke-ScriptBatch=4',
  'fn:Invoke-Handler-challenge-probe=8',
  'fn:Invoke-Handler-chrome-a11y=1',
  'fn:Invoke-Handler-chrome-debug-off=1',
  'fn:Invoke-Handler-chrome-menu-read=1',
  'fn:Invoke-Handler-click=1',
  'fn:Invoke-Handler-copy-file=1',
  'fn:Invoke-Handler-dblclick=1',
  'fn:Invoke-Handler-dialog-cancel=1',
  'fn:Invoke-Handler-drag=1',
  'fn:Invoke-Handler-drag-to=3',
  'fn:Invoke-Handler-find-click=1',
  'fn:Invoke-Handler-focus=1',
  'fn:Invoke-Handler-hover=1',
  'fn:Invoke-Handler-imgclick=1',
  'fn:Invoke-Handler-keys=1',
  'fn:Invoke-Handler-key=1',
  'fn:Invoke-Handler-menu-pick=1',
  'fn:Invoke-Handler-move=1',
  'fn:Invoke-Handler-open-and-pick=2',
  'fn:Invoke-Handler-paste=2',
  'fn:Invoke-Handler-paste-file=2',
  'fn:Invoke-Handler-press-down=5',
  'fn:Invoke-Handler-press-up=2',
  'fn:Invoke-Handler-proc-kill=1',
  'fn:Invoke-Handler-proc-start=1',
  'fn:Invoke-Handler-rclick=1',
  'fn:Invoke-Handler-relclick=1',
  'fn:Invoke-Handler-shots-cleanup=1',
  'fn:Invoke-Handler-type=1',
  'fn:Invoke-Handler-type-in=1',
  'fn:Invoke-Handler-uia-do=1',
  'fn:Invoke-Handler-wheel=1',
  'fn:Invoke-Handler-win-close=1',
  'fn:Invoke-Handler-win-max=1',
  'fn:Invoke-Handler-win-min=1',
  'fn:Invoke-Handler-win-move=1',
  'fn:Invoke-Handler-win-resize=1',
  'fn:Invoke-Handler-win-restore=1'
)
# Emit stdout as UTF-8 (no BOM) so CJK window titles survive being piped to
# other processes when invoked via powershell -File. Wrapped in try/catch
# because hosts without a real console reject the setter.
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class DT {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr ctx);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr GetProcessWindowStation();
  [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr GetThreadDesktop(uint threadId);
  // UOI_NAME: the size probe always reports the Unicode byte count, so a default (ANSI) binding
  // allocates from needed yet writes only the ANSI bytes, and the caller decodes with
  // PtrToStringUni (lib/caller-runtime.ps1:142), which looks for its terminating NUL with no bound.
  // Measured 2026-10-22, both engines: needed=16, neededAfter=8 under the A binding, and that
  // unbounded scan passed the end of the block the call owned on 62/200 trips on 5.1 and 73/200 on
  // pwsh 7.6.7 (worst single overshoot 8 and 62 bytes) - an OUT-OF-BOUNDS READ, undefined behaviour
  // whose contents and distance are set by whatever the heap holds at that moment, and there is no
  // bound to quote: three same-revision runs of the production read path (lib/caller-runtime.ps1
  // Get-DtxCallDesktopName, 40 trips per run, CharSet removed) peaked at 39/39/40 units on 5.1 and
  // 46/64/118 on pwsh 7.6.7 - 118 units is 222 bytes read past the 16 the call owned. The Unicode
  // binding gave 0/200. Reading the tail back as UTF-16 pairs is mojoke and gives a different
  // desktop-<sha16> state key per run, so this binding must stay Unicode: it writes
  // chars*2 + 2 == needed, i.e. exactly one UTF-16 terminating NUL. Pairing is the invariant - W with
  // PtrToStringAnsi reads 1 char, A with PtrToStringAnsi works only until a code page that is not
  // ASCII-safe is involved. Guarded by the real-path gate in gate-meta, and that gate must never be
  // softened into a length or shape assertion: the overshoot only shows across repeated trips.
  [DllImport("user32.dll", SetLastError = true, CharSet=CharSet.Unicode)] public static extern bool GetUserObjectInformation(IntPtr hObj, int index, IntPtr info, int length, out int needed);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attr, out RECT val, int cb);
  [DllImport("user32.dll")] public static extern IntPtr GetKeyboardLayout(uint thread);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool repaint);
  [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
  [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint gw);
  [DllImport("user32.dll")] public static extern int SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("imm32.dll")] public static extern IntPtr ImmGetDefaultIMEWnd(IntPtr h);
  [DllImport("user32.dll", SetLastError = true)] public static extern uint SendInput(uint n, INPUT[] p, int cb);
  [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Explicit)] public struct INPUTUNION { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }
  [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public INPUTUNION u; }
  // CU-REL-03: one wheel event per call, with the exact SendInput count returned to PowerShell.
  public static uint SendWheelInput(int delta, uint flags) {
    if (flags != 0x0800 && flags != 0x1000) { throw new ArgumentOutOfRangeException("flags", "wheel input accepts MOUSE_WHEEL or MOUSE_HWHEEL only"); }
    INPUT[] inputs = new INPUT[1];
    inputs[0].type = 0;
    inputs[0].u.mi = new MOUSEINPUT { dx = 0, dy = 0, mouseData = unchecked((uint)delta), dwFlags = flags, time = 0, dwExtraInfo = IntPtr.Zero };
    return SendInput(1, inputs, Marshal.SizeOf(typeof(INPUT)));
  }
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  public struct RECT { public int Left, Top, Right, Bottom; }
  public struct POINT { public int X, Y; }
  // CU-OPS-COMPLETE-20261026-01: one mouse BUTTON event per call with the exact inserted count
  // returned. mouse_event() returns void, so a caller cannot tell whether the system took the
  // event; SendInput returns how many of the requested events it inserted, which is the receipt
  // the modifiers/buttons work needs. mouseData carries the XBUTTON id (1 = back, 2 = forward).
  public static uint SendMouseButtonInput(uint flag, uint data) {
    uint[] allowed = new uint[] { 0x0002u, 0x0004u, 0x0008u, 0x0010u, 0x0020u, 0x0040u, 0x0080u, 0x0100u };
    bool ok = false;
    for (int k = 0; k < allowed.Length; k++) { if (allowed[k] == flag) { ok = true; } }
    if (!ok) { throw new ArgumentOutOfRangeException("flag", "mouse button input accepts the eight button flags only"); }
    INPUT[] inputs = new INPUT[1];
    inputs[0].type = 0;
    inputs[0].u.mi = new MOUSEINPUT { dx = 0, dy = 0, mouseData = data, dwFlags = flag, time = 0, dwExtraInfo = IntPtr.Zero };
    return SendInput(1, inputs, Marshal.SizeOf(typeof(INPUT)));
  }
  // CU-OPS: one keyboard event (keydown unless up) with its exact inserted count. SendInput does
  // NOT reset a key state that was already held, so the caller must check before pressing and
  // release only what it pressed itself.
  public static uint SendKeyInput(int vk, bool up, bool extended) {
    if (vk <= 0 || vk > 0xFF) { throw new ArgumentOutOfRangeException("vk", "virtual key must be 1..255"); }
    uint flags = (up ? 0x0002u : 0u) | (extended ? 0x0001u : 0u);
    INPUT[] inputs = new INPUT[1];
    inputs[0].type = 1;
    inputs[0].u.ki = new KEYBDINPUT { wVk = (ushort)vk, wScan = 0, dwFlags = flags, time = 0, dwExtraInfo = IntPtr.Zero };
    return SendInput(1, inputs, Marshal.SizeOf(typeof(INPUT)));
  }
  public static int IsVkDown(int vk) { return (GetAsyncKeyState(vk) & 0x8000); }
  public static string Text(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
  // Types text via SendInput with KEYEVENTF_UNICODE: each char arrives as a
  // VK_PACKET keystroke that the system converts straight to WM_CHAR, so the
  // IME never sees it (no candidate window, works for CJK and ASCII alike).
  // SendInput is atomic (one call for the whole string). Returns "" on success,
  // otherwise a short description of how much was actually delivered.
  public static string SendUnicodeText(string text) {
    if (string.IsNullOrEmpty(text)) { return ""; }
    INPUT[] inputs = new INPUT[text.Length * 2];
    int i = 0;
    foreach (char c in text) {
      inputs[i].type = 1; inputs[i].u.ki.wVk = 0; inputs[i].u.ki.wScan = c; inputs[i].u.ki.dwFlags = 0x0004; i++;          // KEYEVENTF_UNICODE
      inputs[i].type = 1; inputs[i].u.ki.wVk = 0; inputs[i].u.ki.wScan = c; inputs[i].u.ki.dwFlags = 0x0004 | 0x0002; i++; // + KEYEVENTF_KEYUP
    }
    uint sent = SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(INPUT)));
    if (sent != (uint)inputs.Length) {
      int err = Marshal.GetLastWin32Error();
      return "SendInput delivered " + sent + " of " + inputs.Length + " events" + (err != 0 ? " (win32 error " + err + ")" : "");
    }
    return "";
  }
  // v2.0.1 (P-3) watchdog 1, deliberately implemented HERE rather than in PowerShell:
  // a scriptblock marshalled as a System.Threading.Timer callback kills the process -
  // measured 2026-10-01 in the first live round, where press-down died with exit code 2
  // and printed nothing (same crash in both the "writes a script-scope variable" variant
  // and the "touches only its own state object" variant). A dead process cannot release the
  // button, so the one outcome this feature must never produce was exactly what the
  // "convenient" implementation caused. A native timer needs no runspace.
  [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int v);
  static System.Threading.Timer holdTimer;
  public static volatile int HoldReleased = 0;
  public static void ArmLeftUpHold(int ms) {
    if (holdTimer != null) { holdTimer.Dispose(); }
    HoldReleased = 0;
    holdTimer = new System.Threading.Timer(deleg => {
      try {
        if ((GetAsyncKeyState(0x01) & 0x8000) != 0) { mouse_event(0x0004, 0, 0, 0, IntPtr.Zero); }
        HoldReleased = 1;
      } catch { }
    }, null, ms, System.Threading.Timeout.Infinite);
  }
  public static void CancelLeftUpHold() { if (holdTimer != null) { holdTimer.Dispose(); holdTimer = null; } }
  // v4.2.2 (F2, entry normalization - machine owner authorized 2026-10-10): read the RAW
  // environment block. [Environment]::GetEnvironmentVariables() hands back a case-INSENSITIVE
  // table, so a block that carries both 'http_proxy' and 'HTTP_PROXY' looks perfectly normal
  // through it - while that same twin makes PS 5.1's Start-Process throw as it copies the block
  // into its own case-insensitive dictionary ("Item has already been added", measured here
  // 2026-10-10: it killed the offline gate before its summary line). The duplicate is visible
  // ONLY at the raw level, which is why the normalizer reads the block and not the managed view.
  [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)] public static extern IntPtr GetEnvironmentStringsW();
  [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)] public static extern bool FreeEnvironmentStringsW(IntPtr p);
  public static string[] RawEnvNames() {
    IntPtr p = GetEnvironmentStringsW();
    if (p == IntPtr.Zero) { return new string[0]; }
    System.Collections.Generic.List<string> names = new System.Collections.Generic.List<string>();
    try {
      int off = 0;
      while (true) {
        string s = Marshal.PtrToStringUni((IntPtr)((long)p + (long)off * 2L));
        if (s == null || s.Length == 0) { break; }        // the block ends with an empty string
        int eq = s.IndexOf('=');
        if (eq > 0) { names.Add(s.Substring(0, eq)); }    // eq == 0 is the '=C:=...' drive-cwd form
        off += s.Length + 1;
      }
    } finally { FreeEnvironmentStringsW(p); }
    return names.ToArray();
  }
}
"@

# CU-OPS package F (v4.6.0): the template matcher's inner loop, compiled once.
# Why compiled: the same comparison written in PowerShell costs ~6ms per position
# (measured 2026-10-27 on this tree: 3326 positions in 20s), so the 3,000,000-pixel
# bound the command advertises could never be met. The semantics are deliberately
# the same in both places: 32bpp BGRA, alpha-0 template pixels are skipped, and the
# per-channel tolerance is inclusive. It returns flattened (x,y) pairs and reports
# the positions actually tested, so the caller's numbers stay honest.
Add-Type @"
using System;
using System.Collections.Generic;
using System.Diagnostics;
public class TPL {
  public static long[] Find(byte[] hay, int hs, int hw, int hh, byte[] need, int ns, int nw, int nh, int tol, int maxMs, out long positions, out bool overBudget) {
    List<long> hits = new List<long>();
    positions = 0;
    overBudget = false;
    Stopwatch sw = Stopwatch.StartNew();
    int maxX = hw - nw;
    int maxY = hh - nh;
    if (maxX < 0 || maxY < 0) { return hits.ToArray(); }
    for (int y = 0; y <= maxY; y++) {
      for (int x = 0; x <= maxX; x++) {
        positions++;
        if ((positions & 0xFFF) == 0 && sw.ElapsedMilliseconds > maxMs) { overBudget = true; return hits.ToArray(); }
        bool ok = true;
        for (int ty = 0; ty < nh && ok; ty++) {
          int nrow = ty * ns;
          int hrow = (y + ty) * hs;
          for (int tx = 0; tx < nw; tx++) {
            int no = nrow + tx * 4;
            if (need[no + 3] == 0) { continue; }
            int ho = hrow + (x + tx) * 4;
            int db = hay[ho] - need[no];
            if (db < 0) { db = -db; }
            if (db > tol) { ok = false; break; }
            int dg = hay[ho + 1] - need[no + 1];
            if (dg < 0) { dg = -dg; }
            if (dg > tol) { ok = false; break; }
            int dr = hay[ho + 2] - need[no + 2];
            if (dr < 0) { dr = -dr; }
            if (dr > tol) { ok = false; break; }
          }
        }
        if (ok) { hits.Add(((long)x << 32) | (long)(uint)y); }
      }
    }
    return hits.ToArray();
  }
}
"@

# Must run before any coordinate is read, otherwise Windows virtualizes every
# value by the monitor scale factor and clicks land in the wrong place.
# Preferred mode is Per-Monitor V2 (Windows 10 1703+, user32 context value -4):
# with several monitors at DIFFERENT scale factors, the legacy System-aware
# mode below is still virtualized on secondary monitors, so screenshots and
# clicks there can be offset. Older builds throw EntryPointNotFoundException
# and we fall back to SetProcessDPIAware() (System aware).
# $DpiMode is reported by the `dpi` command for troubleshooting.
$script:DpiMode = 'unaware'
try {
  if ([DT]::SetProcessDpiAwarenessContext([IntPtr](-4))) { $script:DpiMode = 'per-monitor-v2' }
} catch { }
if ($script:DpiMode -eq 'unaware') {
  try {
    if ([DT]::SetProcessDPIAware()) { $script:DpiMode = 'system' }
  } catch { }
}

$MOUSE_LDOWN = 0x0002
$MOUSE_LUP = 0x0004
$MOUSE_RDOWN = 0x0008
$MOUSE_RUP = 0x0010
$MOUSE_WHEEL = 0x0800
$MOUSE_HWHEEL = 0x1000

$OutDir = Join-Path $PSScriptRoot 'shots'
$ActionLog = Join-Path $OutDir 'actions.log'

function Ensure-OutDir {
  if (-not (Test-Path $OutDir)) { [void](New-Item -ItemType Directory -Force -Path $OutDir) }
}

# Audit trail for act/text commands: one line per executed action, appended
# right before the action runs. Format:
#   <UTC timestamp> UTC | <command> | <raw args> | <target>
# Args are quoted (single quotes, '' escape) when they contain spaces so a
# later `replay` can tokenize them back unambiguously. Never logs clipboard
# contents or the body of pasted files - only file paths.
function Quote-LogArg([string]$s) {
  if ($s -match '\s') { return "'" + ($s -replace "'", "''") + "'" }
  return $s
}

# Audit-log redaction (audit 2026-09-29 #4, closed v1.4.1): typed payloads of
# type/type-in/keys and the --guard-text/--guard-region needles are secrets-in-
# waiting - a password typed via `type` used to land in actions.log verbatim.
# Sensitive tokens are stored as "<redacted:Nchars>" unless --log-payload is
# passed explicitly. File paths, coordinates and window targets stay verbatim:
# they ARE the audit trail.
function Get-RedactedLogArgs([string[]]$rest, [string[]]$sensitive, [bool]$logPayload) {
  if ($logPayload) { return @($rest) }
  $set = @{}
  foreach ($s in $sensitive) { if ($s) { $set[$s] = $true } }
  $out = New-Object System.Collections.ArrayList
  $i = 0
  while ($i -lt $rest.Count) {
    $t = $rest[$i]
    if ($t -eq '--guard-text') {
      [void]$out.Add($t); $i++
      if ($i -lt $rest.Count) { [void]$out.Add('<redacted:' + $rest[$i].Length + 'chars>') }
    } elseif ($t -eq '--expect' -or $t -eq '--expect-gone') {
      # expect needles are search intents too - same redaction class as guards
      [void]$out.Add($t); $i++
      if ($i -lt $rest.Count) { [void]$out.Add('<redacted:' + $rest[$i].Length + 'chars>') }
    } elseif ($t -eq '--guard-region') {
      [void]$out.Add($t); $i++
      if ($i -lt $rest.Count) {
        # keep the coordinates, hide only the "=needle" tail
        $spec = $rest[$i]
        $eq = $spec.IndexOf('=')
        if ($eq -ge 0) { [void]$out.Add($spec.Substring(0, $eq + 1) + '<redacted:' + ($spec.Length - $eq - 1) + 'chars>') }
        else { [void]$out.Add($spec) }
      }
    } elseif ($set.ContainsKey($t)) {
      [void]$out.Add('<redacted:' + $t.Length + 'chars>')
    } else {
      [void]$out.Add($t)
    }
    $i++
  }
  return @($out)
}

# v1.5.2 WP-7 (audit R-14): shots/ grows without bound (100MB / 213 PNG measured
# over three days) while actions.log has rotated since v1.4.1. This is the PLAN
# half of the cleanup, kept pure so the selection is a unit test and not a
# desktop run: newest N captures stay, everything older goes, and a .map.txt
# sidecar ALWAYS travels with its own image (a sidecar whose image stayed, or
# whose image already left, is either useless or actively misleading - imgclick
# refuses a missing sidecar by design and must never be pointed at a moved one).
# Nothing here deletes: the caller moves files, and moving is reversible.
function Get-ShotCleanupPlan($files, [int]$keep) {
  $list = @($files)
  if ($keep -lt 0) { $keep = 0 }
  $byTime = @($list | Where-Object { $_.Name -notlike '*.map.txt' } | Sort-Object -Property LastWriteTime -Descending)
  $stayNames = @($byTime | Select-Object -First $keep | ForEach-Object { $_.Name })   # selection-not-display: the plan echo states keep=/move=/bytes=
  $keepCol = New-Object System.Collections.ArrayList
  $moveCol = New-Object System.Collections.ArrayList
  $boundPairs = New-Object System.Collections.ArrayList
  foreach ($f in $byTime) {
    $side = "$($f.Name).map.txt"
    $sideObj = @($list | Where-Object { $_.Name -ceq $side })
    if (@($sideObj).Count -gt 0) { [void]$boundPairs.Add(@($f.Name, $side)) }
  }
  foreach ($f in $list) {
    if ($f.Name -like '*.map.txt') {
      $owner = $f.Name -replace '\.map\.txt$', ''
      $ownerStayed = @($stayNames | Where-Object { $_ -ceq $owner }).Count -gt 0
      if (-not $ownerStayed) { [void]$moveCol.Add($f) } else { [void]$keepCol.Add($f) }
    } elseif (@($stayNames | Where-Object { $_ -ceq $f.Name }).Count -gt 0) {
      [void]$keepCol.Add($f)
    } else {
      [void]$moveCol.Add($f)
    }
  }
  $bytes = 0L
  foreach ($m in $moveCol) { $bytes += [long]$m.Length }
  return @{ Keep = @($keepCol); Move = @($moveCol); Bytes = $bytes; KeptNames = @($stayNames); SidecarPairs = @($boundPairs) }
}

# v2.5.2/v2.5.3: where shots-cleanup --go sends files. Precedence: explicit
# --quarantine > process env DTX_QUARANTINE > User-scope registry > Machine-scope
# registry > $null (the CALLER refuses with exit 2 and both remedy names, echoing no
# path). The two registry tiers exist because a process environment block is a STARTUP
# SNAPSHOT: long-lived hosts and everything they spawn keep the env they were born
# with, so a User-level variable written later never reaches $env: there - the v2.5.2
# env-only chain made --go refuse exactly on the machine that set the variable. The
# probes are parameters defaulting to the live sources, so every precedence tier is
# unit-testable with injected values and the real registry is never touched by a test;
# the live all-empty refusal is verified manually (it would require deleting the User
# value, which a selftest must never do).
function Resolve-ShotsCleanupQuarantine([string]$Explicit, [string]$EnvProbe = $env:DTX_QUARANTINE, [string]$UserProbe = [Environment]::GetEnvironmentVariable('DTX_QUARANTINE', 'User'), [string]$MachineProbe = [Environment]::GetEnvironmentVariable('DTX_QUARANTINE', 'Machine')) {
  if (-not [string]::IsNullOrWhiteSpace("$Explicit")) { return @{ Dir = "$Explicit"; Source = 'flag' } }
  if (-not [string]::IsNullOrWhiteSpace("$EnvProbe")) { return @{ Dir = "$EnvProbe"; Source = 'env' } }
  if (-not [string]::IsNullOrWhiteSpace("$UserProbe")) { return @{ Dir = "$UserProbe"; Source = 'user' } }
  if (-not [string]::IsNullOrWhiteSpace("$MachineProbe")) { return @{ Dir = "$MachineProbe"; Source = 'machine' } }
  return @{ Dir = $null; Source = $null }
}

# v2.6.0: the move-and-record body, extracted from the 'shots-cleanup --go' branch so the
# automatic trim and the manual command share ONE implementation. Two copies of a loop
# that touches a user's files is how a fix lands in one path and silently not the other.
# Never deletes: each file is moved within the volume (so CreationTime survives) and gets
# a MANIFEST line with its SHA256, which is what makes an automatic action undoable.
# TB-3 (v4.4.2 fold): the MANIFEST line is written for EACH FILE, at the moment that file is
# done, instead of being buffered and flushed once after the loop. The buffered shape made the
# evidence depend on the loop reaching its end: with a folder over its bound, the rows for the files
# already moved were only in memory, so anything that ended the run early (or a host that died)
# left moved files with no record at all - the exact state this tool exists to avoid. A failed
# move is now recorded on disk as a FAILED row too, because a returned array is not evidence.
# And if the row itself cannot be written, the loop STOPS and says so: moving another of the
# user's files without a record is worse than leaving the folder over its bound, so Unrecorded
# names the rows that did not land and every caller reports it instead of a clean summary.
function Move-ShotsToQuarantine($moveItems, [string]$quar, [string]$prefix, [string]$heading) {
  $items = @($moveItems)
  if (-not (Test-Path -LiteralPath $quar)) { throw "quarantine folder does not exist: $quar" }
  $dest = Join-Path $quar ($prefix + (Get-Date -Format 'yyyyMMddTHHmmss'))
  [void](New-Item -ItemType Directory -Force -Path $dest)
  $manifest = Join-Path $quar 'MANIFEST.md'
  $failTxt = New-Object System.Collections.ArrayList
  $unrecordedTxt = New-Object System.Collections.ArrayList
  $movedN = 0; $failN = 0; $rowsWritten = 0
  foreach ($m in $items) {
    $target = Join-Path $dest $m.Name
    $mEntry = $null
    $fileMoved = $false
    try {
      $sha = (Get-FileHash -LiteralPath $m.FullName -Algorithm SHA256).Hash
      # v3.1.0 (P-05): build the manifest line BEFORE the move. The content descriptor opens the
      # ORIGINAL path to read a sidecar's first line; after Move-Item that path is empty and the
      # read fails inside its own catch{}, so every .map.txt row has been printing
      # "first line: " (nothing) since the mover existed. One producer, so this also fixes the
      # automatic trim, not just shots-cleanup --go.
      $mEntry = Get-QuarantineManifestEntry $m.FullName $target $sha $m
      Move-Item -LiteralPath $m.FullName -Destination $target -Force
      $fileMoved = $true
      $movedN++
    } catch {
      $failN++
      [void]$failTxt.Add("  FAILED to move $($m.Name): $($_.Exception.Message)")
      $mEntry = '- FAILED (not moved) | original: ' + [string]$m.FullName + ' | target: ' + [string]$target +
        ' | reason: ' + (($_.Exception.Message -replace '\s+', ' '))
    }
    # TB-3: the row for THIS file reaches the disk before the next file is touched. The heading (and
    # the file's own title line, on the very first run against this quarantine) ride in front of the
    # first row only - counted off what was actually written, so a row whose write failed still owns
    # the heading on the next attempt instead of losing it.
    $mPre = ''
    if ($rowsWritten -eq 0) {
      if (-not (Test-Path -LiteralPath $manifest)) { $mPre = "# Cleanup manifest - $quar" + "`r`n`r`n" }
      $mPre = $mPre + $heading + "`r`n`r`n"
    }
    $mWritten = $false
    $mWriteErr = ''
    try {
      [System.IO.File]::AppendAllText($manifest, $mPre + $mEntry + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
      $mWritten = $true
    } catch { $mWriteErr = (($_.Exception.Message -replace '\s+', ' ')) }
    if ($mWritten) { $rowsWritten++ ; continue }
    if ($fileMoved) { [void]$unrecordedTxt.Add($mEntry) }
    [void]$failTxt.Add('  FAILED to record ' + [string]$m.Name + ' in ' + [string]$manifest + ': ' + $mWriteErr + ' - the run stops here, no further file is moved without its row')
    break
  }
  # Nothing is written to the success stream: the manual command prints these, and the
  # capture path appends them to its own echo array. A function that returns a value must
  # not also Write-Output, or the caller's array silently gains lines it never asked for.
  # Unrecorded is a THIRD state on purpose and is never folded into Failed: Failed means the file
  # did not move, Unrecorded means it did move but its MANIFEST row could not be written.
  return @{ Moved = $movedN; Failed = $failN; Dest = $dest; Quar = $quar; Manifest = $manifest; Failures = @($failTxt); Unrecorded = @($unrecordedTxt) }
}

# v2.6.0: policy for the automatic trim, as a PURE function so both knobs are unit-pinned
# without moving a single file. DTX_SHOT_AUTOTRIM=0|off|false turns the mechanism off;
# DTX_SHOT_KEEP=<n> sets how many newest captures stay. Defaults match the manual
# command's own --keep default so there is exactly one number to remember.
# NOTE on the env tiers: the default is ON, and the variables only ever turn it DOWN or
# off, so the "resident host cannot see a later-set variable" trap (v2.5.3) fails SAFE
# here - an unapplied setting keeps trimming at the default rather than stopping.
function Get-ShotAutoTrimPolicy([string]$switchProbe = $env:DTX_SHOT_AUTOTRIM, [string]$keepProbe = $env:DTX_SHOT_KEEP, [int]$defaultKeep = 100) {
  $on = $true
  $s = "$switchProbe".Trim().ToLowerInvariant()
  if ($s -eq '0' -or $s -eq 'off' -or $s -eq 'false' -or $s -eq 'no') { $on = $false }
  $keep = $defaultKeep
  $k = "$keepProbe".Trim()
  if ($k -ne '') {
    $parsed = 0
    if ([int]::TryParse($k, [ref]$parsed)) { if ($parsed -lt 0) { $parsed = 0 }; $keep = $parsed }
  }
  return @{ Enabled = $on; Keep = $keep }
}

# v2.6.0: bound the capture folder WITHOUT being asked. `shots-cleanup` has existed since
# v1.5.2 and nobody ever ran it: the folder reached 455 PNGs / 132 MB by 2026-10-03. The
# audit log has self-archived on size since v1.4.1 (Invoke-LogRotation), so the pattern is
# already in this file - captures now follow it.
# Runs after a capture is written, so the file the caller just asked for is inside the
# newest $keep and cannot be swept. Skips entirely (no side effect, one line of output)
# when nothing is over the bound, when the quarantine is not configured, or during
# selftest - a live run must never have its own fixtures moved out from under it.
# $Dir is a parameter so the whole path is testable against a temp folder; -Keep and
# -QuarOverride let a test pin the policy and the target WITHOUT touching the registry or
# the process env, so the e2e exercises the real move code on a throwaway directory.
function Trim-ShotDir([string]$Dir = $OutDir, [string]$why = 'after-capture', [int]$Keep = -1, [string]$QuarOverride = '', [string]$CmdName) {
  if ($script:NoAutoTrim) { return $null }
  $pol = Get-ShotAutoTrimPolicy
  if ($Keep -ge 0) { $pol = @{ Enabled = $pol.Enabled; Keep = $Keep } }
  if (-not $pol.Enabled) { return $null }
  if (-not (Test-Path -LiteralPath $Dir)) { return $null }
  $all = @(Get-ChildItem -LiteralPath $Dir -File | Where-Object { $_.Name -like '*.png' -or $_.Name -like '*.jpg' -or $_.Name -like '*.map.txt' })
  $plan = Get-ShotCleanupPlan $all $pol.Keep
  if (@($plan.Move).Count -eq 0) { return $null }
  $q = Resolve-ShotsCleanupQuarantine $QuarOverride
  if (-not $q.Dir) {
    return @{ Moved = 0; Failed = 0; Unrecorded = @(); Skipped = 'no-target'; Note = ('auto-trim: skipped, no quarantine target for ' + @($plan.Move).Count + ' file(s) - pass --quarantine or set DTX_QUARANTINE (see ''help shots-cleanup'')') }
  }
  if (-not (Test-Path -LiteralPath $q.Dir)) {
    return @{ Moved = 0; Failed = 0; Unrecorded = @(); Skipped = 'missing-dir'; Note = ('auto-trim: skipped, the ' + $q.Source + '-scope quarantine folder does not exist') }
  }
  $heading = '## auto-trim v2.6.0 ' + (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm') + ' UTC (' + $why + ', keep newest ' + $pol.Keep + ', moved ' + @($plan.Move).Count + ')'
  $r = Move-ShotsToQuarantine $plan.Move $q.Dir 'shots_auto_' $heading
  $r.Skipped = $null
  $r.Keep = $pol.Keep
  $r.Note = ('auto-trim: moved ' + $r.Moved + ' capture file(s) to the quarantine folder (keep newest ' + $pol.Keep + ', ' + $why + ') - nothing was deleted')
  # TB-3: an automatic action runs on a machine nobody is watching, so the one failure mode that
  # silently costs the user their undo trail has to be in the sentence the user reads, not only in
  # the returned table.
  if (@($r.Unrecorded).Count -gt 0) {
    $r.Note = ($r.Note + ' - ' + @($r.Unrecorded).Count + ' MOVED FILE(S) HAVE NO MANIFEST ROW, the run stopped instead of moving more without a record')
  }
  Log-Action @('auto-trim', '--keep', "$($pol.Keep)", $why) "moved=$($r.Moved) failed=$($r.Failed) unrecorded=$(@($r.Unrecorded).Count) dest=$($r.Dest)" $CmdName
  return $r
}

# Manifest line for a quarantined file: original path, SHA256, size, times and a
# short content descriptor. Cross-project rule 12: deletion is replaced by an
# in-volume move that keeps CreationTime, with the evidence written down so the
# move can be undone by hand.
function Get-QuarantineManifestEntry([string]$origPath, [string]$movedPath, [string]$sha, [object]$item) {
  $kind = [System.IO.Path]::GetExtension($origPath).ToLowerInvariant()
  $desc = 'binary'
  if ($kind -eq '.map.txt' -or $origPath -like '*.map.txt') {
    $first = ''
    try { $first = (@(Get-Content -LiteralPath $origPath -TotalCount 1 -Encoding UTF8) -join '') } catch { }
    $desc = "map sidecar (first line: $first)"
    $kind = '.map.txt'
  } elseif ($kind -eq '.png') { $desc = 'screenshot' }
  return "- $($item.LastWriteTimeUtc.ToString('yyyy-MM-dd HH:mm:ss'))Z | moved: $movedPath | original: $origPath | sha256: $sha | bytes: $($item.Length) | created: $($item.CreationTimeUtc.ToString('yyyy-MM-dd HH:mm:ss'))Z | kind: $kind | $desc"
}

# actions.log rotation (audit 2026-09-29 #13, closed v1.4.1): the audit log grew
# without bound. When it passes $maxBytes it is moved aside to a timestamped
# actions_*.log archive and the newest $keep archives are retained.
function Invoke-LogRotation([string]$logPath, [long]$maxBytes, [int]$keep) {
  if (-not (Test-Path -LiteralPath $logPath)) { return $false }
  if ((Get-Item -LiteralPath $logPath).Length -lt $maxBytes) { return $false }
  $stamp = (Get-Date).ToString('yyyyMMddTHHmmss')
  $archive = Join-Path (Split-Path -Parent $logPath) ('actions_' + $stamp + '.log')
  Move-Item -LiteralPath $logPath -Destination $archive -Force
  $old = @(Get-ChildItem -LiteralPath (Split-Path -Parent $logPath) -Filter 'actions_*.log' | Sort-Object -Property Name -Descending)
  for ($k = $keep; $k -lt $old.Count; $k++) { Remove-Item -LiteralPath $old[$k].FullName -Force }
  return $true
}

function Log-Action([string[]]$restArgs, [string]$target, [string]$CmdName) {
  # The command name arrives as an argument. After the split the bodies live in files whose scope
  # chain no longer contains the dispatcher variable, and an empty audit column is the one failure
  # this file cannot see from its own output - so a missing name stops the command instead of
  # writing a line that looks like a run of nothing. No default value, on purpose.
  if ([string]$CmdName -eq '') { throw 'the command name must be passed as the third argument of the audited-command call - refusing to fill the audit column from caller scope' }
  Ensure-OutDir
  Invoke-LogRotation $ActionLog 524288 5 | Out-Null
  $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
  $line = "$ts UTC | $CmdName | " + (($restArgs | ForEach-Object { Quote-LogArg $_ }) -join ' ') + " | $target"
  [System.IO.File]::AppendAllText($ActionLog, "$line`r`n", (New-Object System.Text.UTF8Encoding($false)))
}

# v1.5.7: SAFE key enumeration for a hashtable.
# !! In PowerShell a dictionary KEY wins over the .NET PROPERTY of the same name:
# $h = @{}; $h['keys'] = 8017; then $h.Keys is the INTEGER 8017, NOT the key collection -
# and .Count still says 59, so nothing looks wrong. Any scan built on a hashtable whose
# keys are COMMAND NAMES therefore breaks the moment one of those commands is called
# 'keys'. This bit the v1.5.5 flag-reachability lint (its foreach ran once over an int, so
# the "every private flag is stripped, read and documented" check was VACUOUS for hover /
# drag / find-click while reporting green) and the help-coverage lint in this round.
# GetEnumerator() is not shadowed by keys, so it is the only honest way to enumerate.
$script:ProcNameCache = $null

# X-02 (Set-StrictMode): one reader for "this field may not be on this object".
# Under StrictMode -Version Latest, reading an absent property is a STATEMENT-TERMINATING error that
# $ErrorActionPreference cannot downgrade, so every optional-field read had to stop being a bare
# member access. This helper returns $null for an absent field - which is exactly what the bare read
# silently produced before - so converting a site cannot change any output line, comparison or exit
# code. Absent-vs-present still means what it meant (an absent OcclusionMax is still threshold 0, an
# absent ExpectAny still yields the one-empty-element loop), because the value handed back is the
# same $null. Kept as one function so the shape is greppable and lints can forbid new bare reads.
function Get-OptValue($o, [string]$k) {
  if ($null -eq $o) { return $null }
  if ($o -is [System.Collections.IDictionary] -and $o.Contains($k)) { return $o[$k] }
  $p = $o.PSObject.Properties[$k]
  if ($null -ne $p) { return $p.Value }
  if ($o -is [System.Collections.IDictionary]) {
    # Keys/Values/Count are members OF the dictionary type, not keys inside it, and PowerShell
    # does not surface every one of them through PSObject.Properties (Values is the one that bit
    # this file: a converted $opStrip.Values[flag] read null and the run died indexing a null
    # array). Enumerated explicitly, so "intrinsic member" stays a visible decision, not a guess.
    if ($k -ceq 'Keys') { return $o.Keys }
    if ($k -ceq 'Values') { return $o.Values }
    if ($k -ceq 'Count') { return $o.Count }
  }
  return $null
}

function Get-HashKeys($h) {
  if ($null -eq $h) { return @() }
  return @($h.GetEnumerator() | ForEach-Object { $_.Key })
}

# v4.3.0: the lang-trap scanner for raw keys-member reads. Pure: takes lines, a selftest-body
# range to exclude, and exempt [start,end) ranges; returns candidates with their exemption
# flag. Used by the lint check AND by that check's planted samples, so the sample and the
# scan cannot diverge. The needle is assembled at runtime (a literal would match this line).
function Get-KeysScanResult($lines, [int]$selfStart, [int]$selfEnd, [array]$exempt) {
  $hits = New-Object System.Collections.ArrayList
  $ls = @($lines)
  for ($i = 0; $i -lt $ls.Count; $i++) {
    if ($selfStart -ge 0 -and $i -ge $selfStart -and $i -lt $selfEnd) { continue }
    $l = [string]$ls[$i]
    if ($l.TrimStart().StartsWith('#')) { continue }
    if (-not $l.Contains('.' + 'Keys')) { continue }
    $ex = $false
    foreach ($r in @($exempt)) { if ($i -ge [int]$r[0] -and $i -lt [int]$r[1]) { $ex = $true; break } }
    [void]$hits.Add([pscustomobject]@{ Line = $i + 1; Text = $l.Trim(); Exempt = $ex })
  }
  return @{ Hits = @($hits) }
}

# v4.2.2 (F2): which raw environment names must go. A process environment block may carry the
# same name twice in different casing (a launcher can hand CreateProcess both spellings; this
# box's agent runtime does). Windows resolves every env lookup case-insensitively, so dropping a
# spelling loses no value - but leaving it in makes PS 5.1's Start-Process throw on its
# case-insensitive copy of the block. Keep the FIRST spelling of each name, report every later
# one; a name that merely resembles another (PATH vs PATHX) is never touched. Pure: the caller
# supplies the names, so the selftest can feed synthetic ones. Comma-returning on purpose (the
# PS 5.1 single-element unwrap trap) - never call it as @()/$( ).
function Get-DuplicateCaseEnvNames([string[]]$Names) {
  $seen = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([System.StringComparer]::OrdinalIgnoreCase)
  $drop = New-Object System.Collections.ArrayList
  foreach ($n in @($Names)) {
    if ($null -eq $n) { continue }
    $k = [string]$n
    if ($k.Length -eq 0) { continue }
    if ($seen.ContainsKey($k)) { [void]$drop.Add($k) } else { $seen[$k] = $k }
  }
  return ,@($drop)
}

# How many positional arguments a call really passes. Needed because PowerShell does
# NOT reject extra positional arguments on a SIMPLE function: `function F([string]$a)`
# called as `F 'X' $false $false` files the two leftovers in $args and runs (measured
# 2026-09-30: simple -> args=2 with no error; the identical call on a [CmdletBinding()]
# function throws). A site written that way reads as "this call suppresses activation"
# while both flags are dead, so no gate can see it - v1.8.0 shipped ten such
# Resolve-Window sites and every one of 446 offline + 528 live checks passed over them.
# Returns an INT on purpose: a list result would re-open the single-element unwrapping
# trap this section is about (see the project gotcha list), and a count is all a scan needs.
# Pure: takes the text AFTER the command name, stops at the first top-level closer or
# pipe, so it works when the call sits inside `if (...) { ... }`, `$( ... )` or `;`-joined lines.
function Get-CallArgCount([string]$tail) {
  if (-not $tail) { return 0 }
  $n = 0
  $inToken = $false
  $depth = 0
  $quote = [char]0
  for ($i = 0; $i -lt $tail.Length; $i++) {
    $c = $tail[$i]
    if ($quote -ne [char]0) { if ($c -eq $quote) { $quote = [char]0 }; continue }
    if ($c -eq "'" -or $c -eq '"') { $quote = $c; $inToken = $true; continue }
    if ($c -eq '(' -or $c -eq '[' -or $c -eq '{') { $depth++; $inToken = $true; continue }
    if ($c -eq ')' -or $c -eq ']' -or $c -eq '}') { if ($depth -eq 0) { break }; $depth--; continue }
    if ($depth -eq 0 -and ($c -eq ';' -or $c -eq '|')) { break }
    if ($depth -eq 0 -and ($c -eq ' ' -or $c -eq [char]9)) {
      if ($inToken) { $n++; $inToken = $false }
      continue
    }
    $inToken = $true
  }
  if ($inToken) { $n++ }
  return $n
}

# The text after the first occurrence of $mark that is NOT inside a quoted literal,
# or $null when every occurrence is quoted. A scan that counts call sites cannot treat
# an assertion TITLE as one: `ST-Check 'unit: Resolve-Window by pid selects...'` mentions
# the function while testing nothing, and feeding that to Get-CallArgCount counts the words
# of the sentence (measured: two such lines reported "passes 6" and "passes 10" on first run).
# Single-quote doubling is not modelled - no scanned line uses it.
function Get-CodeTailAfterMark([string]$line, [string]$mark) {
  if (-not $line -or -not $mark) { return $null }
  $quote = [char]0
  for ($i = 0; $i -lt $line.Length; $i++) {
    $c = $line[$i]
    if ($quote -ne [char]0) { if ($c -eq $quote) { $quote = [char]0 }; continue }
    if ($c -eq "'" -or $c -eq '"') { $quote = $c; continue }
    if ((($line.Length - $i) -ge $mark.Length) -and ($line.Substring($i, $mark.Length) -ceq $mark)) {
      return $line.Substring($i + $mark.Length)
    }
  }
  return $null
}

# Pure: the source of ONE function, from its '^function NAME' line to the first
# column-0 '}' after it. A lint that pins a STRUCTURE ("this Save is inside that try",
# "this route has a catch") cannot just search the whole file - the same words appear in
# somebody else's function, and the answer then depends on file order rather than on the
# thing being claimed. Found=$false when the name is absent, so a renamed function turns
# into a red check instead of a vacuous one.
function Get-FunctionSlice([string]$name, $lines) {
  $fsStart = -1
  $fsEnd = -1
  $fsMark = 'function ' + $name
  $fsAll = @($lines)
  for ($fsI = 0; $fsI -lt $fsAll.Count; $fsI++) {
    if ($fsStart -lt 0) { if (([string]$fsAll[$fsI]).StartsWith($fsMark)) { $fsStart = $fsI }; continue }
    if (([string]$fsAll[$fsI]) -ceq '}') { $fsEnd = $fsI; break }
  }
  if ($fsStart -lt 0 -or $fsEnd -lt $fsStart) { return @{ Found = $false; Start = -1; End = -1; Text = '' } }
  return @{ Found = $true; Start = $fsStart; End = $fsEnd; Text = (($fsAll[$fsStart..$fsEnd]) -join "`n") }
}

# v1.5.7 (D-7): which window of a process IS "the window" the caller meant.
# Pure function over row objects (needs Pid / Handle / Owner / Area) so the rule is
# provable OFFLINE with synthetic rows - a judgement only reachable through --live has
# effectively no assertion behind it. Rule: among a pid's windows the MAIN one is the
# largest-area UNOWNED window; a process whose windows all have owners falls back to
# largest-area overall. Ties break on the handle, so the same rows always produce the
# same map (that reproducibility is asserted, not assumed).
# Returns a hashtable [int64 handle] -> 'yes'|'no'. Callers must NOT wrap it in @():
# @(hashtable) yields ONE element and its .Count is then always 1.
function Select-MainWindowMap($rows) {
  $map = @{}
  $rs = @($rows)
  foreach ($r in $rs) { $map[[int64]$r.Handle] = 'no' }
  foreach ($g in @($rs | Group-Object -Property Pid)) {
    $gr = @($g.Group)
    $free = @($gr | Where-Object { [int64]$_.Owner -eq 0 })
    $pool = $(if (@($free).Count -gt 0) { $free } else { $gr })
    $sorted = @($pool | Sort-Object -Property @{Expression = 'Area'; Descending = $true }, @{Expression = 'Handle'; Descending = $false })
    if (@($sorted).Count -ge 1) { $map[[int64]$sorted[0].Handle] = 'yes' }
  }
  return $map
}

# v4.2.0 (external feedback item 6, 2026-10-10): HOW a resolved pick is labelled. A window
# parked in the taskbar was still reported as pick=fg - its rect reads (-31991,-32000),
# coordinates no click can land on, so "foreground hit" was a claim about the LABEL, not
# about the pick. The basis (fg/largest) still decides WHICH window is picked; only the
# label changes when that window is minimized, and 'parked' means exactly "picked, but
# minimized - restore it before you act on it".
function Get-WindowPickLabel([string]$basis, [bool]$iconic) {
  if ($iconic) { return 'parked' }
  return "$basis"
}

# One reader for "is this window minimized", shared by Resolve-Window and its checks, so
# the pick label and the echoed iconic= flag can never disagree about one window.
function Test-WindowIconic($row) {
  if ($null -eq $row) { return $false }
  try { return [bool][DT]::IsIconic((Get-OptValue $row 'Handle')) } catch { return $false }
}

# The one producer of the "you picked a non-main window of that process" sentence.
# Empty string = nothing to say (single-window process, or the main window was picked):
# an unconditional note would be noise people learn to skip, which is how the NOTICE for
# activation is also kept conditional.
function Format-NonMainPickNote($pick, $rows, [string]$basis) {
  if ($null -eq $pick) { return '' }
  if ($pick.Main -ne 'no') { return '' }
  $sibs = @(@($rows) | Where-Object { $_.Pid -eq $pick.Pid -and $_.Main -eq 'yes' })
  if (@($sibs).Count -lt 1) { return '' }
  $m = $sibs[0]
  $why = if ($basis -eq 'fg') { 'it is the foreground window of that process' } else { 'it is the largest matching window' }
  return "note: pid=$($pick.Pid) has a main window handle=$([int64]$m.Handle) '$($m.Title)' ($($m.W)x$($m.H)) but this pick is handle=$([int64]$pick.Handle) '$($pick.Title)' ($($pick.W)x$($pick.H)) because $why - if you meant the main window select it by title / proc: / class: (or by the handle above); --index-style selectors do not exist here"
}

# The wins text row, in exactly one place: the selftest pins both this line's columns and
# the JSON key set, so "the print gained a column but the machine view did not" cannot
# happen quietly (that split is how two views of the same fact start lying to each other).
function Format-WinRowText($r) {
  $own = [int64]$r.Owner
  $ownTxt = if ($own -eq 0) { '-' } else { "$own" }
  return "pid=$($r.Pid) proc=$($r.Proc) class=$($r.Class) popup=$($r.Popup.ToString().ToLower()) owner=$ownTxt main=$($r.Main)  rect=($($r.Left),$($r.Top))-($($r.Right),$($r.Bottom))  size=$($r.W)x$($r.H)  title=$($r.Title)"
}

function Get-WinList {
  $script:WL = New-Object System.Collections.ArrayList
  if (-not $script:ProcNameCache) { $script:ProcNameCache = @{} }
  $cb = [DT+EnumProc] {
    param($h, $l)
    if ([DT]::IsWindowVisible($h)) {
      $t = [DT]::Text($h)
      $cn = New-Object System.Text.StringBuilder 256
      [void][DT]::GetClassName($h, $cn, 256)
      # Include Win32 native menus even though they have no title: context menus
      # (class #32768) are exactly the windows menu-pick needs to find, and
      # title-only filtering hides them. Everything else still requires a title
      # so wins stays readable.
      if ($t -or $cn.ToString() -eq '#32768') {
        $r = New-Object DT+RECT
        [void][DT]::GetWindowRect($h, [ref]$r)
        # Win10/11 GetWindowRect includes the INVISIBLE resize border (~7-11 px
        # left/right/bottom), which makes `win` captures and `relclick` offsets
        # sit shifted vs the VISIBLE window. DWMWA_EXTENDED_FRAME_BOUNDS (=9)
        # is the real visible rect; use it whenever available, else keep the
        # plain rect (some windows, e.g. the desktop, do not support it).
        $er = New-Object DT+RECT
        $sz = [System.Runtime.InteropServices.Marshal]::SizeOf($er)
        if ([DT]::DwmGetWindowAttribute($h, (Get-DwmVisibleFrameAttribute), [ref]$er, $sz) -eq 0) {
          $r = $er
        }
        $procId = 0
        [void][DT]::GetWindowThreadProcessId($h, [ref]$procId)
        if (-not $script:ProcNameCache.ContainsKey($procId)) {
          $pn = ''
          try { $pn = (Get-Process -Id $procId -ErrorAction Stop).ProcessName } catch { }
          $script:ProcNameCache[$procId] = $pn
        }
        # WS_POPUP (0x80000000): context menus and similar transient windows are
        # their own top-level windows - this flag is how wins marks them, so an
        # agent shoots the menu itself instead of cropping the parent window.
        $style = [DT]::GetWindowLong($h, -16)
        $popup = (([int64]$style) -band 0x80000000L) -ne 0
        $w = $r.Right - $r.Left
        $hh = $r.Bottom - $r.Top
        if ($w -gt 0 -and $hh -gt 0) {
          [void]$script:WL.Add([pscustomobject]@{
            Handle = $h; Pid = $procId; Proc = $script:ProcNameCache[$procId]
            Class = $cn.ToString(); Popup = $popup
            # v1.5.7 (D-7): GW_OWNER (4). A Steam-style promo popup and the app's real
            # main window can share pid, class AND the WS_POPUP bit (Steam's main window
            # carries WS_POPUP itself), so `popup=` cannot tell them apart and a title
            # selector was the only way out. Owner is the column that does.
            Owner = [int64][DT]::GetWindow($h, 4)
            Left = $r.Left; Top = $r.Top
            Right = $r.Right; Bottom = $r.Bottom; W = $w; H = $hh
            Area = $w * $hh; Title = $t
          })
        }
      }
    }
    return $true
  }
  [void][DT]::EnumWindows($cb, [IntPtr]::Zero)
  # v1.5.7 (D-7): stamp main=yes|no once, here, from the pure rule - so wins/info/the
  # selector note all read the SAME judgement instead of three hand-copied versions of it.
  $mainMap = Select-MainWindowMap $script:WL
  foreach ($r in @($script:WL)) {
    $mv = 'no'
    if ($mainMap.ContainsKey([int64]$r.Handle)) { $mv = $mainMap[[int64]$r.Handle] }
    $r | Add-Member -NotePropertyName Main -NotePropertyValue $mv -Force
  }
  return $script:WL
}

# selector: a numeric pid, a case-insensitive title substring, "t:<substr>" /
# "title:<substr>" to force title matching (needed when the substring itself
# is all digits), "proc:<name>" for an exact process name match (case-insensitive),
# "hwnd:<0xhex|decimal>" for one exact top-level window handle (CU-OPS package D:
# a title can change or be duplicated, a handle cannot - a value that is not a
# number is refused, never degraded into a title substring), or "class:<substr>" for a window class substring match. Among matches the
# largest non-minimized window wins (usually the app's main window). Minimized
# windows stay "visible" to EnumWindows but sit at (-32000,-32000), so they are
# only used when nothing else matches.
# A selector that parses as a pid is matched by pid ONLY - no fallback to title
# matching, so a stale pid can never hit an unrelated window whose title
# happens to contain those digits.
# Foreground-first rule for numeric pid selectors: a process can own several
# top level windows (app main window + modal file dialog, both same pid); while
# one of them owns the foreground THAT one is the intended target, not the
# largest. The chosen basis is reported back as Pick = 'fg' or 'largest', and as
# 'parked' when that pick is minimized (v4.2.0 feedback item 6) - see
# Get-WindowPickLabel, which is the one place that decision is made.
# When a non-pid selector matches SEVERAL windows, resolution refuses to guess and
# lists every candidate. A caller must disambiguate with pid / proc: / class: (or a
# narrower title selector). Numeric pid selectors retain their foreground-first rule
# for the common main-window-plus-dialog case.
# v1.11.0: the selector semantics, extracted PURE so the owner's four contrast groups
# (title containing [ / * / ?, empty needle) are unit-testable offline. Literal
# substring via Test-NameSubstring - the same rules the UIA Name matcher has used since
# v1.8.0: case insensitive, empty needle refused. -like turned '[', '*' and '?' inside a
# title into wildcards, so a window could not be found by the very string `wins`
# printed (the same accident class the UIA side already fixed).
function Select-WindowsBySelector($all, [string]$sel) {
  $selHits = @()
  $byPid = $false
  $asPid = 0
  if ($sel -match '^(?:t|title):(.*)$') {
    $sub = $Matches[1]
    if (-not ("$sub".Trim())) { throw 'title selector must not be empty (t:/title: with nothing after it would previously have matched EVERY window)' }
    $selHits = @($all | Where-Object { Test-NameSubstring $_.Title $sub })
  } elseif ($sel -match '^proc:(.*)$') {
    $sub = $Matches[1]
    if (-not ("$sub".Trim())) { throw 'proc selector must not be empty' }
    $selHits = @($all | Where-Object { $_.Proc -eq $sub })
  } elseif ($sel -match '^class:(.*)$') {
    $sub = $Matches[1]
    if (-not ("$sub".Trim())) { throw 'class selector must not be empty' }
    $selHits = @($all | Where-Object { Test-NameSubstring $_.Class $sub })
  } elseif ($sel -match '^hwnd:(.*)$') {
    # CU-OPS package D: the handle IS the identity. A window that was retitled keeps its
    # handle, and a handle that is gone must NOT be approximated by the closest title -
    # that is how "the same window" turns into a different window. Accepts 0x-hex or
    # decimal; anything else is refused here rather than falling through to a title match.
    $raw = "$($Matches[1])".Trim()
    $hv = [int64]0
    $okNum = $false
    if ($raw -match '^0x[0-9a-fA-F]+$') { $okNum = [int64]::TryParse($raw.Substring(2), [System.Globalization.NumberStyles]::HexNumber, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$hv) }
    elseif ($raw -match '^\d+$') { $okNum = [int64]::TryParse($raw, [ref]$hv) }
    if (-not $okNum -or $hv -le 0) { throw "hwnd selector needs a handle like hwnd:0x00120A34 or hwnd:1182260 - got: $raw" }
    $selHits = @($all | Where-Object { [int64]([IntPtr]$(Get-OptValue $_ 'Handle')).ToInt64() -eq $hv })
  } elseif ([int]::TryParse($sel, [ref]$asPid)) {
    $byPid = $true
    $selHits = @($all | Where-Object { $_.Pid -eq $asPid })
  } else {
    $selHits = @($all | Where-Object { Test-NameSubstring $_.Title $sel })
  }
  return @{ Matches = @($selHits); ByPid = $byPid }
}

function Get-SelectorAmbiguity($selHits, [string]$sel) {
  $ms = @($selHits)
  if ($ms.Count -le 1) { return @{ Ambiguous = $false; Message = ''; Count = $ms.Count } }
  $cands = (@($ms | ForEach-Object {
    "pid=$(Get-OptValue $_ 'Pid') proc=$(Get-OptValue $_ 'Proc') class=$(Get-OptValue $_ 'Class') main=$(Get-OptValue $_ 'Main') title='$(Get-OptValue $_ 'Title')' rect=($(Get-OptValue $_ 'Left'),$(Get-OptValue $_ 'Top'),$(Get-OptValue $_ 'W')x$(Get-OptValue $_ 'H'))"
  }) -join '; ')
  return @{
    Ambiguous = $true
    Count = $ms.Count
    Message = "selector '$sel' matched $($ms.Count) windows; refusing an ambiguous target. candidates: $cands; choose pid / proc: / class: / a narrower title selector"
  }
}

function Resolve-Window([string]$sel) {
  $all = Get-WinList
  $script:ResolveNote = ''
  $r = Select-WindowsBySelector $all $sel
  $selHits = $r.Matches
  $byPid = $r.ByPid
  if (-not $selHits) {
    # A flag token reaching here is always a caller mistake (e.g. focus --to X
    # before v1.4.0): say so instead of a bare "no window matching: --to".
    if ($sel -like '--*') {
      throw "selector looks like a flag: '$sel' - this command takes a positional <sel>; --to/--force style flags belong to type/keys/paste/paste-file/click-family (focus also accepts --to)"
    }
    return $null
  }
  if ($byPid) {
    $fgH = [DT]::GetForegroundWindow()
    $fgWin = @($selHits | Where-Object { $_.Handle -eq $fgH })
    if ($fgWin) {
      $pick = $fgWin[0]
      # v4.2.0 (feedback item 6): a minimized window CAN still be the foreground one (a
      # programmatic minimize hands the foreground to nobody), so the label has to tell
      # "picked while parked" apart from a trustworthy foreground hit.
      $pickIconic = Test-WindowIconic $pick
      $pick | Add-Member -NotePropertyName Iconic -NotePropertyValue $pickIconic -Force
      $pick | Add-Member -NotePropertyName Pick -NotePropertyValue (Get-WindowPickLabel 'fg' $pickIconic) -Force
      # v1.5.7 (D-7): foreground-first is right for a modal dialog and wrong for a
      # promo popup, and the caller cannot tell which it just got. Say which it is,
      # in the one note channel every target-resolving command already prints.
      $script:ResolveNote = Format-NonMainPickNote $pick $all 'fg'
      return $pick
    }
  }
  $amb = Get-SelectorAmbiguity $selHits $sel
  if (-not $byPid -and $amb.Ambiguous) {
    throw $amb.Message
  }
  $live = @($selHits | Where-Object { -not [DT]::IsIconic($_.Handle) })
  if ($live) { $selHits = $live }
  $pick = @($selHits | Sort-Object -Property Area -Descending)[0]
  $pickIconic = Test-WindowIconic $pick
  $pick | Add-Member -NotePropertyName Iconic -NotePropertyValue $pickIconic -Force
  $pick | Add-Member -NotePropertyName Pick -NotePropertyValue (Get-WindowPickLabel 'largest' $pickIconic) -Force
  $script:ResolveNote = Format-NonMainPickNote $pick $all 'largest'
  return $pick
}

# Prints (once) the note Resolve-Window recorded for the last pick. Ambiguous
# non-PID selections refuse before this channel; PID picks may still report the
# foreground/non-main relationship here.
function Emit-ResolveNote {
  # v1.5.6: the activation verdict rides along here because this is the one printer every
  #    target-resolving command already calls. Printing it from Resolve-Target itself was
  #    swallowed by `$tgt = Resolve-Target ...` (see the comment on that function).
  # v4.4.0 (G-14, owner ruling 2026-10-19): these three sentences are diagnostics about how a target was
  #    picked - they are not fields of any command's envelope - so on the --json road they take the error
  #    stream and stdout stays parseable. This is the stream rule G-08 bought for the auto-trim note, put in
  #    the one function every target-resolving command already calls: no call site moves, and which paths
  #    reach the dispatcher tail is exactly what G-17 settled. Without --json the human reading is unchanged,
  #    byte for byte, in the same order. Clearing happens on both roads, so a note is never printed twice
  #    and never left alive for the next command.
  if ($script:ActivationLine) {
    if ($script:Json) { [Console]::Error.WriteLine([string]$script:ActivationLine) } else { Write-Output $script:ActivationLine }
    $script:ActivationLine = ''
  }
  if ($script:ActivationNotice) {
    if ($script:Json) { [Console]::Error.WriteLine([string]$script:ActivationNotice) } else { Write-Output $script:ActivationNotice }
    $script:ActivationNotice = ''
  }
  if ($script:ResolveNote) {
    if ($script:Json) { [Console]::Error.WriteLine([string]$script:ResolveNote) } else { Write-Output $script:ResolveNote }
    $script:ResolveNote = ''
  }
}

# Timestamped default file names (millisecond resolution: two calls within the
# same second must not overwrite each other).
function Default-ShotName([string]$base) {
  return Join-Path $OutDir ("{0}_{1}.png" -f $base, (Get-Date -Format 'yyyyMMddTHHmmssfff'))
}

# Capture options shared by shot/win/rect: --fit <px|0> downscales a wide image
# to the given width (rect defaults to 900 - roughly what a viewer shows 1:1),
# --grid [step] overlays a coordinate grid labelled in SCREEN pixels, and
# --mark x,y draws crosshairs at candidate click points. Together with the
# echoed mapping formula this turns "eyeball coordinates on a downscaled
# viewer" (which silently mislocated clicks twice in real use) into "read the
# label" or "apply the formula".
function Parse-CaptureFlags([string[]]$words, [bool]$defaultFit) {
  $rest = New-Object System.Collections.ArrayList
  $fit = $null; $grid = -1
  # v1.5.7 (D-6, J-04 option B): the default only changes for images that are BOTH
  # explicitly fitted and wider than 1000px, and an explicit --no-grid always wins.
  # A grid is drawn on the SAVED bitmap only - hash/assert-hash/OCR all read screen
  # pixels, so overlaying it cannot pollute a pixel or OCR judgement (checked in the
  # verification report). The one thing it does affect is imgclick, which reads that
  # very PNG, so the sidecar records grid= and imgclick warns when it is non-zero.
  $fitUser = $false
  $gridUser = $false
  $marks = New-Object System.Collections.ArrayList
  $i = 0
  while ($i -lt $words.Count) {
    $t = $words[$i]
    if ($t -eq '--fit') {
      $fitUser = $true
      $i++
      if ($i -ge $words.Count) { throw '--fit needs a width in px (0 = full resolution)' }
      $fit = Read-FlagNumber '--fit' $words[$i] $true '(pixels)'
    } elseif ($t -eq '--grid') {
      $gridUser = $true
      $grid = 50
      if ($i + 1 -lt $words.Count -and $words[$i + 1] -match '^\d+$') { $i++; $grid = Read-FlagNumber '--grid' $words[$i] $true ''}
    } elseif ($t -eq '--no-grid') {
      $gridUser = $true; $grid = -1
    } elseif ($t -eq '--mark') {
      $i++
      if ($i -ge $words.Count) { throw '--mark needs x,y' }
      $parts = $words[$i] -split ','
      if ($parts.Count -ne 2 -or @($parts | Where-Object { $_ -match '^-?\d+$' }).Count -ne 2) { throw "--mark expects x,y got: $($words[$i])" }
      [void]$marks.Add(@{ X = [int]$parts[0]; Y = [int]$parts[1] })
    } else {
      [void]$rest.Add($t)
    }
    $i++
  }
  if ($null -eq $fit) { $fit = if ($defaultFit) { 900 } else { 0 } }
  return @{ Rest = @($rest); Fit = [int]$fit; Grid = $grid; Marks = @($marks); FitUser = $fitUser; GridUser = $gridUser }
}

# Captures the region 1:1, applies optional downscale/grid/mark, saves PNG and
# returns the echo lines (saved line + mapping formula + a WARN for wide
# full-resolution images that a viewer will downscale).
# v1.5.1 WP-B: $mapWin (the resolved window object, when the capture is a
# window grab) is recorded in the sidecar so imgclick/unmap can detect that
# the window moved/resized since capture instead of silently mis-mapping.
function Save-RectEx([int]$x, [int]$y, [int]$w, [int]$h, [string]$path, [double]$fit, [int]$grid, $marks, [string]$mapKind = '', $mapWin = $null, $cf = $null) {
  $autoGrid = $false
  Ensure-OutDir
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size($w, $h)))
  $g.Dispose()
  $scale = 1.0
  if ($fit -gt 0 -and $w -gt $fit) { $scale = $fit / $w }
  if ($scale -ne 1.0) {
    $small = New-Object System.Drawing.Bitmap([int][math]::Round($w * $scale), [int][math]::Round($h * $scale))
    $g2 = [System.Drawing.Graphics]::FromImage($small)
    $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g2.DrawImage($bmp, 0, 0, $small.Width, $small.Height)
    $g2.Dispose()
    $bmp.Dispose()
    $bmp = $small
  }
  $iw = $bmp.Width; $ih = $bmp.Height
  # v1.5.7 (D-6, J-04 B): a capture that the USER asked to fit AND that still comes out
  # wider than 1000px gets a grid by default - that is exactly the image class where
  # eyeballing fails twice (the owner measured (3590,50) vs a true (3562,32) on a
  # --fit 1200/1400 shot). --no-grid turns it off; an explicit --grid always wins.
  # The grid only ever exists on the saved PNG: hash/assert-hash and OCR read screen
  # pixels, so no pixel judgement can be polluted by it. imgclick is the one reader that
  # consumes this bitmap, so the step goes into the sidecar and imgclick warns about it.
  if ($grid -le 0 -and $null -ne $cf -and $cf.FitUser -and -not $cf.GridUser -and $fit -gt 0 -and $iw -gt (Get-ShotViewerWidePx)) {
    $grid = 50
    $autoGrid = $true
  }
  if ($grid -gt 0 -or @($marks).Count -gt 0) {
    $g3 = [System.Drawing.Graphics]::FromImage($bmp)
    if ($grid -gt 0) {
      # grid lines sit on round SCREEN coordinates so the labels can be read
      # directly as screen pixels regardless of the fit scale
      $font = New-Object System.Drawing.Font('Consolas', 7)
      $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(140, 255, 0, 0))
      $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 255, 0, 0))
      $sx = [int]([math]::Ceiling($x / $grid) * $grid)
      while ($sx -le ($x + $w)) {
        $ix = [int][math]::Round(($sx - $x) * $scale)
        if ($ix -ge 0 -and $ix -lt $iw) {
          $g3.DrawLine($pen, $ix, 0, $ix, $ih)
          $g3.DrawString("$sx", $font, $brush, [single]($ix + 1), [single]1)
        }
        $sx += $grid
      }
      $sy = [int]([math]::Ceiling($y / $grid) * $grid)
      while ($sy -le ($y + $h)) {
        $iy = [int][math]::Round(($sy - $y) * $scale)
        if ($iy -ge 0 -and $iy -lt $ih) {
          $g3.DrawLine($pen, 0, $iy, $iw, $iy)
          $g3.DrawString("$sy", $font, $brush, [single]1, [single]($iy + 1))
        }
        $sy += $grid
      }
      $font.Dispose(); $pen.Dispose(); $brush.Dispose()
    }
    $penM = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 0, 120, 255), 1)
    foreach ($m in @($marks)) {
      $mx = [int][math]::Round(($m.X - $x) * $scale)
      $my = [int][math]::Round(($m.Y - $y) * $scale)
      $g3.DrawLine($penM, $mx - 14, $my, $mx + 14, $my)
      $g3.DrawLine($penM, $mx, $my - 14, $mx, $my + 14)
      $inOut = if ($mx -ge 0 -and $my -ge 0 -and $mx -lt $iw -and $my -lt $ih) { 'inside' } else { 'OUTSIDE capture' }
      Write-Output ("mark ($($m.X),$($m.Y)) -> image ($mx,$my) $inOut")
    }
    $penM.Dispose()
    $g3.Dispose()
  }
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  $size = (Get-Item -LiteralPath $path).Length
  if ($mapKind) { Write-MapSidecar $path $x $y $scale $iw $ih $mapKind $mapWin $grid }
  $lines = New-Object System.Collections.ArrayList
  $gridTxt = $(if ($grid -gt 0) { "  grid=$grid$(if ($autoGrid) { ' (auto: --fit and wider than 1000px; --no-grid turns it off)' } else { '' })" } else { '' })
  if ($scale -eq 1.0) {
    [void]$lines.Add("saved $path  rect=($x,$y) size=${w}x${h}  bytes=$size  coords: screen = image + ($x,$y)  (image ${iw}x${ih} px, 1:1)$gridTxt")
    if ($w -gt 1400) {
      [void]$lines.Add("WARN: ${w} px wide - your viewer will likely DOWNSCALE this image, so eyeballed coordinates WILL be off. Use --grid (read coordinates off the labels), --fit 900, or zoom. The only supported way back from a pixel you SAW in this image is: imgclick <image> <ix> <iy> (unmap prints the mapping without clicking) - this capture already wrote the .map.txt it needs next to the file. $(if ($grid -gt 0) { 'This capture already carries a grid.' } else { 'Prefer find <text> / find-text <small region> --needle <text> over any measured point.' })")
    }
  } else {
    $rs = [math]::Round($scale, 4)
    $inv = [math]::Round(1.0 / $scale, 4)
    # Both forms on purpose: dividing by 0.593 in your head was the direct
    # source of two real mis-clicks (audit 2026-09-29b #3); the multiply form
    # removes the division. --grid removes the math altogether.
    [void]$lines.Add("saved $path  rect=($x,$y) req=${w}x${h} image=${iw}x${ih} scale=$rs  bytes=$size  coords: screen = ($x + ix/$rs, $y + iy/$rs)  (= $x + ix*$inv, $y + iy*$inv)$gridTxt")
    if ($iw -gt (Get-ShotViewerWidePx) -and $grid -le 0) {
      # v1.5.7 (D-6): the owner measured (3590,50) against a true (3562,32) on a
      # --fit 1200/1400 image - the viewer downscales AGAIN on top of this file.
      [void]$lines.Add("WARN: image is ${iw}px wide, so the viewer will downscale it once more - do not eyeball coordinates here; add --grid, or use find <text> / find-text <small region> --needle <text> and take centre= from its echo. If the point is something you already SAW in this image, the road is imgclick <image> <ix> <iy> - the .map.txt it reads was written next to this file by this capture.")
    }
  }
  if ($mapKind) { [void]$lines.Add("map: $path.map.txt  (imgclick <image> <ix> <iy> maps back and clicks; unmap prints only - no manual ix/scale math)") }
  # v2.6.0: the capture-folder trim is NOT hooked here - it runs once at the tail of
  # Invoke-DesktopCommand, because `zoom` saves its own bitmap and would have slipped a
  # hook placed here (proved by a real run, not by reading the code).
  return ,$lines
}

# v1.5.0 WP-3: mapping sidecar written next to every win/rect/zoom capture.
# All three kinds share ONE forward rule (also printed in the capture echo):
#   screen = (origin_x + ix/scale, origin_y + iy/scale)
# and the inverse (screen -> image px) is ix = (screen_x - origin_x) * scale.
# For zoom the scale is the ENLARGE factor, so the inverse is a multiply -
# the constants stored here are exactly the ones the inverse needs; callers
# (imgclick / unmap) never guess a scale.
# v1.5.1 WP-B: kind=win sidecars additionally record pid/handle/title_b64
# (the staleness anchor). Title is base64 because window titles may contain
# newlines, '=' or non-ASCII bytes.
function Write-MapSidecar([string]$imagePath, [int]$ox, [int]$oy, [double]$scale, [int]$ow, [int]$oh, [string]$kind, $hostWin = $null, [int]$gridStep = 0) {
  $inv = [System.Globalization.CultureInfo]::InvariantCulture
  $s = [math]::Round($scale, 6).ToString($inv)
  $text = "origin_x=$ox`r`norigin_y=$oy`r`nscale=$s`r`nout_w=$ow`r`nout_h=$oh`r`nkind=$kind`r`n"
  # v1.5.7 (D-6, owner's added condition): a grid is drawn ON this bitmap, and imgclick
  # reads exactly this bitmap - so the fact has to travel with the file instead of being
  # discoverable only by looking at the PNG.
  if ($gridStep -gt 0) { $text += "grid=$gridStep`r`n" }
  if ($kind -eq 'win' -and $null -ne $hostWin) {
    $hp = [int]$hostWin.Pid
    $hh = ([IntPtr]$hostWin.Handle).ToInt64()
    $tb = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([string]$hostWin.Title))
    $text += "pid=$hp`r`nhandle=$hh`r`ntitle_b64=$tb`r`n"
  }
  [System.IO.File]::WriteAllText(($imagePath + '.map.txt'), $text, (New-Object System.Text.UTF8Encoding($false)))
}

# Reads <image>.map.txt back. A missing or malformed sidecar is an ERROR that
# says how to fix it (re-capture) - this tool never guesses a scale.
# v1.5.1 WP-B: kind=win sidecars must carry pid/handle (written since v1.5.1);
# a win sidecar without them predates staleness tracking and is refused at
# read time so imgclick can never silently mis-map through it.
function Read-MapSidecar([string]$imagePath) {
  $mapPath = $imagePath + '.map.txt'
  if (-not (Test-Path -LiteralPath $mapPath)) {
    throw "map sidecar not found: $mapPath - re-capture the image (win/rect/zoom write the .map.txt next to every image; this tool never guesses a scale)"
  }
  $raw = [System.IO.File]::ReadAllText($mapPath, [System.Text.Encoding]::UTF8)
  $ox = $null; $oy = $null; $sc = $null; $ow = $null; $oh = $null; $kd = ''
  $hPid = $null; $hHnd = $null; $hTb = ''
  if ($raw -match '(?m)^origin_x=(-?\d+)\s*$') { $ox = [int]$Matches[1] }
  if ($raw -match '(?m)^origin_y=(-?\d+)\s*$') { $oy = [int]$Matches[1] }
  if ($raw -match '(?m)^scale=(\d+(?:\.\d+)?)\s*$') { $sc = [double]::Parse($Matches[1], [System.Globalization.CultureInfo]::InvariantCulture) }
  if ($raw -match '(?m)^out_w=(\d+)\s*$') { $ow = [int]$Matches[1] }
  if ($raw -match '(?m)^out_h=(\d+)\s*$') { $oh = [int]$Matches[1] }
  if ($raw -match '(?m)^kind=(\w+)\s*$') { $kd = $Matches[1] }
  if ($raw -match '(?m)^pid=(\d+)\s*$') { $hPid = [int]$Matches[1] }
  if ($raw -match '(?m)^handle=(-?\d+)\s*$') { $hHnd = [long]$Matches[1] }
  if ($raw -match '(?m)^title_b64=([A-Za-z0-9+/=]+)\s*$') { $hTb = $Matches[1] }
  if ($null -eq $ox -or $null -eq $oy -or $null -eq $sc -or $sc -le 0 -or $null -eq $ow -or $null -eq $oh -or $kd -notin @('win', 'rect', 'zoom')) {
    throw "map sidecar malformed: $mapPath - re-capture the image"
  }
  $title = ''
  if ($hTb) { try { $title = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($hTb)) } catch { $title = '' } }
  $hHwnd = [IntPtr]::Zero
  if ($null -ne $hHnd) { $hHwnd = [System.IntPtr]$hHnd }
  if ($kd -eq 'win' -and ($null -eq $hPid -or $null -eq $hHnd)) {
    throw "map sidecar predates staleness tracking (kind=win without pid/handle): $mapPath - re-capture the image (win <sel>)"
  }
  $gStep = 0
  if ($raw -match '(?m)^grid=(\d+)\s*$') { $gStep = [int]$Matches[1] }
  return @{ OriginX = $ox; OriginY = $oy; Scale = $sc; OutW = $ow; OutH = $oh; Kind = $kd; Grid = $gStep; HostPid = $(if ($null -ne $hPid) { $hPid } else { 0 }); HostHwnd = $hHwnd; HostTitle = $title }
}

# Image px -> screen px using a sidecar (single formula for win/rect/zoom).
function Convert-ImageToScreen($map, [int]$ix, [int]$iy) {
  return @{ X = [int][math]::Round($map.OriginX + $ix / $map.Scale); Y = [int][math]::Round($map.OriginY + $iy / $map.Scale) }
}

# v1.5.1 WP-B: current VISIBLE rect of a window handle (DWM extended frame
# when available, plain GetWindowRect otherwise - the same rule Get-WinList
# applies to every rect this tool reports). Returns a hashtable or $null.
function Get-WindowVisibleRect([IntPtr]$h) {
  if (-not [DT]::IsWindow($h)) { return $null }
  $wr = New-Object DT+RECT
  [void][DT]::GetWindowRect($h, [ref]$wr)
  $vr = New-Object DT+RECT
  if ([DT]::DwmGetWindowAttribute($h, (Get-DwmVisibleFrameAttribute), [ref]$vr, [System.Runtime.InteropServices.Marshal]::SizeOf($vr)) -eq 0) { $wr = $vr }
  return @{ X = $wr.Left; Y = $wr.Top; W = ($wr.Right - $wr.Left); H = ($wr.Bottom - $wr.Top) }
}

# v1.5.1 WP-B: is a sidecar still valid for the window it was captured from?
#   ok            - window exists, same pid, origin/size within 2px
#   stale         - window moved/resized beyond 2px (or is minimized)
#   gone          - handle dead or reused by another process (never guess)
#   unverifiable  - rect/zoom sidecars have no host window (say so, don't fail)
# Returns @{ Verdict; Msg; OldX; OldY; NewX; NewY; OldW; OldH; NewW; NewH }.
function Test-MapSidecarStale($map) {
  if ($map.Kind -ne 'win') {
    return @{ Verdict = 'unverifiable'; Msg = 'no host window - staleness not verifiable'; OldX = $map.OriginX; OldY = $map.OriginY; NewX = $null; NewY = $null; OldW = $null; OldH = $null; NewW = $null; NewH = $null }
  }
  $h = $map.HostHwnd
  if (-not [DT]::IsWindow($h)) {
    return @{ Verdict = 'gone'; Msg = "the recorded window handle=$($h) no longer exists - re-capture the image (win <sel>)"; OldX = $map.OriginX; OldY = $map.OriginY; NewX = $null; NewY = $null; OldW = $null; OldH = $null; NewW = $null; NewH = $null }
  }
  $curPid = 0
  [void][DT]::GetWindowThreadProcessId($h, [ref]$curPid)
  if ($curPid -ne $map.HostPid) {
    return @{ Verdict = 'gone'; Msg = "window handle=$($h) now belongs to pid=$curPid (was pid=$($map.HostPid)) - handle reused, refusing to guess; re-capture the image"; OldX = $map.OriginX; OldY = $map.OriginY; NewX = $null; NewY = $null; OldW = $null; OldH = $null; NewW = $null; NewH = $null }
  }
  $r = Get-WindowVisibleRect $h
  if ($null -eq $r) {
    return @{ Verdict = 'gone'; Msg = 'window vanished while checking - re-capture the image'; OldX = $map.OriginX; OldY = $map.OriginY; NewX = $null; NewY = $null; OldW = $null; OldH = $null; NewW = $null; NewH = $null }
  }
  $oldW = [int][math]::Round($map.OutW / $map.Scale)
  $oldH = [int][math]::Round($map.OutH / $map.Scale)
  $dx = [math]::Abs($r.X - $map.OriginX)
  $dy = [math]::Abs($r.Y - $map.OriginY)
  $dw = [math]::Abs($r.W - $oldW)
  $dh = [math]::Abs($r.H - $oldH)
  if ($dx -gt 2 -or $dy -gt 2 -or $dw -gt 2 -or $dh -gt 2) {
    $what = New-Object System.Collections.ArrayList
    if ($dx -gt 2 -or $dy -gt 2) { [void]$what.Add("origin was ($($map.OriginX),$($map.OriginY)) now ($($r.X),$($r.Y))") }
    if ($dw -gt 2 -or $dh -gt 2) { [void]$what.Add("size was ${oldW}x${oldH} now $($r.W)x$($r.H)") }
    $mini = ''
    if ([DT]::IsIconic($h)) { $mini = ' (window is minimized)' }
    return @{ Verdict = 'stale'; Msg = "sidecar is STALE for '$($map.HostTitle)': $([string]::Join('; ', @($what)))$mini - re-capture (win <sel>) or pass --stale-ok to map against the OLD origin anyway (clicks likely land wrong)"; OldX = $map.OriginX; OldY = $map.OriginY; NewX = $r.X; NewY = $r.Y; OldW = $oldW; OldH = $oldH; NewW = $r.W; NewH = $r.H }
  }
  return @{ Verdict = 'ok'; Msg = ''; OldX = $map.OriginX; OldY = $map.OriginY; NewX = $r.X; NewY = $r.Y; OldW = $oldW; OldH = $oldH; NewW = $r.W; NewH = $r.H }
}

# --- OCR (Windows.Media.Ocr via WinRT, zero third-party deps) -------------
# Probed live on this machine (2026-09-28): engine zh-Hans-CN, MaxImageDimension
# = 10000. Async WinRT calls are bridged to PS 5.1 through the standard
# WindowsRuntimeSystemExtensions.AsTask reflection helper.
$script:OcrEngine = $null
$script:OcrTried = $false
$script:OcrLang = ''   # --ocr-lang override (v1.5.0 WP-4); '' = default pick

function Get-OcrEngine {
  if ($script:OcrTried) { return $script:OcrEngine }
  $script:OcrTried = $true
  if ($script:OcrLang) {
    # --ocr-lang pins the recognizer: resolve the tag against the INSTALLED
    # packs (case-insensitive) and build from that exact Language instance.
    # An unavailable tag dies here with the list - never a silent fallback to
    # another language.
    try {
      Add-Type -AssemblyName System.Runtime.WindowsRuntime
      $null = [Windows.Media.Ocr.OcrEngine,Windows.Media.Ocr,ContentType=WindowsRuntime]
      $avail = @([Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages)
      # CU-FINAL-ROUND2: an empty match must reach the message below, not die on [0]
      $match = @($avail | Where-Object { $_.LanguageTag -ieq $script:OcrLang })
      $pick = $null
      if ($match.Count -gt 0) { $pick = $match[0] }
      if ($null -eq $pick) {
        throw "OCR language '$($script:OcrLang)' is not available; installed packs: $(@($avail | ForEach-Object { $_.LanguageTag }) -join ', ')"
      }
      $eng = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($pick)
      if ($null -eq $eng) { throw "OCR language '$($script:OcrLang)' could not be activated" }
      $script:OcrEngine = $eng
      return $script:OcrEngine
    } catch {
      $script:OcrEngine = $null
      throw
    }
  }
  try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.Media.Ocr.OcrEngine,Windows.Media.Ocr,ContentType=WindowsRuntime]
    $null = [Windows.Globalization.Language,Windows.Globalization,ContentType=WindowsRuntime]
    $eng = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
    if ($null -eq $eng) {
      $avail = @([Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages)
      if ($avail.Count -gt 0) { $eng = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($avail[0]) }
    }
    $script:OcrEngine = $eng
  } catch { $script:OcrEngine = $null }
  return $script:OcrEngine
}

$script:AsTaskM = $null
function Await-WinRt($op, [type]$resultType) {
  if ($null -eq $script:AsTaskM) {
    $script:AsTaskM = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
      Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
    if ($null -eq $script:AsTaskM) { throw 'WinRT AsTask bridge not found (needs desktop PowerShell 5.1+)' }
  }
  $task = $script:AsTaskM.MakeGenericMethod($resultType).Invoke($null, @($op))
  if (-not $task.Wait(20000)) { throw 'WinRT async operation timed out' }
  return $task.Result
}

# OCR one screen region 1:1 and return lines as @{ Text; X; Y; W; H } with
# screen-space rects. Very short regions are upscaled x2 internally (tiny text
# gives OCR nothing to bite on); returned rects are mapped back exactly.
# Screen capture half of the OCR pipeline (v1.5.0 WP-1 split): grabs the region
# 1:1 and optionally upscales. Returns a hashtable (never a bare list - task
# invariant) with the bitmap the caller MUST dispose, plus the scale actually
# applied, so bitmap pixels map back to screen as screen = origin + px/scale.
function Get-ScreenBitmap([int]$x, [int]$y, [int]$w, [int]$h, [double]$scale) {
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size($w, $h)))
  $g.Dispose()
  $src = $bmp
  if ($scale -ne 1.0) {
    $src = New-Object System.Drawing.Bitmap([int]($w * $scale), [int]($h * $scale))
    $g2 = [System.Drawing.Graphics]::FromImage($src)
    $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g2.DrawImage($bmp, 0, 0, $src.Width, $src.Height)
    $g2.Dispose(); $bmp.Dispose()
  }
  return @{ Bitmap = $src; Scale = $scale }
}

# Recognition half of the OCR pipeline: OCRs an in-memory bitmap and returns
# lines with rects in BITMAP pixel coordinates (caller maps to screen). All
# null-Text / null-Word guards live here so every path shares them.
function Invoke-OcrBitmap([System.Drawing.Bitmap]$src) {
  $eng = Get-OcrEngine
  if ($null -eq $eng) { throw 'OCR unavailable: no OCR language pack on this system (Settings > Time & Language > Language, add e.g. zh-CN or en-US)' }
  $tmp = Join-Path $env:TEMP ("dtocr_" + [guid]::NewGuid().ToString('N') + '.png')
  $stream = $null
  $sbmp = $null
  try {
    # v3.0.1 (audit #13, the half the second review left standing): the Save used to sit
    # OUTSIDE the try, so a write that failed part-way left a dtocr_*.png behind with
    # nothing to clean it up. The finally removes $tmp with SilentlyContinue, so moving
    # the Save inside costs nothing when it succeeds.
    $src.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
    $null = [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
    $null = [Windows.Storage.FileAccessMode,Windows.Storage,ContentType=WindowsRuntime]
    $null = [Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime]
    $sf = Await-WinRt ([Windows.Storage.StorageFile]::GetFileFromPathAsync($tmp)) ([Windows.Storage.StorageFile])
    $stream = Await-WinRt ($sf.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    $decoder = Await-WinRt ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $sbmp = Await-WinRt ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $result = Await-WinRt ($eng.RecognizeAsync($sbmp)) ([Windows.Media.Ocr.OcrResult])
    $lines = New-Object System.Collections.ArrayList
    foreach ($line in $result.Lines) {
      # an OcrLine can transiently report a null Text (seen live mid-animation);
      # never let such a line reach the matching code
      $lt = "$($line.Text)"
      if (-not $lt) { continue }
      $minx = [double]::MaxValue; $miny = [double]::MaxValue; $maxx = 0.0; $maxy = 0.0
      foreach ($wd in $line.Words) {
        if ($null -eq $wd) { continue }
        $r = $wd.BoundingRect
        if ($r.X -lt $minx) { $minx = $r.X }
        if ($r.Y -lt $miny) { $miny = $r.Y }
        if ($r.X + $r.Width -gt $maxx) { $maxx = $r.X + $r.Width }
        if ($r.Y + $r.Height -gt $maxy) { $maxy = $r.Y + $r.Height }
      }
      if ($maxx -le $minx) { continue }
      [void]$lines.Add([pscustomobject]@{
        Text = $lt
        X = [int][math]::Round($minx)
        Y = [int][math]::Round($miny)
        W = [int][math]::Round($maxx - $minx)
        H = [int][math]::Round($maxy - $miny)
      })
    }
    return @{ Lines = $lines }
  } finally {
    # v3.0.1 (audit #13, the half that survived re-review): the WinRT stream holds a file
    # handle on the temp PNG and the SoftwareBitmap holds a native buffer. Neither was
    # ever released, so a long `script` batch accumulated both (the Remove-Item below is
    # also why the handle matters - a file still open by this process does not always
    # delete). Best-effort disposal only: a Dispose failure must never mask the error
    # that brought us into this finally.
    foreach ($ocrDisposables in @($sbmp, $stream)) {
      if ($null -eq $ocrDisposables) { continue }
      try { $ocrDisposables.Dispose() } catch { }
    }
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  }
}

function Invoke-OcrRegion([int]$x, [int]$y, [int]$w, [int]$h, [double]$forceScale = 0) {
  $eng = Get-OcrEngine
  if ($null -eq $eng) { throw 'OCR unavailable: no OCR language pack on this system (Settings > Time & Language > Language, add e.g. zh-CN or en-US)' }
  if ($forceScale -lt 0) { $forceScale = 0 }
  $scale = 1.0
  # 1x fast path: very short regions get a 2x upscale; the rule keys off REGION
  # height, not glyph size, by design - the needle commands route through
  # Find-OcrHitsScaled, whose 2x / tiled fallback (v1.5.0 WP-1) covers small
  # text in large windows, so no glyph-size TODO remains here.
  if ($forceScale -gt 0) { $scale = $forceScale }
  elseif ($h -lt 48) {
    $dimLimit = 0L
    try { $dimLimit = Get-OcrMaxDimension } catch { $dimLimit = 0L }
    if ($dimLimit -le 0) {
      $dimLimit = 4000L
      if (-not $script:OcrCapNoteShown) {
        $script:OcrCapNoteShown = $true
        [Console]::Error.WriteLine('note: OCR engine dimension limit unreadable; short-region upscale falls back to the 4000px assumption')
      }
    }
    if (($h * 2) -le $dimLimit) { $scale = 2.0 }
  }
  $cap = Get-ScreenBitmap $x $y $w $h $scale
  try {
    $r = Invoke-OcrBitmap $cap.Bitmap
    $lines = New-Object System.Collections.ArrayList
    foreach ($ln in $r.Lines) {
      # bitmap px -> screen: screen = origin + px/scale (single offset, by design)
      [void]$lines.Add([pscustomobject]@{
        Text = $ln.Text
        X = $x + [int][math]::Round($ln.X / $scale)
        Y = $y + [int][math]::Round($ln.Y / $scale)
        W = [int][math]::Round($ln.W / $scale)
        H = [int][math]::Round($ln.H / $scale)
      })
    }
    return ,$lines
  } finally { $cap.Bitmap.Dispose() }
}

# v2.7.0: OCR a SAVED capture instead of a live screen region. Two reasons this exists:
#   1. it makes OCR quality MEASURABLE. Until now every claim about the OCR road was
#      backed only by live checks that need the desktop, so "our OCR reads this well"
#      could not be tested at all, let alone A/B'd against another recognizer language
#      pack. A stored PNG can be re-read by any agent, on any machine, offline.
#   2. it decouples measuring from driving: no window is raised, nothing is clicked, and
#      another automation cannot collide with the measurement.
# Lines come back in IMAGE pixel coordinates with the origin at the image's own top-left.
# There is no screen, so there is no offset to add - which is exactly why the caller must
# never present these as screen rects (read-text labels them img-rect= and refuses
# --json here, because the pinned read-text envelope carries no provenance field).
function Invoke-OcrFile([string]$Path, [double]$scale) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "OCR file not found: $Path" }
  $item = Get-Item -LiteralPath $Path
  if ($item.PSIsContainer) { throw "OCR file is a folder, not an image: $Path" }
  if ($scale -le 0) { $scale = 1.0 }
  $bmp = $null; $src = $null
  try {
    $bmp = New-Object System.Drawing.Bitmap($item.FullName)
    $iw = [int]$bmp.Width; $ih = [int]$bmp.Height
    if ($iw -le 0 -or $ih -le 0) { throw "OCR file decoded to ${iw}x${ih}, nothing to read: $Path" }
    if ($scale -ne 1.0) {
      $src = New-Object System.Drawing.Bitmap([int]($iw * $scale), [int]($ih * $scale))
      $g = [System.Drawing.Graphics]::FromImage($src)
      $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $g.DrawImage($bmp, 0, 0, $src.Width, $src.Height)
      $g.Dispose()
    } else { $src = $bmp }
    $r = Invoke-OcrBitmap $src
    $out = New-Object System.Collections.ArrayList
    foreach ($ln in $r.Lines) {
      [void]$out.Add([pscustomobject]@{
        Text = $ln.Text
        X = [int][math]::Round($ln.X / $scale)
        Y = [int][math]::Round($ln.Y / $scale)
        W = [int][math]::Round($ln.W / $scale)
        H = [int][math]::Round($ln.H / $scale)
      })
    }
    return @{ Lines = @($out); W = $iw; H = $ih; Scale = $scale }
  } finally {
    if ($null -ne $src -and -not [object]::ReferenceEquals($src, $bmp)) { $src.Dispose() }
    if ($null -ne $bmp) { $bmp.Dispose() }
  }
}

# v2.8.0: what "tiled" means for a STORED image. The live road tiles only to keep a
# pass under the engine's dimension limit; a capture from any modern screen is far
# under it, so that rule alone gives exactly one tile and reads the image the same
# way the plain read does. Here the point of subdividing is the OPPOSITE: cut the
# area handed to one OCR pass so the recognizer spends its detail budget on less
# ground at once. Halving the longer side does that, and never lifts the limit -
# Invoke-OcrBitmapTiled clamps this to the engine's own value.
function Get-FileTileMaxDim([int]$w, [int]$h, [double]$scale) {
  if ($scale -le 0) { $scale = 1.0 }
  $longer = $w
  if ($h -gt $longer) { $longer = $h }
  if ($longer -lt 32) { $longer = 32 }
  $d = [int][math]::Floor(($longer / 2.0) * $scale)
  if ($d -lt 32) { $d = 32 }
  return $d
}

# Tiled read of a saved capture. Coordinates come back in IMAGE px with the origin at
# the image's own top-left - the same space Invoke-OcrFile reports, so a caller can
# mix the two reads without a conversion. Never touches the screen.
function Invoke-OcrFileTiled([string]$Path, [double]$scale, [int]$maxTiles) {
  if ($scale -le 0) { $scale = 2.0 }
  if (-not (Test-Path -LiteralPath $Path)) { throw "OCR file not found: $Path" }
  $item = Get-Item -LiteralPath $Path
  if ($item.PSIsContainer) { throw "OCR file is a folder, not an image: $Path" }
  $bmp = $null
  try {
    $bmp = New-Object System.Drawing.Bitmap($item.FullName)
    $iw = [int]$bmp.Width; $ih = [int]$bmp.Height
    if ($iw -le 0 -or $ih -le 0) { throw "OCR file decoded to ${iw}x${ih}, nothing to read: $Path" }
    $t = Invoke-OcrBitmapTiled $bmp $iw $ih $scale $maxTiles 0 0 (Get-FileTileMaxDim $iw $ih $scale)
    return @{ Lines = @($t.Lines); W = $iw; H = $ih; Scale = $scale; Tiles = $t.Tiles; Ms = $t.Ms; Duplicates = $t.Duplicates; Notes = @($t.Notes) }
  } finally { if ($null -ne $bmp) { $bmp.Dispose() } }
}

# v2.8.1: what an EMPTY read of a stored image is worth, and what to do about it.
#
# The 489-capture survey produced 21 reads of 0 lines, and two of them were real
# dropouts. v2.8.0 retried those with the subdivided 2x read above and recovered
# NEITHER - re-measured on the same two files today: a 920x520 shot still read 0
# through the planner (its 2x-upscaled tiles are the wrong shape for it) but 1 line
# from a plain un-upscaled crop of the top-left quarter, and a 1040x220 shot still
# reads 0 subdivided but 1 line from the whole image simply upscaled. Two different
# failures, two different cures, so the retry is a LADDER of those two passes and the
# report names each pass with what it got.
#
# The trigger floor is deliberately NOT the sparse-WARN band. That band (300k px2) sits
# ABOVE the 1040x220 capture (228,800 px2) the retry exists for, so reusing it - as
# v2.8.0 did, to avoid a second threshold - meant the motivating case got neither a
# warning nor a retry and looked identical to "this image is blank". An empty read is
# suspicious at a much smaller size than a sparse one, so it gets its own, lower floor.
function Get-EmptyReadAreaFloor { return 30000 }
function Test-EmptyReadSuspect([int]$w, [int]$h) {
  return (([long]$w * [long]$h) -ge (Get-EmptyReadAreaFloor))
}

# Pure: the four crop rectangles of a 2x2 read with OVERLAP px folded into each inner
# edge. Rule is testable without an engine; union always covers the image and no rect
# ever leaves it, which is what the unit checks below pin. Order is row-major so a
# reported tile index stays reproducible.
function Get-QuadrantRects([int]$w, [int]$h, [int]$overlap) {
  if ($w -lt 2 -or $h -lt 2) { return @{ Rects = @(); Count = 0; Error = "degenerate image ${w}x${h}" } }
  $hw = [int][math]::Ceiling($w / 2); $hh = [int][math]::Ceiling($h / 2)
  $ov = $overlap
  if ($ov -lt 0) { $ov = 0 }
  $cap = [math]::Min($hw, $hh) - 1
  if ($ov -gt $cap) { $ov = $cap }
  $xs = @(0, [math]::Max(0, $hw - $ov))
  $ys = @(0, [math]::Max(0, $hh - $ov))
  $rects = New-Object System.Collections.ArrayList
  foreach ($y in $ys) {
    foreach ($x in $xs) {
      $ex = $hw; if ($x -ne 0) { $ex = $w }
      $ey = $hh; if ($y -ne 0) { $ey = $h }
      [void]$rects.Add((New-Object System.Drawing.Rectangle($x, $y, ($ex - $x), ($ey - $y))))
    }
  }
  return @{ Rects = @($rects); Count = @($rects).Count; Error = '' }
}

# Ladder pass 2: read the image in four un-upscaled overlapping crops and merge. This is
# the pass that finds text a whole-image read drops, because the engine spends its
# geometry on less ground at once WITHOUT being resampled first.
function Invoke-OcrFileQuadrants([string]$Path, [int]$maxTiles) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $notes = New-Object System.Collections.ArrayList
  $plan = Get-QuadrantRects 0 0 0
  $bmp = $null
  try {
    $bmp = New-Object System.Drawing.Bitmap((Get-Item -LiteralPath $Path).FullName)
    $plan = Get-QuadrantRects ([int]$bmp.Width) ([int]$bmp.Height) 64
  } catch {
    if ($null -ne $bmp) { $bmp.Dispose() }
    return @{ Lines = @(); Tiles = 0; Ms = 0; Scale = 1.0; Duplicates = 0; Notes = @('quadrants: image could not be opened') }
  }
  try {
    if ($plan.Error) { return @{ Lines = @(); Tiles = 0; Ms = $sw.Elapsed.TotalMilliseconds; Scale = 1.0; Duplicates = 0; Notes = @($plan.Error) } }
    if ($plan.Count -gt $maxTiles) {
      return @{ Lines = @(); Tiles = 0; Ms = $sw.Elapsed.TotalMilliseconds; Scale = 1.0; Duplicates = 0;
        Notes = @("quadrants needs $($plan.Count) tiles > --max-tiles $maxTiles; raise --max-tiles or pass --no-tile") }
    }
    $lists = New-Object System.Collections.ArrayList
    $k = 0
    foreach ($r in $plan.Rects) {
      $k++
      try {
        $crop = $bmp.Clone($r, $bmp.PixelFormat)
        try { [void]$lists.Add(@((Invoke-OcrBitmap $crop).Lines)) } finally { $crop.Dispose() }
      } catch {
        [void]$notes.Add("[quadrant $k failed: $($_.Exception.Message)]")
        [void]$lists.Add(@())
      }
    }
    $m = Merge-OcrTileLines $lists
    return @{ Lines = @($m.Lines); Tiles = $plan.Count; Ms = $sw.Elapsed.TotalMilliseconds; Scale = 1.0; Duplicates = $m.Duplicates; Notes = @($notes) }
  } finally { $bmp.Dispose() }
}

# Pure: may the file ladder pay for its 2x first rung on a WxH image? The engine does not
# return an empty read for an oversized bitmap, it THROWS (measured 2026-10-05 with a
# 6000x200 PNG whose 1x read came back empty: "Image dimensions are too large! Check
# MaxImageDimension", the whole command ERROR exit 1, and rung 2 - the pass built exactly
# for wide images - never ran). So a rung that cannot fit is skipped and says why; an
# unknown cap counts as "cannot fit", because claiming a fit we did not measure is how
# the silent-skip bug lived here since v2.8.1.
function Get-OcrFileRung1Fit([int]$w, [int]$h, [long]$maxDim) {
  if ($maxDim -le 0) { return @{ Fits = $false; Why = 'engine MaxImageDimension unknown' } }
  $rung1W = [long]$w * 2
  $rung1H = [long]$h * 2
  if (($rung1W -le $maxDim) -and ($rung1H -le $maxDim)) { return @{ Fits = $true; Why = '' } }
  return @{ Fits = $false; Why = "${w}x${h} doubled is ${rung1W}x${rung1H}, over the engine limit ${maxDim}" }
}

# The ladder itself. Returns @{ Lines; Report; Scale; Tiles; Ms } where Report names every
# pass that ran and what it produced - including zeros, and including a pass that was
# skipped because --max-tiles refused it or because the engine limit ruled it out.
# Callers print Report verbatim.
function Invoke-OcrFileRetryLadder([string]$Path, [int]$maxTiles, [long]$capDim = -1) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  if ($capDim -lt 0) { $capDim = Get-OcrMaxDimension }
  $rung1 = @{ Fits = $true; Why = '' }
  $probe = $null
  try {
    $probe = New-Object System.Drawing.Bitmap((Get-Item -LiteralPath $Path).FullName)
    $rung1 = Get-OcrFileRung1Fit ([int]$probe.Width) ([int]$probe.Height) $capDim
  } catch {
    # An image that will not open is rung 1's own error to report - turning it into a
    # skipped rung would trade one clear failure for two confusing empty reads.
  } finally {
    if ($null -ne $probe) { $probe.Dispose() }
  }
  $p1Lines = @()
  if ($rung1.Fits) {
    $p1 = Invoke-OcrFile $Path 2.0
    $n1 = @($p1.Lines).Count
    $report = "whole@2x=$n1 line(s)"
    if ($n1 -gt 0) {
      return @{ Lines = @($p1.Lines); Report = $report; Scale = 2.0; Tiles = 0; Ms = $sw.Elapsed.TotalMilliseconds }
    }
    $p1Lines = @($p1.Lines)
  } else {
    $report = "whole@2x=skipped ($($rung1.Why))"
  }
  $p2 = Invoke-OcrFileQuadrants $Path $maxTiles
  $n2 = @($p2.Lines).Count
  if ($n2 -ge 0 -and $p2.Tiles -gt 0) {
    $report += ", quadrants@1x=$n2 line(s) ($($p2.Tiles) tiles)"
  } else {
    $report += ", quadrants@1x=skipped"
  }
  if (@($p2.Notes).Count -gt 0) { $report += ' ' + (@($p2.Notes) -join ' ') }
  $best = $p2
  if (($n2 -eq 0) -and $rung1.Fits) { $best = @{ Lines = $p1Lines; Scale = 2.0; Tiles = 0 } }
  return @{ Lines = @($best.Lines); Report = $report; Scale = [double]$best.Scale; Tiles = [int]$best.Tiles; Ms = $sw.Elapsed.TotalMilliseconds }
}

# Pure tiling planner (v1.5.0 WP-1): splits a source region into overlapping
# tiles such that EVERY tile scaled up by $scale stays within the OCR engine's
# dimension limit. Row-major from (0,0) so --index n is reproducible; the last
# tile column/row snaps to the region edge so the union always covers.
# Returns a hashtable: @{ Tiles = <pscustomobject X;Y;W;H[] region-relative>;
# Count; Covered; Error } - on Error there are no Tiles and the message is
# meant to be quoted verbatim to the user.
function Get-OcrTilePlan([int]$w, [int]$h, [double]$scale, [long]$maxDim, [int]$overlapPx, [int]$maxTiles) {
  $err = ''
  $tiles = New-Object System.Collections.ArrayList
  $covered = $false
  if ($w -le 0 -or $h -le 0) {
    $err = "degenerate region ${w}x${h}"
  } elseif ($scale -le 0) {
    $err = "scale must be > 0, got $scale"
  } elseif ($maxDim -le 0) {
    $err = 'OCR engine dimension limit unknown (engine unavailable)'
  } else {
    $tileDim = [int][math]::Floor($maxDim / $scale)
    $tw = [math]::Min($tileDim, $w)
    $th = [math]::Min($tileDim, $h)
    $strideX = $tw - $overlapPx
    $strideY = $th - $overlapPx
    if ($strideX -lt 1 -or $strideY -lt 1) {
      $err = "overlap ${overlapPx}px leaves no stride (tile ${tw}x${th} at scale $scale); reduce --scale or the overlap"
    } else {
      # edge-snapped axis positions: 0, stride, stride*2, ... then snap the last
      # one so the final tile reaches the far edge (dedup keeps Count exact)
      $xs = New-Object System.Collections.ArrayList
      $p = 0
      while ($p + $tw -lt $w) { [void]$xs.Add($p); $p += $strideX }
      $lastX = [math]::Max(0, $w - $tw)
      if (-not $xs.Contains($lastX)) { [void]$xs.Add($lastX) }
      $ys = New-Object System.Collections.ArrayList
      $p = 0
      while ($p + $th -lt $h) { [void]$ys.Add($p); $p += $strideY }
      $lastY = [math]::Max(0, $h - $th)
      if (-not $ys.Contains($lastY)) { [void]$ys.Add($lastY) }
      $count = $xs.Count * $ys.Count
      if ($count -gt $maxTiles) {
        $err = "tiled retry needs $count tiles (region ${w}x${h} at scale $scale, tile ${tw}x${th}, stride ${strideX}x${strideY}) > --max-tiles $maxTiles; narrow the region or pass --scale 1 / --max-tiles n"
      } else {
        foreach ($y in $ys) { foreach ($x in $xs) {
          [void]$tiles.Add([pscustomobject]@{ X = [int]$x; Y = [int]$y; W = $tw; H = $th })
        } }
        # full cartesian grid: 2D coverage == X-axis cover AND Y-axis cover
        $coverX = $true
        $sx = @($xs | Sort-Object)
        if ($sx[0] -ne 0 -or ($sx[$sx.Count - 1] + $tw) -lt $w) { $coverX = $false }
        for ($i = 1; $i -lt $sx.Count; $i++) { if (($sx[$i] - $sx[$i - 1]) -gt $tw) { $coverX = $false } }
        $coverY = $true
        $sy = @($ys | Sort-Object)
        if ($sy[0] -ne 0 -or ($sy[$sy.Count - 1] + $th) -lt $h) { $coverY = $false }
        for ($i = 1; $i -lt $sy.Count; $i++) { if (($sy[$i] - $sy[$i - 1]) -gt $th) { $coverY = $false } }
        $covered = $coverX -and $coverY
      }
    }
  }
  return @{ Tiles = $tiles; Count = $tiles.Count; Covered = $covered; Error = $err }
}

# Merge per-tile OCR line lists into one screen-space list, dropping duplicates
# from tile overlap: same normalized text AND centres within +/-3 source px
# (screen px == source px after mapping) -> keep the FIRST occurrence; the
# row-major tile order makes that deterministic. Exact pairwise compare, not a
# grid bucket - two centres 2px apart must merge even across a bucket edge.
# Returns hashtable @{ Lines = ArrayList; Duplicates = int }.
function Merge-OcrTileLines($tileLineLists) {
  $lines = New-Object System.Collections.ArrayList
  $dups = 0
  foreach ($list in @($tileLineLists)) {
    foreach ($ln in @($list)) {
      if ($null -eq $ln) { continue }
      $hay = Normalize-OcrText $ln.Text
      $cx = $ln.X + $ln.W / 2.0
      $cy = $ln.Y + $ln.H / 2.0
      $dup = $false
      foreach ($keep in $lines) {
        if ($ln.X -eq $keep.X -and $ln.Y -eq $keep.Y -and $ln.Text -eq $keep.Text) { $dup = $true; break }
        if ((Normalize-OcrText $keep.Text) -eq $hay -and
            [math]::Abs(($keep.X + $keep.W / 2.0) - $cx) -le 3.0 -and
            [math]::Abs(($keep.Y + $keep.H / 2.0) - $cy) -le 3.0) { $dup = $true; break }
      }
      if ($dup) { $dups++ } else { [void]$lines.Add($ln) }
    }
  }
  return @{ Lines = $lines; Duplicates = $dups }
}

# MaxImageDimension is a STATIC property of the OcrEngine class - accessing it
# on an engine INSTANCE silently yields $null in PowerShell, which made every
# Test-OcrRetryFits caller see an unknown limit and silently skip the 2x retry
# from v1.3.1 until v1.5.0 (found live: whole-window find-text on a 2482x1514
# window reported "engine unavailable" while OCR itself worked fine).
function Get-OcrMaxDimension {
  try {
    $null = [Windows.Media.Ocr.OcrEngine,Windows.Media.Ocr,ContentType=WindowsRuntime]
    return [long][Windows.Media.Ocr.OcrEngine]::MaxImageDimension
  } catch { return 0L }
}

# Tiled OCR over ONE in-memory 1:1 region bitmap (v1.5.0 WP-1). The plan comes
# from Get-OcrTilePlan; each tile is cropped from the canvas, OCR'd at $scale,
# and mapped to screen as screen = (originX + tile.X + px/scale, ...) - a
# single offset per tile, never a second one. A tile that fails to OCR is
# recorded and treated as empty (DWM edge of a transient window) instead of
# killing the whole pass. Returns hashtable @{ Lines; Tiles; Ms; Duplicates;
# Notes } with Notes listing failed tiles verbatim for the caller's echo.
function Invoke-OcrBitmapTiled([System.Drawing.Bitmap]$canvas, [int]$srcW, [int]$srcH, [double]$scale, [int]$maxTiles, [int]$originX, [int]$originY, [long]$maxDimOverride = 0) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $maxDim = 0
  try { $maxDim = Get-OcrMaxDimension } catch { $maxDim = 0 }
  # v2.8.0: the planner only subdivides to stay under the ENGINE's dimension limit, which on
  # this machine is 10000 - far above any capture a screen produces, so tiling a screenshot
  # would always be one tile and "tiled" would mean nothing. An override lets a caller ask
  # for subdivision as a READING strategy (smaller area per pass = more detail per pixel of
  # the recognizer's budget), which is the only thing that recovered the dropouts found in
  # the 489-capture survey. It may only ever SHRINK the limit: the engine limit still binds.
  if ($maxDimOverride -gt 0 -and ($maxDim -le 0 -or $maxDimOverride -lt $maxDim)) { $maxDim = $maxDimOverride }
  $plan = Get-OcrTilePlan $srcW $srcH $scale $maxDim 64 $maxTiles
  if ($plan.Error) {
    return @{ Lines = (New-Object System.Collections.ArrayList); Tiles = 0; Ms = $sw.Elapsed.TotalMilliseconds; Duplicates = 0; Notes = @($plan.Error) }
  }
  $lists = New-Object System.Collections.ArrayList
  $notes = New-Object System.Collections.ArrayList
  $k = 0
  foreach ($tile in $plan.Tiles) {
    $k++
    try {
      $cropRect = New-Object System.Drawing.Rectangle($tile.X, $tile.Y, $tile.W, $tile.H)
      $crop = $canvas.Clone($cropRect, $canvas.PixelFormat)
      $up = $null
      try {
        # v1.5.0 WP-5 self-corrected defect: the tile MUST be upscaled by
        # $scale before OCR (tileDim already accounts for it), otherwise the
        # px/scale mapping halves every coordinate and the "2x read" at the
        # heart of tiling never actually happens.
        $srcBmp = $crop
        if ($scale -ne 1.0) {
          $up = New-Object System.Drawing.Bitmap([int]($tile.W * $scale), [int]($tile.H * $scale))
          $gU = [System.Drawing.Graphics]::FromImage($up)
          # NearestNeighbor, deliberately: same crisp-scaling idiom as `zoom`
          # (integer 2x blocks are the right texture for text OCR). Note: the
          # Windows OCR engine can still jitter line bboxes (up to ~+90px) on
          # tiles whose upscaled size sits exactly at MaxImageDimension in
          # DPI-aware hosts - an engine artifact outside our mapping math
          # (pixel-verified); the live tests allow for it explicitly.
          $gU.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
          $gU.DrawImage($crop, 0, 0, $up.Width, $up.Height)
          $gU.Dispose()
          $srcBmp = $up
        }
        $r = Invoke-OcrBitmap $srcBmp
        $mapped = New-Object System.Collections.ArrayList
        foreach ($ln in $r.Lines) {
          [void]$mapped.Add([pscustomobject]@{
            Text = $ln.Text
            X = $originX + $tile.X + [int][math]::Round($ln.X / $scale)
            Y = $originY + $tile.Y + [int][math]::Round($ln.Y / $scale)
            W = [int][math]::Round($ln.W / $scale)
            H = [int][math]::Round($ln.H / $scale)
          })
        }
        [void]$lists.Add($mapped)
      } finally { if ($null -ne $up) { $up.Dispose() }; $crop.Dispose() }
    } catch {
      [void]$notes.Add("[tile $k failed: $($_.Exception.Message)]")
      [void]$lists.Add((New-Object System.Collections.ArrayList))
    }
  }
  $m = Merge-OcrTileLines $lists
  return @{ Lines = $m.Lines; Tiles = $plan.Count; Ms = $sw.Elapsed.TotalMilliseconds; Duplicates = $m.Duplicates; Notes = $notes }
}

# Screen wrapper: ONE atomic 1:1 grab of the whole region, then tiled OCR from
# memory (per-tile screen grabs would see different moments and cost N times
# the capture). Returns hashtable @{ Lines; Tiles; Ms; Duplicates; Notes }.
function Invoke-OcrRegionTiled([int]$x, [int]$y, [int]$w, [int]$h, [double]$scale, [int]$maxTiles) {
  $cap = Get-ScreenBitmap $x $y $w $h 1.0
  try {
    return Invoke-OcrBitmapTiled $cap.Bitmap $w $h $scale $maxTiles $x $y
  } finally { $cap.Bitmap.Dispose() }
}

# Windows OCR puts a space between every pair of CJK glyphs, so a line that
# reads two ideographs with an invented gap between them never contains the
# natural two-character needle - which silently broke find-text / assert-text
# / menu-pick on every Chinese UI (verified live: the unspaced needle misses,
# the spaced one hits). Strip spaces that sit between two CJK code points, on
# BOTH sides, so callers can write natural needles. English word structure is
# left untouched: only CJK-CJK gaps collapse. (This comment is ASCII on
# purpose - the selftest lint forbids non-ASCII in this file, and it caught
# exactly that here.)
function Normalize-OcrText([string]$s) {
  if (-not $s) { return '' }
  # Dash confusables first: Windows OCR renders a typed ASCII hyphen as
  # U+2014/U+2013 in terminal text (seen live: HELLO-VERIFY-TEST came back as
  # HELLO<U+2014>VERIFY<U+2014>TEST), which made every hyphenated needle miss.
  $t = [regex]::Replace($s, '[\u2010-\u2015\u2212\uFF0D]', '-')
  # Fullwidth punctuation confusables (audit 2026-09-29b #7): OCR renders
  # "100,000,000" as "100<U+FF0C>000" and dots as U+FF0E (seen live in MAC
  # address tables). Fold them to ASCII on BOTH sides - needle and haystack get
  # the same treatment, so matching stays consistent.
  $t = [regex]::Replace($t, '[\uFF0C]', ',')
  $t = [regex]::Replace($t, '[\uFF0E]', '.')
  $t = [regex]::Replace($t, '[\uFF1A]', ':')
  $t = [regex]::Replace($t, '[\uFF1B]', ';')
  $t = [regex]::Replace($t, '[\uFF01]', '!')
  $t = [regex]::Replace($t, '[\uFF1F]', '?')
  # The fullwidth originals carried glyph padding: OCR emits spaces hugging the
  # punctuation ("100 , 000"). Collapse those on both sides too, or the folded
  # comma still will not match a dense needle like 100,000,000.
  $t = [regex]::Replace($t, ' *([,.;:!?]) *', '$1')
  $cjk = '[\u3000-\u303F\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF\uFF00-\uFFEF]'
  $pat = '(?<=' + $cjk + ') +(?=' + $cjk + ')'
  $prev = ''
  while ($prev -ne $t) {
    $prev = $t
    $t = [regex]::Replace($t, $pat, '')
  }
  return $t
}

# Case-insensitive substring match of the needle over OCR'd lines; a hit is the
# whole line (its rect is the row - exactly what menu/list picking needs).
# Returns an ArrayList - callers assign it DIRECTLY (no @() wrapper: @() around
# a comma-wrapped function call yields Object[1]{ArrayList} in PS 5.1, which
# broke every Count/hit check once).
# v1.5.2 WP-5 (audit R-10): the SECOND pass for OCR confusables.
# Deliberately tiny and deliberately separate from Normalize-OcrText: folding
# broadens matching, and a broadened match that is presented as an exact one is
# exactly the false green this tool's guards exist to prevent. So the fold lives
# here, Find-OcrHits only applies it when the exact pass found nothing, and every
# echo has to say 'matched via confusable-fold' (Get-OcrFoldMarker).
# The set is what was measured on this machine, nothing more:
#   I / l / 1 / |   - 'QX7AUDITBEGIN' read as 'QX7AUDlTBEGlN',
#                     'DTX-AuditInput' read as 'DTX-Auditlnput'
#   O / 0           - 'QXHELLO123' read as 'QXHELL01231'
# NOT folded (would create real ambiguity for no measured gain): S/5, Z/2, B/8,
# G/6, and never any CJK character.
function Convert-ConfusableFold([string]$s) {
  if (-not $s) { return '' }
  $t = Normalize-OcrText $s
  $t = $t -replace '[Il1|]', 'l'
  $t = $t -replace '[Oo0]', 'o'
  return $t
}

# The marker every echo must print when the hit only exists after folding.
# Returns '' for exact hits so the normal output shape does not change.
function Get-OcrFoldMarker($hits) {
  $folded = @($hits | Where-Object { $_.PSObject.Properties['Folded'] -and $_.Folded -eq $true })
  if (@($hits).Count -eq 0) { return '' }
  return (Get-FoldMarkerFromCounts @($folded).Count @($hits).Count)
}

# v3.0.0: the fold marker WORDING, split out of Get-OcrFoldMarker so a caller that already
# reduced hits to counts (the expect proof line) goes through the same producer instead of
# handwriting a second copy that can quietly stop being true.
# Splitting it out is ALSO the fix for a shipped defect found while writing this: the old
# partial branch was " [$$($folded.Count) of ...]", and `$$(` in a double-quoted string is
# NEITHER an escape NOR a subexpression - it stringifies the ARRAY and appends a literal
# ".Count", so a 2-of-5 partial fold rendered "[lineA lineB.Count of 5 matched via
# confusable-fold ...]". The marker whose only job is to be honest was lying, and no check
# covered the partial branch's rendered line (the all-folded branch used no interpolation,
# which is why it looked fine). Same family as v2.0.1's "$g.Warn printed Hashtable.Warn".
function Get-FoldMarkerFromCounts([int]$folded, [int]$total) {
  if ($total -eq 0) { return '' }
  if ($folded -eq 0) { return '' }
  if ($folded -eq $total) { return ' [matched via confusable-fold - not an exact read]' }
  return " [$folded of $total matched via confusable-fold - not an exact read]"
}

# v1.5.7 (J-05, owner ruling option C): hit GRANULARITY stays line-level on purpose -
# word-level hits would turn "the same text twice on one line" from 1 hit into 2 and break
# every script that passes --index. What was asked for instead is that the tool SAY so when
# the number a reader sees cannot be the number of things on screen. Pure over (needle,
# hits) so both directions are testable offline; matching uses the same Normalize-OcrText
# basis as Find-OcrHits, otherwise the count and the hit could disagree.
function Format-MultiOccurrenceHint([string]$needle, $hits) {
  $hs = @($hits)
  if ($hs.Count -eq 0 -or -not $needle) { return '' }
  $want = Normalize-OcrText $needle
  if (-not $want) { return '' }
  $occ = 0
  foreach ($h in $hs) {
    $hay = Normalize-OcrText "$($h.Text)"
    if (-not $hay) { continue }
    $pos = 0
    while ($occ -le 999) {
      $ix = $hay.IndexOf($want, $pos, [System.StringComparison]::OrdinalIgnoreCase)
      if ($ix -lt 0) { break }
      $occ++
      $pos = $ix + $want.Length
    }
  }
  if ($occ -le $hs.Count) { return '' }
  return "hint: the needle occurs $occ time(s) inside $($hs.Count) hit line(s) - a hit is ONE LINE: the same text twice on one line is still one hit, and --index selects lines, not occurrences (line granularity is the J-05 ruling, not a limit of this scan)"
}

# v1.5.2 (audit R-08): ONE flag grammar for every command that takes a needle.
# Each of these commands had its own loop that pushed any token it did not
# recognise into the positional words, so `find-text X --expct Y` silently
# searched for the literal '--expct' instead of failing: a mistyped safety flag
# degraded into a different search. That is the same "unknown flag degrades into
# real action" family this tool has been closing since v1.3.0, and fixing only
# one command would leave the family with two parsing phases again.
# Grammar (documented in README and help, each branch pinned by a selftest case):
#   <text>              plain positional token (the usual needle)
#   --needle <text>     explicit needle - never guessed, never ambiguous; the
#                       only route for text that starts with --, and the
#                       recommended form inside script steps (a JSON field, so
#                       the shell quoting layer never touches it)
#   --<anything else>   a flag - if the command does not implement exactly that
#                       spelling, it THROWS instead of being silently searched
# A lone -- terminator is deliberately NOT supported: powershell.exe consumes it
# at its own parameter-binding layer (it answers "parameter name '--' is
# ambiguous" and this parser never runs), so the feature would be reachable only
# from inside tests. It was built, measured, and removed again for that reason.
function Resolve-NeedleToken([string]$tok) {
  if ($tok -ceq '--needle') { return @{ Kind = 'explicit' } }
  if ($tok -like '--*') { return @{ Kind = 'unknown' } }
  return @{ Kind = 'literal' }
}

# The one error message every needle command throws with. Kept as a function so
# the wording cannot drift between commands (task order, R-08 side requirement:
# no second parsing phase). It names the single reachable escape route.
function Get-NeedleFlagError([string]$cmd, [string]$tok) {
  return "$cmd : unknown flag '$tok' - flags must be spelled exactly (see 'desktop.ps1 help'). To search for text that starts with --, pass it as --needle <text>."
}

# v1.5.9 (P-2): find-click used to click the HIT LINE's centre. A real incident
# (2026-09-30): two adjacent tabs were OCR'd as one spaced-out line of seven CJK
# words, the centre landed in the dead zone BETWEEN the tabs, and the echo reported
# hit 1/1 + clicked while the interface did nothing. The fix maps the needle's
# character span in the NORMALIZED line text (the same Normalize-OcrText the
# matcher used to find it) linearly onto the line rect and aims at that sub-span's
# centre. Count-fraction -> width-fraction is an approximation (no per-glyph rects
# at this stage), but its error is bounded by the inter-word slack, while the line
# centre error grows with every character the needle does not cover.
# Hit GRANULARITY IS UNCHANGED (J-05 ruling): this decides WHERE to click inside a
# line, never HOW MANY lines matched. --aim-line restores the old centre behaviour.
# Pure: returns @{ Matched; AimX; SpanStart; SpanEnd; NormLen } - Matched=$false
# means the needle is not locatable in the line text (e.g. a confusable-folded
# match); the caller then falls back to the line centre and says so in the echo.
function Get-NeedleAimX([string]$lineText, [int]$lineX, [int]$lineW, [string]$needle) {
  $hay = Normalize-OcrText "$lineText"
  $want = Normalize-OcrText "$needle"
  $miss = @{ Matched = $false; AimX = ($lineX + [int]($lineW / 2)); SpanStart = 0; SpanEnd = 0; NormLen = $hay.Length }
  if (-not $hay -or -not $want) { return $miss }
  $ix = $hay.IndexOf($want, [System.StringComparison]::OrdinalIgnoreCase)
  if ($ix -lt 0) { return $miss }
  $x0 = $lineX + [int]($lineW * ($ix / $hay.Length))
  $x1 = $lineX + [int]($lineW * (($ix + $want.Length) / $hay.Length))
  return @{ Matched = $true; AimX = ($x0 + [int](($x1 - $x0) / 2)); SpanStart = $ix; SpanEnd = ($ix + $want.Length); NormLen = $hay.Length }
}

function Find-OcrHits($lines, [string]$needle) {
  # v3.0.1 (audit #11): IndexOf('') is 0, so an empty needle matches EVERY OCR line -
  # a caller that forgets its own guard gets "the whole screen matched" in a perfectly
  # normal-shaped result. Every command path that reaches here refuses an empty needle
  # today (find-text/read-text/assert-text/find-click/menu-pick/--filter), so this is
  # unreachable from the CLI: it is the same refusal Get-NeedleAimX carries, placed one
  # level down where the next caller cannot miss it. Thrown, not answered with an empty
  # list, because "no hits" and "you asked nothing" are different facts.
  if ("$needle" -eq '') { throw 'Find-OcrHits: empty needle - an empty substring matches every line, so a hit would prove nothing' }
  $hits = New-Object System.Collections.ArrayList
  $want = Normalize-OcrText $needle
  foreach ($ln in $lines) {
    if ($null -eq $ln) { continue }
    $t = $ln.Text
    if (-not $t) { continue }
    $hay = Normalize-OcrText $t
    if ($hay.IndexOf($want, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { [void]$hits.Add($ln) }
  }
  if ($hits.Count -eq 0) {
    # second pass only - an exact hit never gets marked, so nothing downstream
    # can mistake the broadened match for a confirmed read
    $wantFold = Convert-ConfusableFold $needle
    if ($wantFold) {
      foreach ($ln in $lines) {
        if ($null -eq $ln) { continue }
        $t = $ln.Text
        if (-not $t) { continue }
        $hayFold = Convert-ConfusableFold $t
        if ($hayFold.IndexOf($wantFold, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
          [void]$ln.PSObject.Properties.Add((New-Object System.Management.Automation.PSNoteProperty('Folded', $true)))
          [void]$hits.Add($ln)
        }
      }
    }
  }
  return ,$hits
}

# Can a 2x upscale of this region still satisfy the OCR engine? Windows OCR
# refuses bitmaps whose widest side exceeds OcrEngine.MaxImageDimension (probed
# at 10000 on this machine). The old hardcoded 2200/1200 guard was SMALLER than
# real windows (ZCode 2361x1469), so whole-window searches silently never
# retried while the miss message claimed they had - the worst kind of lie
# because it made the agent believe every avenue was exhausted (audit
# 2026-09-29b #1). Pure function so selftest can pin the decision.
function Test-OcrRetryFits([int]$w, [int]$h, [long]$maxDim) {
  if ($maxDim -le 0) { return $false }
  return (($w * 2) -le $maxDim) -and (($h * 2) -le $maxDim)
}

# OCR-then-match with one upscale retry, for every needle-based command.
#
# Windows OCR collapses on small glyphs - verified live, 17px terminal text came
# back as "DTVER I FY ... Ok ... 4271" with the hyphens turned into spaces and
# CJK strokes - and Invoke-OcrRegion's auto upscale keys off REGION height, so a
# large window of small text is never enlarged and the caller gets a false
# "not found". Retry the same region at 2x when the 1x pass finds nothing: costs
# one extra OCR pass only on a miss, and only when the doubled region still fits
# the engine's dimension limit (Retried=false otherwise - callers must report
# that honestly instead of claiming a retry happened).
#
# Returns a hashtable (not a list) so callers cannot fall into the @() trap:
#   Hits     ArrayList of matching lines (screen-space rects)
#   Lines    the OCR lines the verdict was based on (for "Visible:" reporting)
#   Scaled   whether the verdict came from the 2x pass
#   Retried  whether a 2x pass ran at all (miss messages quote this verbatim)
# OCR-then-match with the v1.5.0 scale decision tree. Backward compatible with
# v1.4.1: same first five keys, only NEW keys added (Tiled, TileCount, Note,
# Ms). Decision order per the v1.5.0 task order (WP-1 2.4):
#   1x fast path -> hit? done.
#   --scale 1 or --no-tile  -> never retry (v1.4.1 --no-tile keeps the
#                              Test-OcrRetryFits single-2x pass for contrast).
#   --scale 2 | tiled       -> straight to tiled (skips Test-OcrRetryFits).
#   auto                    -> whole-region 2x when it fits the engine limit
#                              (zero regression vs v1.4.x), else tiled.
# Keys: Hits; Lines (the lines the verdict used - miss messages quote the 1x
# view); Scaled (verdict from an upscaled pass); Retried (any retry ran);
# Tiled (retry was tiled); TileCount; Note (machine-usable refusal/notes);
# Ms (tiled wall time).
function Find-OcrHitsScaled([int]$x, [int]$y, [int]$w, [int]$h, [string]$needle, [string]$scaleMode = 'auto', [int]$maxTiles = 16, [bool]$noTile = $false) {
  $l1 = Invoke-OcrRegion $x $y $w $h
  $h1 = Find-OcrHits $l1 $needle
  if ($h1.Count -gt 0) { return @{ Hits = $h1; Lines = $l1; Scaled = $false; Retried = $false; Tiled = $false; TileCount = 0; Note = ''; Ms = 0.0 } }
  if ($scaleMode -eq '1') { return @{ Hits = $h1; Lines = $l1; Scaled = $false; Retried = $false; Tiled = $false; TileCount = 0; Note = 'retry SKIPPED by flag'; Ms = 0.0 } }
  if ($scaleMode -eq '2' -or $scaleMode -eq 'tiled') {
    $t = Invoke-OcrRegionTiled $x $y $w $h 2.0 $maxTiles
    if ($t.Tiles -eq 0) { return @{ Hits = $h1; Lines = $l1; Scaled = $false; Retried = $false; Tiled = $false; TileCount = 0; Note = (@($t.Notes) -join ' '); Ms = $t.Ms } }
    $h2 = Find-OcrHits $t.Lines $needle
    if ($h2.Count -gt 0) { return @{ Hits = $h2; Lines = $t.Lines; Scaled = $true; Retried = $true; Tiled = $true; TileCount = $t.Tiles; Note = ''; Ms = $t.Ms } }
    return @{ Hits = $h1; Lines = $l1; Scaled = $false; Retried = $true; Tiled = $true; TileCount = $t.Tiles; Note = (@($t.Notes) -join ' '); Ms = $t.Ms }
  }
  if ($noTile) {
    # explicit v1.4.1 contrast mode: single-2x when it fits, otherwise skip
    $maxDim = 0
    try { $maxDim = Get-OcrMaxDimension } catch { $maxDim = 0 }
    if (Test-OcrRetryFits $w $h $maxDim) {
      $l2 = Invoke-OcrRegion $x $y $w $h 2.0
      $h2 = Find-OcrHits $l2 $needle
      if ($h2.Count -gt 0) { return @{ Hits = $h2; Lines = $l2; Scaled = $true; Retried = $true; Tiled = $false; TileCount = 1; Note = ''; Ms = 0.0 } }
      return @{ Hits = $h1; Lines = $l1; Scaled = $false; Retried = $true; Tiled = $false; TileCount = 1; Note = ''; Ms = 0.0 }
    }
    return @{ Hits = $h1; Lines = $l1; Scaled = $false; Retried = $false; Tiled = $false; TileCount = 0; Note = 'retry SKIPPED by flag'; Ms = 0.0 }
  }
  # auto: single 2x when the doubled region fits, else tiled
  $maxDim = 0
  try { $maxDim = Get-OcrMaxDimension } catch { $maxDim = 0 }
  if (Test-OcrRetryFits $w $h $maxDim) {
    $l2 = Invoke-OcrRegion $x $y $w $h 2.0
    $h2 = Find-OcrHits $l2 $needle
    if ($h2.Count -gt 0) { return @{ Hits = $h2; Lines = $l2; Scaled = $true; Retried = $true; Tiled = $false; TileCount = 1; Note = ''; Ms = 0.0 } }
    return @{ Hits = $h1; Lines = $l1; Scaled = $false; Retried = $true; Tiled = $false; TileCount = 1; Note = ''; Ms = 0.0 }
  }
  $t = Invoke-OcrRegionTiled $x $y $w $h 2.0 $maxTiles
  if ($t.Tiles -eq 0) { return @{ Hits = $h1; Lines = $l1; Scaled = $false; Retried = $false; Tiled = $false; TileCount = 0; Note = (@($t.Notes) -join ' '); Ms = $t.Ms } }
  $h2 = Find-OcrHits $t.Lines $needle
  if ($h2.Count -gt 0) { return @{ Hits = $h2; Lines = $t.Lines; Scaled = $true; Retried = $true; Tiled = $true; TileCount = $t.Tiles; Note = ''; Ms = $t.Ms } }
  return @{ Hits = $h1; Lines = $l1; Scaled = $false; Retried = $true; Tiled = $true; TileCount = $t.Tiles; Note = (@($t.Notes) -join ' '); Ms = $t.Ms }
}

# Three-state retry verdict for miss messages (v1.5.0 WP-1 2.6) - must match
# what Find-OcrHitsScaled actually did, never claim more than ran.
function Format-OcrRetryNote($f) {
  if ($f.Retried) {
    if ($f.Tiled) {
      $n = if ($f.Note) { ' ' + $f.Note } else { '' }
      return "retried at 2x across $($f.TileCount) tile(s) in $([math]::Round($f.Ms / 1000.0, 1)) s$n"
    }
    return 'also retried at 2x'
  }
  if ($f.Note -and $f.Note -match 'needs \d+ tiles') { return "tiled retry REFUSED: $($f.Note)" }
  if ($f.Note) { return $f.Note }
  return 'no retry ran'
}

# <sel> or <x> <y> <w> <h> (starting at word <i>) -> screen-space rect.
# Four integers always win over a selector; use t:<digits> if you ever need a
# digit-only title selector in a position where 4 ints could also parse.
# v1.5.1 WP-A: the resolved window object rides along as .Win (null for the
# raw-quad form) so occlusion checks know the expected pixel owner.
function Resolve-Region([string[]]$words, [int]$i) {
  if ($words.Count -ge ($i + 4)) {
    $quad = @($words[$i..($i + 3)])
    if (@($quad | Where-Object { $_ -match '^-?\d+$' }).Count -eq 4) {
      $w = [int]$quad[2]; $h = [int]$quad[3]
      if ($w -le 0 -or $h -le 0) { throw "region w/h must be positive: $($quad -join ' ')" }
      return @{ X = [int]$quad[0]; Y = [int]$quad[1]; W = $w; H = $h; Win = $null }
    }
  }
  if ($words.Count -ge ($i + 1)) {
    $w = Resolve-Window $words[$i]
    if ($w) { return @{ X = $w.Left; Y = $w.Top; W = $w.W; H = $w.H; Win = $w } }
  }
  throw "expected <sel> or <x> <y> <w> <h>"
}

# How many leading words Resolve-Region consumes at position <i>: 4 for the
# integer-quad form, else 1 (a selector). Needle extraction relies on this.
function Region-WordCount([string[]]$words, [int]$i) {
  if ($words.Count -ge ($i + 4)) {
    $quad = @($words[$i..($i + 3)])
    if (@($quad | Where-Object { $_ -match '^-?\d+$' }).Count -eq 4) { return 4 }
  }
  return 1
}

# MD5 of the PNG bytes of a screen region - the identity used by wait-stable,
# assert-stable and assert-hash ("UI settled" == two consecutive equal hashes).
function Get-RegionHash([int]$x, [int]$y, [int]$w, [int]$h) {
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size($w, $h)))
  $g.Dispose()
  $ms = New-Object System.IO.MemoryStream
  $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  $md5 = [System.Security.Cryptography.MD5]::Create()
  $hash = ([BitConverter]::ToString($md5.ComputeHash($ms.ToArray())) -replace '-', '').ToLower()
  $ms.Dispose(); $md5.Dispose()
  return $hash
}

# ---- v1.10.0: verification-challenge workflow (detect / classify / staleness / ONE
# authorized attempt with a hard fuse / clean handoff to a human). The boundary is
# deliberate, not unfinished (task order 2026-09-30): these challenges exist to stop
# scripted repeated claiming - breaking them escalates the account's risk-control and
# the reward disappears (measured 2026-09-30: the win came from RECOGNIZING an expired
# modal and closing it, never solving). So: no third-party solvers, no generic CAPTCHA
# recognition, no humanized trajectories, no multi-account handling, no attempt without
# the caller's explicit authorization. The corpus lives here and ONLY here; CJK is
# code-point assembled because this file stays pure ASCII beyond its BOM.

function Get-ChallengeCorpus {
  $zhSecure = [string]([char]0x5B89) + [char]0x5168 + [char]0x9A8C + [char]0x8BC1   # secure-verification (4 glyphs)
  $zhDrag = [string]([char]0x62D6) + [char]0x52A8 + [char]0x6ED1 + [char]0x5757   # drag-the-slider (4 glyphs)
  $zhPuzzle = [string]([char]0x62FC) + [char]0x56FE   # jigsaw/puzzle (2 glyphs)
  $zhCaptcha = [string]([char]0x9A8C) + [char]0x8BC1 + [char]0x7801   # verification-code (3 glyphs)
  $zhPlease = [string]([char]0x8BF7) + [char]0x5B8C + [char]0x6210 + $zhSecure   # please-complete-the-secure-verification
  return @(
    @{ Needle = $zhSecure; Kind = 'generic' },
    @{ Needle = $zhPlease; Kind = 'generic' },
    @{ Needle = $zhDrag; Kind = 'slider' },
    @{ Needle = $zhPuzzle; Kind = 'slider' },
    @{ Needle = $zhCaptcha; Kind = 'generic' },
    @{ Needle = 'certifyid'; Kind = 'slider' }
  )
}

# Pure: classify a whole-window OCR read. $lines are screen-space OCR lines (.Text/.X/.Y/.W/.H).
# Returns Challenge/Type/Confidence/Matched/Lines/Handle - the Handle is the FIRST
# slider-kind line's rect (the drag affordance a human needs to be told about).
function Test-ChallengeLines($lines) {
  $rs = @($lines)
  $matched = New-Object System.Collections.ArrayList
  $slider = $false
  $handle = $null
  foreach ($l in $rs) {
    $nm = Normalize-OcrText "$($l.Text)"
    if (-not $nm) { continue }
    foreach ($c in @(Get-ChallengeCorpus)) {
      if ($matched -contains $c.Needle) { continue }
      if ($nm.IndexOf($c.Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        [void]$matched.Add($c.Needle)
        if ($c.Kind -eq 'slider') {
          $slider = $true
          if ($null -eq $handle) { $handle = $l }
        }
      }
    }
  }
  $conf = 'none'
  if (@($matched).Count -ge 2) { $conf = 'high' }
  elseif (@($matched).Count -eq 1) { $conf = 'medium' }
  return @{
    Challenge = (@($matched).Count -gt 0)
    Type = $(if ($slider) { 'slider-captcha' } else { 'challenge-unknown' })
    Confidence = $conf
    Matched = @($matched)
    Lines = $rs.Count
    Handle = $handle
  }
}

# Stable logical identity for a challenge. DWM CopyFromScreen can repaint an
# unchanged window between separate PowerShell processes (focus/compositor noise
# changes pixels without changing the challenge), so the state gate uses only the
# matched challenge corpus, line count, and slider-handle geometry. The digest is
# still opaque in actions.log and never contains page text.
function Get-ChallengeIdentityHash($verdict) {
  $needles = (@($verdict.Matched | Sort-Object) -join '|')
  $handle = 'none'
  if ($null -ne $verdict.Handle) {
    $h = $verdict.Handle
    $handle = "$([int]$h.X),$([int]$h.Y),$([int]$h.W),$([int]$h.H)"
  }
  $canonical = "challenge-v2|type=$($verdict.Type)|confidence=$($verdict.Confidence)|needles=$needles|lines=$($verdict.Lines)|handle=$handle"
  $md5 = [System.Security.Cryptography.MD5]::Create()
  try {
    return ([BitConverter]::ToString($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($canonical))) -replace '-', '').ToLower()
  } finally { $md5.Dispose() }
}

# Pure: staleness verdict from the previously recorded challenge hash. The state store
# is actions.log (this tool is one process per call); the comparison itself is pure.
function Test-ChallengeStale($lastSeenHash, $curHash) {
  if (-not $lastSeenHash) { return @{ Stale = 'first-seen'; Recommend = '' } }
  if ("$lastSeenHash" -eq "$curHash") {
    return @{ Stale = $true; Recommend = 'dismiss-not-solve: try clicking a non-button, non-close area of the modal, then re-check the underlying target - a challenge that has been sitting for minutes is usually an expired ticket, and solving it burns one risk-control attempt' }
  }
  return @{ Stale = $false; Recommend = '' }
}

# Pure: extract this pid's challenge state (last seen hash + armed fuse hash) from
# actions.log lines. Log-Action lines look like: `<ts> UTC | challenge-probe | pid=N ... | seen hash=<hex>`
# The command-name column is what selects the lines, so it has to be the token the
# dispatcher really writes there - renaming the command without renaming this
# filter turns the fuse into a reader that always sees an empty log.
function Test-ChallengeLogLines($lines, [int]$pidToFind) {
  $last = ''; $fuse = ''
  foreach ($ln in @($lines)) {
    $s = "$ln"
    if ($s.IndexOf("| challenge-probe | pid=$pidToFind ") -lt 0) { continue }
    if ($s.IndexOf('seen hash=') -ge 0) {
      $m = [regex]::Match($s, 'seen hash=([0-9a-f]+)')
      if ($m.Success) { $last = $m.Groups[1].Value }
    }
    if ($s.IndexOf('fuse hash=') -ge 0) {
      $m2 = [regex]::Match($s, 'fuse hash=([0-9a-f]+)')
      if ($m2.Success) { $fuse = $m2.Groups[1].Value }
    }
  }
  return @{ LastHash = $last; FuseHash = $fuse }
}

# Pure: what the reader is ALLOWED to claim about this pid's fuse, given how the log read AND the
# sighting write went. The four answers are different facts and must not collapse into one
# another: `absent` = the log has never been written, so "first challenge for this pid" is a true
# statement; `unreadable` = the file is there but THIS call could not read it, which says nothing
# about whether a fuse is armed; `unwritable` = we could read but could not record what we just
# saw, so the fuse cannot be armed for the NEXT call either - same consequence as unreadable.
# Before this, the read carried -ErrorAction SilentlyContinue, so an unreadable log arrived
# downstream as an empty array, was reported as `stale=first-seen`, and cleared the armed fuse -
# a retry that risk-control was supposed to be protected from (v4.0.1 audit, finding 2).
function Resolve-ChallengeLogState([bool]$logExists, [bool]$readOk, [bool]$writeOk = $true) {
  if (-not $logExists) { return 'absent' }
  if (-not $readOk) { return 'unreadable' }
  if (-not $writeOk) { return 'unwritable' }
  return 'ok'
}

# Pure: the human-handoff echo. All four contract fields (type= / rect= / handle: /
# shot:) must be present - the handoff is what the operator reads to take over, and a
# missing field is how "I'll just click it myself" bad guesses start.
function Build-ChallengeHandoff($verdict, $win, $hash8, $shotPath) {
  $handleTxt = 'not-found (no slider-affordance line matched)'
  if ($null -ne $verdict.Handle) {
    $hl = $verdict.Handle
    $handleTxt = "($([int]$hl.X),$([int]$hl.Y)) size=$([int]$hl.W)x$([int]$hl.H)  <- the drag affordance as OCR'd"
  }
  $em = [string][char]0x2014
  $lines = @(
    "challenge handoff: type=$($verdict.Type) window='$($win.Title)' pid=$($win.Pid) rect=($([int]$win.Left),$([int]$win.Top),$([int]$win.W)x$([int]$win.H))",
    "  handle: $handleTxt",
    "  shot: $shotPath",
    "  challenge-image-hash: $hash8",
    "  next: a human completes or dismisses the challenge, then the ORIGINAL command is re-run. Do not re-click cards/buttons first - this action may already have changed their state$em'"
  )
  return $lines
}

# Poll a region until the hash DIFFERS from the entry baseline - the reverse
# of Wait-RegionStable, for "did my click do anything at all" (v1.5.0 WP-2).
# Returns hashtable @{ Changed; Elapsed; From; To }.
function Wait-RegionChanged($region, [double]$timeoutSec, [int]$intervalMs) {
  if ($intervalMs -lt 100) { $intervalMs = 100 }
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $from = Get-RegionHash $region.X $region.Y $region.W $region.H
  while ($sw.Elapsed.TotalSeconds -lt $timeoutSec) {
    Start-Sleep -Milliseconds $intervalMs
    $h = Get-RegionHash $region.X $region.Y $region.W $region.H
    if ($h -ne $from) { return @{ Changed = $true; Elapsed = $sw.Elapsed.TotalSeconds; From = $from; To = $h } }
  }
  return @{ Changed = $false; Elapsed = $sw.Elapsed.TotalSeconds; From = $from; To = $from }
}

# Poll a region until two consecutive captures hash identically. Returns
# @{ Stable; Elapsed; Hash } - wait-stable / assert-stable report it as-is.
function Wait-RegionStable($region, [double]$timeoutSec, [int]$intervalMs) {
  if ($intervalMs -lt 100) { $intervalMs = 100 }
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $prev = $null
  while ($true) {
    $h = Get-RegionHash $region.X $region.Y $region.W $region.H
    if ($null -ne $prev -and $h -eq $prev) {
      return @{ Stable = $true; Elapsed = $sw.Elapsed.TotalSeconds; Hash = $h }
    }
    $prev = $h
    if ($sw.Elapsed.TotalSeconds -ge $timeoutSec) { break }
    Start-Sleep -Milliseconds $intervalMs
  }
  return @{ Stable = $false; Elapsed = $sw.Elapsed.TotalSeconds; Hash = $prev }
}

function Get-PixelHex([int]$x, [int]$y) {
  $bmp = New-Object System.Drawing.Bitmap(1, 1)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size(1, 1)))
  $g.Dispose()
  $c = $bmp.GetPixel(0, 0)
  $bmp.Dispose()
  return "#{0:X2}{1:X2}{2:X2}" -f $c.R, $c.G, $c.B
}

function Convert-HexToRgb([string]$hex) {
  $h = $hex.TrimStart('#')
  if ($h -notmatch '^[0-9a-fA-F]{6}$') { throw "expected #RRGGBB, got: $hex" }
  return @{ R = [Convert]::ToInt32($h.Substring(0, 2), 16); G = [Convert]::ToInt32($h.Substring(2, 2), 16); B = [Convert]::ToInt32($h.Substring(4, 2), 16) }
}

# Scan a region for pixels matching #RRGGBB within +/- tolerance per channel.
# LockBits + one managed copy: GetPixel-per-pixel is far too slow for regions.
function Find-ColorMatches([int]$x, [int]$y, [int]$w, [int]$h, [string]$hex, [int]$tolerance) {
  $rgb = Convert-HexToRgb $hex
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size($w, $h)))
  $g.Dispose()
  $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
  $bd = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $bytes = New-Object byte[] ($bd.Stride * $h)
  [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $bytes, 0, $bytes.Length)
  $bmp.UnlockBits($bd)
  $bmp.Dispose()
  $hits = New-Object System.Collections.ArrayList
  for ($row = 0; $row -lt $h; $row++) {
    $rowOff = $row * $bd.Stride
    for ($col = 0; $col -lt $w; $col++) {
      $o = $rowOff + $col * 4
      if ([math]::Abs($bytes[$o + 2] - $rgb.R) -le $tolerance -and [math]::Abs($bytes[$o + 1] - $rgb.G) -le $tolerance -and [math]::Abs($bytes[$o] - $rgb.B) -le $tolerance) {
        [void]$hits.Add(@{ X = $x + $col; Y = $y + $row; Hex = ("#{0:X2}{1:X2}{2:X2}" -f $bytes[$o + 2], $bytes[$o + 1], $bytes[$o]) })
        if ($hits.Count -ge 500) { return ,$hits }
      }
    }
  }
  return ,$hits
}

# --- IME conversion mode via the default IME window -----------------------
# The conversion mode (Chinese composition vs alphanumeric) is NOT visible in
# the HKL - it lives in the input context. Cross-process access works through
# the default IME window: SendMessage(ImmGetDefaultIMEWnd(hwnd), WM_IME_CONTROL,
# sub, ...). Sub-codes probed live on this machine (2026-09-28):
#   IMC_GETCONVERSIONMODE = 0x0001  -> 0x401 = NATIVE|SYMBOL (Chinese), 0 = English
#   IMC_SETCONVERSIONMODE = 0x0002  (round-trip verified, restores fine)
#   IMC_GETOPENSTATUS     = 0x0005
# Do NOT send other sub-codes: GETCOMPOSITIONFONT (9) with a null lParam faults.
function Get-ImeMode([IntPtr]$hwnd) {
  $imeWnd = [DT]::ImmGetDefaultIMEWnd($hwnd)
  if ($imeWnd -eq [IntPtr]::Zero) { return -1 }
  return [DT]::SendMessage($imeWnd, 0x0283, [IntPtr]1, [IntPtr]::Zero)
}

function Set-ImeMode([IntPtr]$hwnd, [int]$mode) {
  $imeWnd = [DT]::ImmGetDefaultIMEWnd($hwnd)
  if ($imeWnd -eq [IntPtr]::Zero) { return $false }
  [void][DT]::SendMessage($imeWnd, 0x0283, [IntPtr]2, [IntPtr]$mode)
  return $true
}

function Format-ImeMode([int]$mode) {
  $parts = @()
  if ($mode -eq 0) { $parts += 'alphanumeric' }
  if (($mode -band 0x1) -ne 0) { $parts += 'native' }
  if (($mode -band 0x8) -ne 0) { $parts += 'fullshape' }
  if (($mode -band 0x400) -ne 0) { $parts += 'symbol' }
  if (($mode -band 0x100) -ne 0) { $parts += 'noconversion' }
  if ($parts.Count -eq 0) { $parts += "bits=0x$($mode.ToString('X'))" }
  return "mode=0x$($mode.ToString('X')) ($($parts -join '|'))"
}

# v3.1.0 (P-05): the --json view of an IME reading, one producer. `open` used to be the literal
# $true on every row - including mode=0, which this file's OWN text output describes as
# "type English directly" - so a JSON consumer was told "an IME is open" for the one state where
# nothing is open. Two fields in one message contradicting each other is exactly what the
# overview's F-01 round named: assert the RELATION between them, not that each is non-empty.
function Get-ImeStateView($procId, $title, [int]$mode) {
  return [pscustomobject]@{ pid = $procId; title = $title; mode = $mode; open = ($mode -ne 0); text = (Format-ImeMode $mode) }
}

# Set conversion mode and poll-verify (some TSF IMEs ignore WM_IME_CONTROL -
# the verification is what turns that into an honest ERROR instead of a lie).
function Set-ImeModeVerified([IntPtr]$hwnd, [int]$mode) {
  if (-not (Set-ImeMode $hwnd $mode)) { return $false }
  for ($i = 0; $i -lt 4; $i++) {
    Start-Sleep -Milliseconds 250
    if ((Get-ImeMode $hwnd) -eq $mode) { return $true }
    [void](Set-ImeMode $hwnd $mode)
  }
  return ((Get-ImeMode $hwnd) -eq $mode)
}

# Win10/11: MoveWindow and GetWindowRect operate on the window rect INCLUDING
# the invisible resize border, while every rect this tool reports (WinList, win
# captures, relclick origin) is the DWM visible bounds. This per-side delta is
# how win-move/win-resize can speak visible coordinates.
function Get-VisibleAdjust([IntPtr]$h) {
  $wr = New-Object DT+RECT
  [void][DT]::GetWindowRect($h, [ref]$wr)
  $vr = New-Object DT+RECT
  if ([DT]::DwmGetWindowAttribute($h, (Get-DwmVisibleFrameAttribute), [ref]$vr, [System.Runtime.InteropServices.Marshal]::SizeOf($vr)) -ne 0) {
    return @{ DL = 0; DT = 0; DR = 0; DB = 0 }
  }
  return @{ DL = $vr.Left - $wr.Left; DT = $vr.Top - $wr.Top; DR = $wr.Right - $vr.Right; DB = $wr.Bottom - $vr.Bottom }
}

# Screen rect of a resolved target: WinList objects carry it; a no-sel target
# (whatever is foreground) is looked up by handle.
function Get-TargetRect($target) {
  # The cached fields are used only when they are LIVE geometry: a rect at the
  # -32000 parking spot means the window was minimized when that snapshot was
  # taken, and the caller (e.g. an activation that just restored it, or the
  # landing guard) needs the fresh rect - fall through to the by-handle
  # re-query instead of judging against the parked rect.
  if ($null -ne $target.PSObject.Properties['Left'] -and $target.W -gt 0 -and $target.Left -gt -32000) {
    return @{ X = $target.Left; Y = $target.Top; W = $target.W; H = $target.H }
  }
  $found = @(Get-WinList | Where-Object { $_.Handle -eq $target.Handle })
  if ($found.Count -gt 0) { return @{ X = $found[0].Left; Y = $found[0].Top; W = $found[0].W; H = $found[0].H } }
  return $null
}

# ---------------------------------------------------------------------------
# CU-OPS package D (v4.6.0): explicit coordinate spaces.
# A bare x,y has always meant SCREEN pixels. `--space window` and `--space client`
# are the two relative spaces callers actually have on hand: an offset inside the
# window's visible frame, and an offset inside its client area. What they must NOT
# become is a stored point: the origin is read at ACTION time, after the target has
# been resolved and activated, so a move/resize/DPI change between "I looked" and
# "I clicked" cannot leave an old origin in use. `screen` keeps the legacy path
# bit-for-bit and needs no window at all.
# ---------------------------------------------------------------------------
function Test-PointSpaceArg([string]$space) {
  $sp = "$space"
  if ($sp -eq '') { return 'screen' }
  if ($sp -notin @('screen', 'window', 'client')) { throw "--space must be screen|window|client, got '$sp'; no input was sent" }
  return $sp
}

# One origin for one space, measured NOW. Returns the screen-space origin plus the
# area bounds used to refuse a point that cannot exist in that space (a negative
# offset or one past the edge is a caller mistake, not a point to clamp).
function Get-PointSpaceOrigin([string]$space, $target) {
  $sp = Test-PointSpaceArg $space
  if ($sp -eq 'screen') { return @{ Space = 'screen'; X = 0; Y = 0; W = 0; H = 0 } }
  if ($null -eq $target) {
    throw ("--space $sp needs a resolved window (--to <sel>, or wheel --at <sel>): there is no window origin to convert the coordinates against; no input was sent")
  }
  $h = [IntPtr]$target.Handle
  if ($sp -eq 'window') {
    $r = Get-TargetRect $target
    if ($null -eq $r) { throw "--space window: the target's visible rect could not be read now (closed, hidden or minimized?) - refusing to reuse an old origin; no input was sent" }
    if ([int]$r.W -le 0 -or [int]$r.H -le 0) { throw ('--space window: the target visible rect is ' + $r.W + 'x' + $r.H + ' - no usable origin; no input was sent') }
    return @{ Space = 'window'; X = [int]$r.X; Y = [int]$r.Y; W = [int]$r.W; H = [int]$r.H }
  }
  $cr = New-Object DT+RECT
  if (-not [DT]::GetClientRect($h, [ref]$cr)) {
    throw ("--space client: GetClientRect failed for hwnd=$(([int64]$h).ToString('X')) - the window may have closed; no input was sent")
  }
  $origin = New-Object DT+POINT
  $origin.X = 0; $origin.Y = 0
  if (-not [DT]::ClientToScreen($h, [ref]$origin)) {
    throw ("--space client: ClientToScreen failed for hwnd=$(([int64]$h).ToString('X')); no input was sent")
  }
  $cw = [int]($cr.Right - $cr.Left)
  $chh = [int]($cr.Bottom - $cr.Top)
  if ($cw -le 0 -or $chh -le 0) { throw ('--space client: the target client area is ' + $cw + 'x' + $chh + ' - no usable origin; no input was sent') }
  return @{ Space = 'client'; X = [int]$origin.X; Y = [int]$origin.Y; W = $cw; H = $chh }
}

function Convert-PointSpace([int]$x, [int]$y, $origin) {
  if ($origin.Space -eq 'screen') { return @{ X = $x; Y = $y } }
  if ($x -lt 0 -or $y -lt 0 -or $x -ge $origin.W -or $y -ge $origin.H) {
    throw ('--space ' + $origin.Space + ': point ' + $x + ',' + $y + ' is outside the target area ' + $origin.W + 'x' + $origin.H + ' (offsets are 0-based inside that area); no input was sent')
  }
  return @{ X = ($origin.X + $x); Y = ($origin.Y + $y) }
}

# Receipt tail for the pointer echoes: empty for the legacy screen space (so every
# pre-existing caller sees the same line), explicit otherwise.
function Format-PointSpaceReceipt($origin, [int]$rx, [int]$ry) {
  if ($origin.Space -eq 'screen') { return '' }
  return (' space=' + $origin.Space + ' rel=' + $rx + ',' + $ry)
}

# After-send foreground recheck: the pre-send guard verifies the target BEFORE
# v1.5.3 (audit R-06): the same-process popup hole.
# EnumWindows returns top-level windows in Z-ORDER (topmost first), so "is there
# one of the target's own windows sitting ON TOP of the target" is answerable
# without any geometry guessing. This matters because the post-send reconciliation
# compared PIDs: a popup owned by the SAME process as the target (context menu,
# autocomplete dropdown, a dialog the app throws over its own input box) passed
# silently, and the command reported a successful send while the text went
# nowhere (measured in the audit round: right-click menu open -> 'type --to' echoed
# "typed 12 chars", exit 0, and the UIA readback showed the text lost/mangled).
# Detection is a DELTA against a pre-send baseline, per the owner's contract, so a
# tool window or palette that was already floating there does not fire on every
# single send. Click-through layers (WS_EX_TRANSPARENT - tooltips, hover hints,
# notification toasts) are NEVER a trigger: they cannot take the keyboard, and
# warning on them would turn every `type` into a red herring.
function Get-SamePidWindowsAbove($target) {
  $found = New-Object System.Collections.ArrayList
  if ($null -eq $target -or -not [DT]::IsWindow($target.Handle)) { return @($found) }
  $order = New-Object System.Collections.ArrayList
  $cb = [DT+EnumProc] {
    param($h, $l)
    if ([DT]::IsWindowVisible($h)) { [void]$order.Add($h) }
    return $true
  }
  [void][DT]::EnumWindows($cb, [IntPtr]::Zero)
  $idxTarget = -1
  for ($k = 0; $k -lt $order.Count; $k++) { if ($order[$k] -eq $target.Handle) { $idxTarget = $k; break } }
  if ($idxTarget -lt 0) { return @($found) }   # target is not (or no longer) on the list
  for ($k = 0; $k -lt $idxTarget; $k++) {
    $h = $order[$k]
    $pid2 = [uint32]0
    [void][DT]::GetWindowThreadProcessId($h, [ref]$pid2)
    if ([uint32]$target.Pid -ne $pid2) { continue }
    $cn = New-Object System.Text.StringBuilder 256
    [void][DT]::GetClassName($h, $cn, 256)
    $ex = [DT]::GetWindowLong($h, -20)           # GWL_EXSTYLE
    [void]$found.Add([pscustomobject]@{
      Handle = $h
      Class = $cn.ToString()
      Title = [DT]::Text($h)
      Transparent = ((([int64]$ex) -band 0x20L) -ne 0)   # WS_EX_TRANSPARENT: cannot take keys
    })
  }
  return @($found)
}

# Pure delta over ONE handle-set membership rule, answering both popup directions:
#   forward  - which opaque handles are NEW on top since $before (the pre-send
#              question menu-pick / Test-PostSendForeground ask);
#   reverse  - whether one specific handle ($watch) is STILL in the set (the
#              survival question the script popup guard asks).
# v2.0.1 (owner ruling 2026-10-01): these two directions used to live in two
# places - this function had the forward one, Test-PopupGuardAlive hand-rolled
# the reverse. The merged rule sits here so the "is this handle in that set"
# arithmetic has exactly one producer. New/HasNew keep their v1.5.x semantics
# (menu-pick depends on them); $watch is optional and defaults to asking nothing.
# Transparency is an ALARM filter, not an existence filter: a click-through
# coverer must not raise a "new popup" warning, but a guarded popup that happens
# to be click-through is still present, so Present reads the unfiltered handles.
function Compare-PopupDelta($before, $after, $watch = $null) {
  $b = @($before | ForEach-Object { [int64]$_.Handle })
  $a = @($after | ForEach-Object { [int64]$_.Handle })
  $new = New-Object System.Collections.ArrayList
  foreach ($w in @($after)) {
    if ($w.Transparent) { continue }
    if ($b -notcontains [int64]$w.Handle) { [void]$new.Add($w) }
  }
  $present = 'n/a'
  if ($null -ne $watch) {
    if ($a -contains [int64]$watch) { $present = 'yes' } else { $present = 'no' }
  }
  return @{ New = @($new); HasNew = (@($new).Count -gt 0); Watch = $watch; Present = $present }
}

# v1.9.0 (J-02 C, popup survival self-check). Compare-PopupDelta answers "what APPEARED
# on top" - the pre-send question. The script popup guard needs the COMPLEMENTARY answer
# about ONE specific baseline window: is it still a live window, still above its owner in
# z-order, and how far did its visible rectangle drift? Same enumeration
# (Get-SamePidWindowsAbove), other direction.
#   v2.0.0 shipped this as a SECOND pure function BESIDE the differ because the differ
#   could not express "this handle is gone" (the granularity gap the task order
#   anticipated, iteration log v1.9.0 limitation 1). Owner ruling 2026-10-01 merged the
#   two directions into Compare-PopupDelta, so the z-order leg below now READS the merged
#   differ instead of re-rolling its own handle-set arithmetic.
# Every P/Invoke read stays with the caller: inputs are plain values, so the RULE is
# offline-testable.
#   $base      @{ Hwnd; Pid; Class; X; Y; W; H; OwnerHwnd; Above0; Tolerance; MustBeFg }
#              ($Above0 = the z-order snapshot taken when the guard was armed; it is the
#              differ's "before" set - the PRESENCE verdict does not depend on it)
#   $isWindow  [DT]::IsWindow of the baseline hwnd, read by the caller
#   $aboveList Get-SamePidWindowsAbove output for the popup's OWNER (empty when the
#              popup has no owner - the z-order leg then reads n/a: an ownerless popup
#              cannot bury relative to anything, and IsWindow+rect carry the verdict)
#   $curRect   Get-WindowVisibleRect of the baseline hwnd ($null when IsWindow failed)
#   $fgHwnd    GetForegroundWindow at check time
function Test-PopupGuardAlive($base, [bool]$isWindow, $aboveList, $curRect, $fgHwnd) {
  $d = @{ Alive = $false; Present = 'no'; Above = 'no'; Drift = '-'; FgOk = '-'; Reason = '' }
  if ($null -eq $base) { $d.Reason = 'no baseline'; return $d }
  if (-not $isWindow) { $d.Reason = 'popup GONE (window destroyed)'; return $d }
  $d.Present = 'yes'
  $owned = ($null -ne $base.OwnerHwnd -and $base.OwnerHwnd -ne [IntPtr]::Zero)
  if ($owned) {
    # One membership rule, one producer (v2.0.1 merge). The differ's forward direction
    # (what appeared since the baseline snapshot) is deliberately NOT consumed here:
    # the abort reasons stay exactly the four v1.9.0 legs, so a live round cannot gain
    # a new failure mode from this refactor.
    $dz = Compare-PopupDelta @($base.Above0) @($aboveList) $base.Hwnd
    if ($dz.Present -eq 'yes') { $d.Above = 'yes' }
    else { $d.Reason = 'no longer above its owner in z-order'; return $d }
  } else {
    $d.Above = 'n/a (no owner)'
  }
  if ($null -eq $curRect) { $d.Reason = 'no visible rect'; return $d }
  $dx = [Math]::Abs([int]$curRect.X - [int]$base.X)
  $dy = [Math]::Abs([int]$curRect.Y - [int]$base.Y)
  $dw = [Math]::Abs([int]$curRect.W - [int]$base.W)
  $dh = [Math]::Abs([int]$curRect.H - [int]$base.H)
  $tol = [int]$base.Tolerance
  if (($dx -gt $tol) -or ($dy -gt $tol) -or ($dw -gt $tol) -or ($dh -gt $tol)) {
    $d.Reason = "rect drift dx=$dx dy=$dy dw=$dw dh=$dh exceeds tolerance=$tol"
    return $d
  }
  $d.Drift = "dx=$dx dy=$dy dw=$dw dh=$dh"
  if ([bool]$base.MustBeFg) {
    if ($fgHwnd -eq $base.Hwnd) { $d.FgOk = 'yes' }
    else { $d.Reason = 'foreground is no longer the guarded popup'; return $d }
  } else {
    $d.FgOk = 'n/a'
  }
  $d.Alive = $true
  $d.Reason = 'alive'
  return $d
}

# keys go out to whatever is focused, so foreground can be stolen between guard
# and delivery (seen live: keys --to WeChat echoed target pid=85756, foreground
# after = 71320). Two failure shapes are reported:
#   (a) a DIFFERENT process took the foreground  -> warn (pre-existing behaviour)
#   (b) the target's OWN process put a new, keyboard-capable window on top of the
#       target after the guard ran            -> warn (v1.5.3, audit R-06)
# With --force the caller already accepted an unverified send, so (b) is printed
# as a notice and does NOT flip the exit code - the bypass keeps its meaning.
function Test-PostSendForeground($target, [bool]$force = $false) {
  try {
    if ([DT]::IsWindow($target.Handle)) {
      $h = [DT]::GetForegroundWindow()
      if ($h -ne $target.Handle) {
        $procId = 0
        [void][DT]::GetWindowThreadProcessId($h, [ref]$procId)
        if ($procId -ne $target.Pid) {
          return "WARN: foreground changed after send -> pid=$procId title='$([DT]::Text($h))' - keys may have reached the wrong window; verify with a screenshot"
        }
      }
    }
    $beforeHandles = @()
    if ($target.PSObject.Properties['PreSendAbove']) { $beforeHandles = @($target.PreSendAbove) }
    $after = @(Get-SamePidWindowsAbove $target)
    $d = Compare-PopupDelta $beforeHandles $after
    if ($d.HasNew) {
      $w0 = $d.New[0]
      $msg = "WARN: same-process popup '$($w0.Class)' (hwnd=$($w0.Handle) title='$($w0.Title)') appeared ON TOP of the target after the guard passed - the keystrokes may have been taken by that popup, and the target's own text is NOT confirmed changed. Verify by reading the control back (uia-find / read-text); --force suppresses this check."
      if ($force) { return "NOTICE (bypassed by --force): $msg" }
      return $msg
    }
  } catch {
    # v3.1.0 (P-05 sub-item): the guard's OWN failure used to vanish into an empty catch, which
    # made "the check did not run" and "the check passed" the same observable - the exact shape
    # this repo keeps getting caught by. Fail-OPEN is still the right call (a broken sampler must
    # not turn a successful send into exit 1), but it has to be LOUD: NOTICE* is printed and
    # never exits 1 by the four consumers, so the send keeps its exit code and the caller sees
    # that this leg did not answer. Compare Invoke-OcclusionGate, which has an explicit Err.
    return "NOTICE: post-send foreground check unavailable: $($_.Exception.Message) - the send itself was NOT re-verified (exit code unchanged)"
  }
  return ''
}

# v1.5.2 WP-3 (audit R-04, HIGH): what counts as a MENU for menu-pick.
# The old predicate was the WS_POPUP style bit, but on this machine the desktop
# (Progman), the Settings shell, Weixin and several Tauri/Qt windows all carry
# that bit - measured live: `menu-pick "Program Manager" <needle>` OCR'd 145
# desktop rows and would have clicked one, while the docs promised "non-popup
# targets are refused by default". A menu is now identified by class + shape:
#   - class '#32768'              the Win32 context-menu class: always a menu
#   - Progman / WorkerW           shell surfaces: never a menu (explicit rule,
#                                 not left to the area heuristic)
#   - smaller than 25% of the screen and not spanning it  transient popup shape
# Accepted cost (task order section 4): a Win11 XAML context menu that is neither
# #32768 nor popup-shaped now needs --allow-window. Chosen deliberately: the
# false-positive shows up as a loud refusal with a way out, while the old
# behaviour was a silent click on whatever happened to contain the text.
function Test-MenuWindow($w, [int]$screenW, [int]$screenH) {
  if ($null -eq $w) { return @{ Menu = $false; Reason = 'no window resolved' } }
  $cls = "$($w.Class)"
  if ($cls -eq '#32768') { return @{ Menu = $true; Reason = 'class=#32768 (Win32 menu)' } }
  if ($cls -eq 'Progman' -or $cls -eq 'WorkerW') {
    return @{ Menu = $false; Reason = "class=$cls is a shell surface" }
  }
  if ($screenW -le 0 -or $screenH -le 0) { return @{ Menu = $false; Reason = 'screen size unavailable' } }
  if ([int]$w.W -ge $screenW -or [int]$w.H -ge $screenH) {
    return @{ Menu = $false; Reason = "spans the screen ($($w.W)x$($w.H) of $screenW x $screenH)" }
  }
  $area = [long]$w.W * [long]$w.H
  $limit = [long]($screenW * $screenH * 0.25)
  if ($area -gt $limit) {
    return @{ Menu = $false; Reason = "area $area px2 is over 25% of the screen ($limit px2)" }
  }
  return @{ Menu = $true; Reason = 'transient popup shape' }
}

# v1.5.0 WP-3 landing-point self-proof: the top-level window actually under a
# screen point (WindowFromPoint then GetAncestor GA_ROOT=2, so the echo names
# the real app window and not an inner control). Returns a hashtable or $null.
function Get-HitWindow([int]$x, [int]$y) {
  $pt = New-Object DT+POINT
  $pt.X = $x; $pt.Y = $y
  $h = [DT]::WindowFromPoint($pt)
  if ($h -eq [IntPtr]::Zero) { return $null }
  $root = [DT]::GetAncestor($h, 2)
  if ($root -ne [IntPtr]::Zero) { $h = $root }
  $procId = 0
  [void][DT]::GetWindowThreadProcessId($h, [ref]$procId)
  $proc = '?'
  try { $proc = (Get-Process -Id $procId -ErrorAction Stop).ProcessName } catch { }
  return @{ Hwnd = $h; Pid = $procId; Proc = $proc; Title = [DT]::Text($h) }
}

# ---------------------------------------------------------------------------
# v1.5.1 WP-A: occlusion self-proof.
#
# Every capture path in this tool reads SCREEN pixels (CopyFromScreen): when
# the target window is covered, a command reads the COVERER's pixels and still
# returns a perfectly normal result. The check below, built on the real system
# hit test, is what lets a command say "these pixels are not the target's".
#
# Why WindowFromPoint and NOT z-order rectangle intersection: this machine
# carries full-screen but CLICK-THROUGH overlay layers (NVIDIA GeForce
# Overlay, TextInputHost "Windows input experience", Program Manager). A
# rectangle-intersection check would flag every region as ~100% occluded and
# the tool would be useless. WindowFromPoint runs the actual hit test, which
# honours WS_EX_TRANSPARENT / layered pass-through, so it reports who would
# really RECEIVE a click at that pixel - the same layering a capture shows.
# ---------------------------------------------------------------------------

# The class name of a window as a plain string. Exists so the occlusion scan can
# name an ANONYMOUS coverer (taskbar, desktop, tool windows) instead of printing ''
# - see Format-WindowLabel.
function Get-WindowClass([IntPtr]$h) {
  $sb = New-Object System.Text.StringBuilder 256
  try { [void][DT]::GetClassName($h, $sb, 256) } catch { return '' }
  return $sb.ToString()
}

# n x n interior sample points, kept 2px away from the region edges (DWM
# shadows and rounded corners live there). Regions too small for the inset
# degrade to a single centre sample; zero/negative sizes yield no points.
# Pure geometry: unit-testable without a screen. Returns @{ Points; N }.
function Get-OcclusionPoints([int]$x, [int]$y, [int]$w, [int]$h, [int]$grid) {
  if ($grid -lt 1) { $grid = 1 }
  if ($grid -gt 21) { $grid = 21 }
  $pts = New-Object System.Collections.ArrayList
  if ($w -le 0 -or $h -le 0) { return @{ Points = @($pts); N = 0 } }
  $n = $grid
  if ($w -lt (2 * $n + 2) -or $h -lt (2 * $n + 2)) { $n = 1 }
  if ($n -eq 1) {
    [void]$pts.Add(@{ X = $x + [int][math]::Floor($w / 2.0); Y = $y + [int][math]::Floor($h / 2.0) })
    return @{ Points = @($pts); N = 1 }
  }
  for ($iy = 0; $iy -lt $n; $iy++) {
    $py = $y + 2 + [int][math]::Round($iy * (($h - 4) / ($n - 1.0)))
    for ($ix = 0; $ix -lt $n; $ix++) {
      $px = $x + 2 + [int][math]::Round($ix * (($w - 4) / ($n - 1.0)))
      [void]$pts.Add(@{ X = $px; Y = $py })
    }
  }
  return @{ Points = @($pts); N = @($pts).Count }
}

# Deduplicates hit rows by root handle: one Covering entry per window with the
# number of sample points it took. Pure (synthetic rows are fine in tests).
function Merge-OcclusionHits($rows) {
  $byH = @{}
  foreach ($r in @($rows)) {
    $key = [string]$r.Hwnd
    if (-not $byH.ContainsKey($key)) {
      $byH[$key] = @{ Hwnd = (Get-OptValue $r 'Hwnd'); Pid = (Get-OptValue $r 'Pid'); Proc = (Get-OptValue $r 'Proc'); Title = (Get-OptValue $r 'Title'); Class = (Get-OptValue $r 'Class'); Count = 0 }
    }
    $byH[$key].Count++
  }
  $list = @($byH.Values | Sort-Object -Property @{ Expression = { $_.Count }; Descending = $true }, @{ Expression = { [string]$_.Hwnd } })
  return @{ Covering = @($list) }
}

# One hit-test pass over the grid. Proc names / titles are resolved ONCE per
# unique root handle (a per-point Get-Process would blow the cost budget on
# large windows). Points outside the virtual screen are dropped into Skipped,
# never counted as mismatches (multi-monitor negative coordinates). Returns
# @{ Checked; Skipped; Rows; Err; Ms; Total }.
function Get-OcclusionScan([int]$x, [int]$y, [int]$w, [int]$h, [int]$grid) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $g = Get-OcclusionPoints $x $y $w $h $grid
  $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
  if (-not $script:ProcNameCache) { $script:ProcNameCache = @{} }
  $rows = New-Object System.Collections.ArrayList
  $checked = 0
  $skipped = 0
  $info = @{}
  foreach ($p in @($g.Points)) {
    if ($p.X -lt $vs.X -or $p.X -ge ($vs.X + $vs.Width) -or $p.Y -lt $vs.Y -or $p.Y -ge ($vs.Y + $vs.Height)) { $skipped++; continue }
    $checked++
    $pt = New-Object DT+POINT
    $pt.X = $p.X; $pt.Y = $p.Y
    $hw = [DT]::WindowFromPoint($pt)
    if ($hw -ne [IntPtr]::Zero) {
      $root = [DT]::GetAncestor($hw, 2)
      if ($root -ne [IntPtr]::Zero) { $hw = $root }
    }
    $key = [string]$hw
    if (-not $info.ContainsKey($key)) {
      $procId = 0
      [void][DT]::GetWindowThreadProcessId($hw, [ref]$procId)
      if (-not $script:ProcNameCache.ContainsKey($procId)) {
        $pn = ''
        try { $pn = (Get-Process -Id $procId -ErrorAction Stop).ProcessName } catch { }
        $script:ProcNameCache[$procId] = $pn
      }
      $info[$key] = @{ Pid = $procId; Proc = $script:ProcNameCache[$procId]; Title = [DT]::Text($hw); Class = (Get-WindowClass $hw) }
    }
    $r = $info[$key]
    [void]$rows.Add(@{ Hwnd = $hw; Pid = $r.Pid; Proc = $r.Proc; Title = $r.Title; Class = $r.Class })
  }
  $sw.Stop()
  $err = ''
  if (@($g.Points).Count -eq 0) { $err = 'degenerate-rect' }
  elseif ($checked -eq 0) { $err = 'all-offscreen' }
  return @{ Checked = $checked; Skipped = $skipped; Rows = @($rows); Err = $err; Ms = [int]$sw.Elapsed.TotalMilliseconds; Total = @($g.Points).Count }
}

# Pure verdict for a fixed target: what fraction of the sampled points would
# NOT be received by <target> (root-window comparison). All-offscreen is its
# own state (Err), never reported as a 0% pass. Returns
# @{ Checked; Mismatch; Pct; Covering; Skipped; Err; Ms }.
function Get-OcclusionVerdict([int]$x, [int]$y, [int]$w, [int]$h, [IntPtr]$target, [int]$grid) {
  $s = Get-OcclusionScan $x $y $w $h $grid
  $mis = New-Object System.Collections.ArrayList
  foreach ($r in @($s.Rows)) { if ($r.Hwnd -ne $target) { [void]$mis.Add($r) } }
  $mm = @($mis).Count
  $pct = 0.0
  if ($s.Checked -gt 0) { $pct = [math]::Round(100.0 * $mm / $s.Checked, 1) }
  $c = Merge-OcclusionHits $mis
  return @{ Checked = $s.Checked; Mismatch = $mm; Pct = $pct; Covering = $c.Covering; Skipped = $s.Skipped; Err = $s.Err; Ms = $s.Ms }
}

# ---------------------------------------------------------------------------
# v1.5.4 (R-25): ONE renderer for every "who is covering this" line.
# R-25 reached me as "two different pids blamed in the same command". Measured,
# that reading came from the REPORT being truncated by the observer; what is real
# and now fixed is three different things: the same covering list was rendered in
# three different shapes by three call sites, the gate path dropped every coverer
# past the third SILENTLY (while --json kept all of them - measured with four
# self-produced coverers: WARNING showed 3, --json showed 4), and no line said
# which rectangle it had actually measured, so two correct lines from two correct
# scans read like a contradiction.
# DISPLAY ONLY: percentages, the warn/strict/off policy, which conditions throw,
# exit codes and the --json key set are all untouched.
# ---------------------------------------------------------------------------

# ' (+K more)' - the exact wording the owners path already used, factored out so the
# two paths can never drift into two conventions again. Truncation is allowed,
# silent truncation is not. Pure.
function Add-OcclusionMore([int]$total, [int]$shown) {
  if ([int]$total -gt [int]$shown) { return " (+$([int]$total - [int]$shown) more)" }
  return ''
}

# Sort and render a covering list. Sorts DEFENSIVELY (sample count descending,
# handle as tiebreak - the same rule Merge-OcclusionHits uses) so a caller handed an
# unsorted list cannot make the one-line summary disagree with the detailed list:
# the summary is by construction the FIRST rendered item, and selftest asserts
# exactly that. Returns @{ Items; Lines; Summary; Top }.
function Format-OcclusionCovering($covering, [int]$checked) {
  $items = @(@($covering) | Sort-Object -Property @{ Expression = { [int]$_.Count }; Descending = $true }, @{ Expression = { [string]$_.Hwnd } })
  $lines = New-Object System.Collections.ArrayList
  foreach ($c in $items) {
    [void]$lines.Add("pid=$(Get-OptValue $c 'Pid') proc=$(Get-OptValue $c 'Proc') title=$(Format-WindowLabel (Get-OptValue $c 'Title') (Get-OptValue $c 'Class')) ($(Get-OptValue $c 'Count') of $checked sample points)")
  }
  $top = $null
  $summary = 'unknown'
  if (@($items).Count -gt 0) {
    $top = $items[0]
    $summary = "pid=$($top.Pid) $(Format-WindowLabel $top.Title (Get-OptValue $top 'Class')) ($($top.Count) of $checked sample points)" + (Add-OcclusionMore @($items).Count 1)
  }
  return @{ Items = @($items); Lines = @($lines); Summary = $summary; Top = $top }
}

# The one-line verdict, ALWAYS labelled with which scan produced it and which
# rectangle it measured - the missing label is the whole reason two correct lines
# looked like a contradiction. Returns e.g.
#   scan=guard rect=(989,760,280x220) occluded=36% coveredBy=pid=94736 'DTX-OccB' (9 of 25 sample points)
#   scan=read  rect=(409,400,798x530) occluded=0%
function Format-OcclusionVerdict([string]$scan, $rect, [int]$pct, [string]$coveringSummary, [string]$err) {
  $rs = ''
  if ($null -ne $rect) { $rs = " rect=($($rect.X),$($rect.Y),$($rect.W)x$($rect.H))" }
  if ($err) { return "scan=$scan$rs occluded=n/a ($err)" }
  $txt = "scan=$scan$rs occluded=$pct%"
  if ($pct -gt 0 -and $coveringSummary) { $txt += " coveredBy=$coveringSummary" }
  return $txt
}

# Same grid, no target window: for raw-region reads and plain captures there
# is nothing to compare against, so report who OWNS the sampled pixels.
# Fabricating a target (centre window? foreground?) would be exactly the kind
# of guessing this project bans - and would misfire on ordinary multi-window
# regions the moment two windows legitimately share the area.
function Get-RegionOwners([int]$x, [int]$y, [int]$w, [int]$h, [int]$grid) {
  $s = Get-OcclusionScan $x $y $w $h $grid
  $c = Merge-OcclusionHits $s.Rows
  return @{ Checked = $s.Checked; Skipped = $s.Skipped; Owners = $c.Covering; Err = $s.Err; Ms = $s.Ms }
}

# --occlude off|warn|strict overrides the per-command default (reads warn,
# guards/asserts strict); --allow-occluded downgrades strict to warn - it is
# the explicit "I know, let me through" switch, like --force.
function Resolve-OcclusionMode([string]$v, [bool]$allow, [bool]$strictByDefault) {
  $action = if ($strictByDefault) { 'strict' } else { 'warn' }
  if ($v) {
    $action = Resolve-OccludeModeArg $v
  }
  if ($allow -and $action -eq 'strict') { $action = 'warn' }
  return @{ Action = $action }
}

# Shared parser: strips --occlude / --occlude-grid / --allow-occluded wherever
# they appear so every occlusion-aware command can reuse one implementation.
function Split-OcclusionFlags([string[]]$words) {
  $out = New-Object System.Collections.ArrayList
  $mode = ''
  $grid = 5
  $allow = $false
  $i = 0
  while ($i -lt $words.Count) {
    $t = $words[$i]
    if ($t -eq '--occlude') {
      $i++
      if ($i -ge $words.Count) { throw '--occlude needs off|warn|strict' }
      $mode = Resolve-OccludeModeArg $words[$i]
    } elseif ($t -eq '--occlude-grid') {
      $i++
      if ($i -ge $words.Count) { throw '--occlude-grid needs a number (1..21)' }
      $grid = Resolve-OcclGridArg $words[$i]
    } elseif ($t -eq '--allow-occluded') {
      $allow = $true
    } else {
      [void]$out.Add($t)
    }
    $i++
  }
  return @{ Words = @($out); Occlude = $mode; OcclGrid = $grid; AllowOccluded = $allow }
}

# Runs the verdict for a known target and applies the resolved policy:
#   warn   -> stderr WARNING when occluded, echo/json fields, never fails
#   strict -> throws on ANY mismatch (nothing is sent/asserted on another
#             window's pixels); clean runs still echo occluded=0%
#   off    -> no scan at all
# Returns @{ Ran; Pct; Mismatch; Checked; Covering; Err; Echo }.
function Invoke-OcclusionGate($rect, [IntPtr]$handle, [string]$action, [int]$grid, [string]$desc, [string]$sel, [string]$kind) {
  if ($action -eq 'off' -or $null -eq $rect -or $handle -eq [IntPtr]::Zero) {
    return @{ Ran = $false; Pct = 0.0; Mismatch = 0; Checked = 0; Covering = @(); Err = ''; Echo = 'occlusion check skipped (--occlude off)' }
  }
  $occ = Get-OcclusionVerdict $rect.X $rect.Y $rect.W $rect.H $handle $grid
  $pct = [int][math]::Round($occ.Pct)
  $cov = @($occ.Covering)
  # v1.5.4 (R-25): one renderer, one label. The summary and the WARNING list are now
  # the SAME sorted list seen two ways, so they cannot name different pids, and the
  # list names every coverer instead of dropping the 4th and beyond.
  $rep = Format-OcclusionCovering $cov $occ.Checked
  $scan = 'read'
  if ($kind -eq 'guard') { $scan = 'guard' } elseif ($kind -eq 'assert') { $scan = 'assert' }
  $echo = Format-OcclusionVerdict $scan $rect $pct $rep.Summary $occ.Err
  $raise = if ($sel) { "focus $sel first and retry" } else { 'raise the target window first and retry' }
  $coverStr = $rep.Summary
  if ($occ.Mismatch -gt 0) {
    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add("WARNING: [scan=$scan] target '$desc' rect ($($rect.X),$($rect.Y),$($rect.W)x$($rect.H)) is $pct% OCCLUDED - pixels read are NOT the target's.")
    foreach ($l in @($rep.Lines)) { [void]$lines.Add("  covering: $l") }
    if (@($rep.Lines).Count -eq 0) { [void]$lines.Add('  covering: (none resolved - the sampled pixels belong to nothing addressable)') }
    if ($kind -eq 'guard') {
      [void]$lines.Add("  the content guard is reading other windows' pixels - it stops by default ($raise, or pass --allow-occluded / --occlude off).")
    } elseif ($kind -eq 'assert') {
      [void]$lines.Add("  an assertion over these pixels is NOT evidence about the target - $raise, or pass --allow-occluded.")
    } else {
      [void]$lines.Add("  a `"not found`" result here is NOT evidence the text is absent. $raise, or pass --occlude off.")
    }
    try { [Console]::Error.WriteLine(($lines -join "`r`n")) } catch { }
  }
  if ($action -eq 'strict' -and $occ.Mismatch -gt 0) {
    if ($kind -eq 'guard') {
      throw "content guard FAILED (occlusion $pct%): pixels in the guard region are NOT '$desc' (covered by $coverStr) - NOTHING was sent. $raise, or pass --allow-occluded / --occlude off."
    } elseif ($kind -eq 'assert') {
      throw "assert failed: target region pixels are OCCLUDED ($pct% - covered by $coverStr); refusing to assert on another window's pixels. $raise, or pass --allow-occluded."
    }
    throw "occlusion check failed ($pct%): '$desc' is covered by $coverStr - refusing to continue (--occlude strict). $raise, or drop --occlude strict."
  }
  return @{ Ran = $true; Pct = $occ.Pct; Mismatch = $occ.Mismatch; Checked = $occ.Checked; Covering = $cov; Err = $occ.Err; Echo = $echo }
}

# Owners mode for regions without a target window (raw-rect reads, rect/shot
# captures): report which windows the sampled pixels belong to. Nothing to
# fail on - the echo is the product.
function Invoke-OcclusionOwners($rect, [string]$action, [int]$grid) {
  if ($action -eq 'off' -or $null -eq $rect) {
    return @{ Ran = $false; Echo = 'occlusion check skipped (--occlude off)'; Owners = @(); Checked = 0 }
  }
  $o = Get-RegionOwners $rect.X $rect.Y $rect.W $rect.H $grid
  if ($o.Err) { return @{ Ran = $false; Echo = "n/a ($($o.Err))"; Owners = @(); Checked = 0 } }
  $parts = New-Object System.Collections.ArrayList
  # v1.5.4 (R-25): the (+K more) marker comes from Add-OcclusionMore, the same helper the
  # gate path uses, so the two cannot grow into different conventions about admitting a
  # truncated list. v1.5.7: it is computed NEXT TO the cut below, so "we hid some" cannot
  # drift away from the line that hides them (the truncation contract reads the locality).
  $ownMax = 3; $more = Add-OcclusionMore @($o.Owners).Count $ownMax
  foreach ($c in @($o.Owners | Select-Object -First $ownMax)) {
    $share = 0
    if ($o.Checked -gt 0) { $share = [int][math]::Round(100.0 * $c.Count / $o.Checked) }
    [void]$parts.Add("pid=$($c.Pid) $(Format-WindowLabel $c.Title $c.Class) $share%")
  }
  return @{ Ran = $true; Echo = 'owners ' + ($parts -join '; ') + $more; Owners = @($o.Owners); Checked = $o.Checked }
}

# Echoes the hit-window line and enforces the landing rule: when an explicit
# --to target is known (enforce=$true) and the point is OUTSIDE the target's
# DWM-visible rect, refuse by default - throw BEFORE anything is moved/clicked
# so the caller's catch reports it and exits 1. --allow-outside downgrades the
# refusal to a note. Without --to it only echoes (bare-coordinate semantics are
# unchanged). Prints nothing else; returns nothing on the happy path.
function Invoke-HitWindowCheck([int]$x, [int]$y, $target, [bool]$enforce, [bool]$allowOutside) {
  $hit = Get-HitWindow $x $y
  $inside = 'n/a'
  $tr = $null
  $occTxt = ''
  if ($null -ne $target) {
    $tr = Get-TargetRect $target
    if ($null -ne $tr) {
      if ($x -ge $tr.X -and $x -lt ($tr.X + $tr.W) -and $y -ge $tr.Y -and $y -lt ($tr.Y + $tr.H)) { $inside = 'yes' } else { $inside = 'no' }
      # v1.5.1 WP-A: echo the target's occlusion rate too, so a landing check
      # names the full risk (a point can sit inside the target's rect while
      # the pixel under it belongs to a coverer). Echo only - never blocks.
      # v1.5.4 (R-25): this line used to print a bare pid and no rectangle, which
      # is the shape that made a full-target scan and a guard sub-region scan look
      # like they contradicted each other. Same renderer as everything else now,
      # labelled scan=hit, and it names proc/title like the rest.
      $ov = Get-OcclusionVerdict $tr.X $tr.Y $tr.W $tr.H $target.Handle 5
      $opct = [int][math]::Round($ov.Pct)
      $orep = Format-OcclusionCovering @($ov.Covering) $ov.Checked
      $occTxt = ' ' + (Format-OcclusionVerdict 'hit' $tr $opct $orep.Summary $ov.Err)
    }
  }
  if ($null -eq $hit) { Write-Output "hit-window: (none)  (inside-target=$inside)$occTxt" }
  else { Write-Output "hit-window: pid=$($hit.Pid) proc=$($hit.Proc) title='$($hit.Title)'  (inside-target=$inside)$occTxt" }
  if ($enforce -and $inside -eq 'no') {
    $desc = if ($target) { "'$($target.Title)'" } else { 'target' }
    $rr = if ($null -ne $tr) { "($($tr.X),$($tr.Y),$($tr.W)x$($tr.H))" } else { '(rect unknown)' }
    if (-not $allowOutside) {
      throw "landing guard: point ($x,$y) is OUTSIDE target window $desc visible rect $rr - action NOT sent. Re-derive the point (imgclick/unmap for image-derived coords) or pass --allow-outside to send anyway."
    }
    Write-Output "  (outside target rect - proceeding anyway: --allow-outside)"
  }
}

# CU-REL-01 (v4.4.1): the landing question the click family never asked before sending -
# "is the window physically under this point the window I just resolved?" Invoke-HitWindowCheck
# answers "is the point inside the target's rect" and only ECHOES who is under the point, so a
# point inside the rect but covered by another top-level (an unselected modal of the same process,
# a promo popup, a tooltip from a neighbouring app) still reported a confident success.
# Get-HitWindow walks WindowFromPoint up to its ROOT owner, which is what makes this comparable:
# a legitimate child control of the target answers with the TARGET's own handle and is allowed,
# while any other top-level - same pid or not - answers with its own handle and is refused.
# Pure over the two objects it is handed, so the four shapes are pinned offline (see the unit
# check in the window-targeting family) instead of needing a live window to be believed.
function Test-LandingOnTarget($hit, $target) {
  if ($null -eq $hit) { return $false }
  return ($hit.Hwnd -eq $target.Handle)
}

# The one producer of the refusal/relaxation sentence for that verdict, so the echo names the
# thing that was actually relaxed (the card's rule: a relaxation flag keeps its own definition
# and must say so). Returns the sentence only - the caller decides whether to throw or print.
function Format-LandingVerdict([int]$x, [int]$y, $hit, $target, [bool]$relaxed) {
  $who = if ($null -eq $hit) { '(nothing answers the hit test)' } else { "pid=$($hit.Pid) hwnd=$($hit.Hwnd) '$([DT]::Text($hit.Hwnd))'" }
  if ($relaxed) {
    return "  (landing guard RELAXED by --allow-outside: clicking at ($x,$y) where $who sits, while the resolved target is hwnd=$($target.Handle) '$($target.Title)')"
  }
  return "landing guard: the window under ($x,$y) is $who, not the resolved target hwnd=$($target.Handle) '$($target.Title)' - NOTHING was clicked. Move or close the coverer (wins -z lists what is on top), point at the target itself, or pass --allow-outside to send anyway (it will say it relaxed the guard)."
}

# CU-REL-01 (v4.4.1): the one renderer for "what state is this window in, and when was that
# measured". `focus` used to print the label captured at SELECT time (parked / fg / largest) next to
# a boolean from Activate-Win and then never look at the window again, so a call whose target stayed
# minimized, or that never came forward, still read like a usable foreground. Both readings now go
# through here, each with its own stamp, so a reader can tell "what I picked" from "what it is after
# I touched it" - and a refusal can quote the state it refused on. Pure over the values it is handed,
# which is what lets the offline unit check pin all four shapes without a window.
function Format-FocusState([string]$when, $st) {
  if ($null -eq $st) { return "$when (not measured)" }
  $rs = '(none)'
  if ($null -ne $st.Rect) { $rs = "($($st.Rect.X),$($st.Rect.Y),$($st.Rect.W)x$($st.Rect.H))" }
  return "$when fg=$([bool]$st.Fg) iconic=$([bool]$st.Iconic) visible=$([bool]$st.Visible) rect=$rs"
}

# The single answer to "may the caller treat this window as clickable now". Deliberately stricter
# than "Activate-Win returned True": the window must actually BE the foreground one, must not be
# minimized, must be visible, and must have a rect that is not the parked off-screen spot.
function Test-FocusUsable($st) {
  if ($null -eq $st) { return $false }
  if (-not [bool]$st.Fg) { return $false }
  if ([bool]$st.Iconic) { return $false }
  if (-not [bool]$st.Visible) { return $false }
  if ($null -eq $st.Rect) { return $false }
  if ($st.Rect.X -le -32000 -or $st.Rect.Y -le -32000) { return $false }
  return $true
}

# The one answer to "is this a legal --occlude value / --occlude-grid value". Both flag
# parsers (Split-OcclusionFlags, which strips them from a word list, and Split-Target, which
# parses them in place) used to carry their own copy of these two checks INCLUDING the error
# text, three copies of each message in total (audit 2026-10-04 #16). --occlude-grid now
# also gets the numeric-flag refusal for free, so 'abc' names the flag instead of throwing
# a .NET cast error.
function Get-OcclusionModeValues { return @('off', 'warn', 'strict') }

function Resolve-OccludeModeArg([string]$v) {
  if ("$v" -notin (Get-OcclusionModeValues)) { throw "--occlude must be off|warn|strict, got: $v" }
  return "$v"
}

function Resolve-OcclGridArg($v) {
  $g = Read-FlagNumber '--occlude-grid' $v $true '(1..21)'
  if ($g -lt 1 -or $g -gt 21) { throw "--occlude-grid must be 1..21, got: $g" }
  return $g
}

# v3.1.0 (P-06): menu-pick's own flag loop, extracted PURE so the trailing-flag hole can be
# pinned offline. Second review batch, item 5 of the small-fix bundle: five flags consumed their
# operand with a bare `$i++; $x = $mp[$i]`. When the flag was the LAST token, `$mp[$i]` indexed
# past the end and bound to $null - so `--expect` silently became "no expectation at all" and
# `--timeout` became 0, i.e. the assertion the caller asked for never ran while the command
# reported green. The SAME loop already refused a missing operand for --needle ('menu-pick:
# --needle needs a value'), which is what makes this a defect rather than a design choice.
# Numbers now go through Read-FlagNumber like every other numeric flag in this file.
function Resolve-MenuPickArgs([string[]]$mp) {
  $r = @{ Expect = ''; ExpectGone = ''; ExpectRegion = ''; TimeoutSec = 6.0; IntervalMs = 300; Words = @() }
  # v4.2.4 (perf): the count is hoisted - @( ) copies the array on every evaluation, and this
  # loop evaluates its bound once per token (see the lint that bans the shape in conditions).
  $mpCount = @($mp).Count
  $i = 0
  while ($i -lt $mpCount) {
    $t = [string]$mp[$i]
    if ($t -eq '--expect' -or $t -eq '--expect-gone' -or $t -eq '--expect-region' -or $t -eq '--timeout' -or $t -eq '--interval') {
      $i++
      if ($i -ge $mpCount) { throw "menu-pick: $t needs a value (it was the last token - the expectation would have been silently dropped)" }
      $v = [string]$mp[$i]
      if ($t -eq '--expect') { $r.Expect = $v }
      elseif ($t -eq '--expect-gone') { $r.ExpectGone = $v }
      elseif ($t -eq '--expect-region') { $r.ExpectRegion = $v }
      elseif ($t -eq '--timeout') { $r.TimeoutSec = Read-FlagNumber '--timeout' $v $false '(seconds)' }
      else { $r.IntervalMs = Read-FlagNumber '--interval' $v $true '(ms)' }
    }
    elseif ($t -eq '--needle') {
      $i++
      if ($i -ge $mpCount) { throw 'menu-pick: --needle needs a value' }
      $r.Words += [string]$mp[$i]
    }
    elseif ($t -like '--*') { throw (Get-UnknownFlagMessage 'menu-pick' $t) }
    else { $r.Words += $t }
    $i++
  }
  return $r
}

# Content guard for --guard-text / --guard-region: AFTER the window guard
# passed, OCR the target window (or a window-relative sub-region) and require
# the needle to be present BEFORE anything is sent. This is what keeps
# "paste into the file-transfer assistant ONLY" style invariants enforced by
# the tool instead of by the agent remembering to look. Throws on miss.
# v1.5.1 WP-A: the guard is occlusion-STRICT by default - reading a coverer's
# pixels and finding the needle there is exactly the false-green this guard
# exists to prevent, so an occluded guard region fails BEFORE the OCR and
# nothing is sent (--allow-occluded / --occlude warn downgrade to a warning).
function Invoke-ContentGuard($target, [string]$guardText, [string]$guardRegion, [string]$scaleMode = 'auto', [int]$maxTiles = 16, [bool]$noTile = $false, [string]$occMode = '', [bool]$allowOccluded = $false, [int]$occGrid = 5) {
  if (-not $guardText -and -not $guardRegion) { return }
  $eng = Get-OcrEngine
  if ($null -eq $eng) {
    throw 'content guard requested but OCR is unavailable (no language pack); refusing to send - drop --guard-text/--guard-region or install an OCR language'
  }
  $rect = Get-TargetRect $target
  if ($null -eq $rect) { throw 'content guard: cannot determine target window rect (window may be gone)' }
  $needle = $guardText
  $where = 'whole target window'
  if ($guardRegion) {
    if ($guardRegion -notmatch '^(-?\d+),(-?\d+),(\d+),(\d+)=(.+)$') { throw "--guard-region expects x,y,w,h=needle got: $guardRegion" }
    $needle = $Matches[5]
    # Base on the resolved $rect, never on $target.Left: a no-sel target
    # (foreground lookup) carries no Left, and null + offset silently degraded
    # the window-relative region to a screen-absolute one (audit 2026-09-29 #12).
    $rect = @{ X = $rect.X + [int]$Matches[1]; Y = $rect.Y + [int]$Matches[2]; W = [int]$Matches[3]; H = [int]$Matches[4] }
    $where = "region $($Matches[1]),$($Matches[2]),$($Matches[3])x$($Matches[4]) (window-relative)"
  }
  if (-not $needle) { throw 'content guard: empty needle' }
  $occAct = (Resolve-OcclusionMode $occMode $allowOccluded $true).Action
  $gate = Invoke-OcclusionGate $rect $target.Handle $occAct $occGrid $target.Title $target.Title 'guard'
  $g = Find-OcrHitsScaled $rect.X $rect.Y $rect.W $rect.H $needle $scaleMode $maxTiles $noTile
  if ($g.Hits.Count -eq 0) {
    throw "content guard FAILED: '$needle' not found in $where of window '$($target.Title)' - NOTHING was sent. $(Format-OcrSampleTail $g.Lines 8 @{ Rect = $where; Retry = (Format-OcrRetryNote $g); Occlusion = "$([int][math]::Round($gate.Pct))% $($gate.Echo)"; Needle = $needle })"
  }
  $occSeg = ''
  if ($gate.Ran) { $occSeg = " [occ: $($gate.Echo)]" }
  Write-Output "content guard ok: '$needle' found in $where$(if ($g.Scaled) { ' (needed 2x upscale to read)' })$(Get-OcrFoldMarker $g.Hits)$occSeg"
}

# v1.5.0 WP-2: post-action expectation contract. Polls the anchor region via
# the tiled OCR path (big windows must read small text) until the needle is
# present (--expect) or absent (--expect-gone), or the timeout expires.
# baseRect: the anchor - target window rect when the command had --to, else
# the virtual screen. --expect-region is anchor-relative (same semantics as
# --guard-region). Returns hashtable @{ Ok; Elapsed; Where; Timeout; Interval } - the last
# two are what the LOOP ran with (interval after its 100 ms floor), so the verdict line can
# self-report the patience it actually used instead of just the time it spent.
#
# v3.0.0 (B-1 + B-3): two changes, one of them a thrown-away-evidence bug.
#  B-3 - the needle arguments are now ARRAYS. `--expect-any` accepts several texts and
#        passes as soon as ANY is present; `--expect-any-gone` requires ALL of them to be
#        gone (a gone-list where "one of them vanished" counts is the inverted reading, so
#        the two semantics are stated in the return keys and pinned in both directions).
#        Real shape this serves: a claim flow that answers either of two strings, a dialog
#        whose label follows the UI language.
#  B-1 - the SUCCESS branch used to return {Ok, Elapsed, Where, Timeout, Interval} and drop
#        the hit it had just found, while the FAILURE branch kept LastSeen/LineCount/RectW/
#        RectH. So proving "it appeared" left the caller to run a SECOND read to learn
#        WHERE - a second read that re-resolves <sel>, re-samples occlusion and re-pays the
#        OCR round trip (the repo's own pit 0b/16 say a second read is a different fact).
#        The success branch now carries Matched/Rect/Centre/Hits/Scaled/TileCount/Reads.
function Invoke-Expectation($baseRect, [string[]]$expect, [string[]]$expectGone, [string]$expectRegion, [double]$timeoutSec, [int]$intervalMs, $anchorHandle) {
  if ($intervalMs -lt 100) { $intervalMs = 100 }
  $expect = @($expect | Where-Object { "$_" -ne '' })
  $expectGone = @($expectGone | Where-Object { "$_" -ne '' })
  $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
  # v3.1.0 (P-03): the fallback used to be silent and the $where line called the result
  # "whole anchored region" in BOTH cases - a caller that gave --to and lost the window
  # (closed/hidden between send and wait) got the whole virtual screen under the same
  # honest-sounding label as a caller that never gave a target at all. The lost-window
  # case is refused by the callers now (Confirm-ExpectAnchor, same fail-closed shape as
  # the content guard); what still reaches here with $null is ONLY the no-target case,
  # and that one must say what it is actually waiting on.
  $where = 'whole anchored region'
  if ($null -eq $baseRect) {
    $baseRect = @{ X = $vs.X; Y = $vs.Y; W = $vs.Width; H = $vs.Height }
    $where = 'anchor=no-target (whole virtual screen)'
  }
  $rect = $baseRect
  if ($expectRegion) {
    if ($expectRegion -notmatch '^(-?\d+),(-?\d+),(\d+),(\d+)$') { throw "--expect-region expects x,y,w,h got: $expectRegion" }
    $rect = @{ X = $baseRect.X + [int]$Matches[1]; Y = $baseRect.Y + [int]$Matches[2]; W = [int]$Matches[3]; H = [int]$Matches[4] }
    $where = if ($where -eq 'anchor=no-target (whole virtual screen)') { "anchor=no-target (whole virtual screen), region $($Matches[1]),$($Matches[2]),$($Matches[3])x$($Matches[4]) (anchor-relative)" } else { "region $($Matches[1]),$($Matches[2]),$($Matches[3])x$($Matches[4]) (anchor-relative)" }
  }
  if ($expect.Count -eq 0 -and $expectGone.Count -eq 0) { return @{ Ok = $true; Elapsed = 0.0; Where = $where; Polls = 0 } }
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $polls = 0
  $last = $null
  $occErrSeen = ''
  while ($true) {
    $polls++
    # v3.1.0 (P-04): the occlusion front gate over the verbatim expectation legs - the same
    # 25-point sampler behind every occ: line and the v2.3.0 receipt gate, and the SAME knob
    # (Get-PasteReceiptOcclusionMax). The poll reads the SCREEN rect; a covered target means
    # the read is the coverer's, which is exactly the false-accept measured on the receipt
    # chain (v2.3.0 red-1/red-2). A covered anchor refuses the wait AT ONCE - no "wait and
    # see" - with exit 1 naming the pct and the coverer. Sampler failure (Err) is fail-OPEN
    # and self-reported through OccErr (registered limitation, same as the receipt gate).
    # No target handle (the P-03 anchor=no-target case) has no occlusion semantics: no gate.
    if (($null -ne $anchorHandle) -and (-not $anchorHandle.Equals([IntPtr]::Zero))) {
      $ovc = Get-OcclusionVerdict $rect.X $rect.Y $rect.W $rect.H $anchorHandle 5
      if ($ovc.Err -ne '') { $occErrSeen = $ovc.Err }
      elseif ([double]$ovc.Pct -gt [double](Get-PasteReceiptOcclusionMax)) {
        $orep = Format-OcclusionCovering @($ovc.Covering) $ovc.Checked
        throw ("expect refused: target occluded=" + [int][math]::Round($ovc.Pct) + "% coveredBy=" + $orep.Summary)
      }
    }
    # present = the needles that ARE on screen this poll; stillThere = the gone-list needles
    # that ARE. Both come from the SAME poll, so the verdict and its evidence cannot be two
    # different moments. AND semantics across the two lists: a caller that asks for "A
    # appeared and B gone" must not be passed on the strength of one of them.
    $present = @()
    $stillThere = @()
    foreach ($n in $expect) {
      $v = Find-OcrHitsScaled $rect.X $rect.Y $rect.W $rect.H $n 'auto' 16 $false
      if (@($v.Hits).Count -gt 0) { $present += ,@($n, $v) }
      $last = $v
    }
    foreach ($n in $expectGone) {
      $v = Find-OcrHitsScaled $rect.X $rect.Y $rect.W $rect.H $n 'auto' 16 $false
      if (@($v.Hits).Count -gt 0) { $stillThere += ,@($n, $v) }
      $last = $v
    }
    $wantPresent = ($expect.Count -eq 0 -or @($present).Count -gt 0)
    $wantGone = ($expectGone.Count -eq 0 -or @($stillThere).Count -eq 0)
    if ($wantPresent -and $wantGone) {
      $hit = $null
      $matched = ''
      if (@($present).Count -gt 0) { $matched = [string]$present[0][0]; $hit = $present[0][1] }
      $r = @{ Ok = $true; Elapsed = $sw.Elapsed.TotalSeconds; Where = $where; Timeout = $timeoutSec; Interval = $intervalMs; Polls = $polls; Matched = $matched; GoneList = (@($expectGone) -join '|'); OccErr = $occErrSeen }
      if ($null -ne $hit) {
        $hh = @($hit.Hits)
        $h0 = $hh[0]
        $r.Rect = "($($h0.X),$($h0.Y),$($h0.W)x$($h0.H))"
        $r.Centre = "$([int]($h0.X + $h0.W / 2)),$([int]($h0.Y + $h0.H / 2))"
        $r.Hits = $hh.Count
        # folded hits are counted the way Get-OcrFoldMarker counts them - through the
        # property collection, not by member access (the marker wording has one producer).
        $r.FoldedHits = @($hh | Where-Object { $_.PSObject.Properties['Folded'] -and $_.Folded -eq $true }).Count
        $r.Scaled = [bool]$hit.Scaled
        $r.Tiled = [bool]$hit.Tiled
        $r.TileCount = [int]$hit.TileCount
      }
      return $r
    }
    if ($sw.Elapsed.TotalSeconds -ge $timeoutSec) {
      $lines = @()
      if ($null -ne $last) { $lines = @($last.Lines) }
      $r = @{ Ok = $false; Elapsed = $sw.Elapsed.TotalSeconds; Where = $where; Timeout = $timeoutSec; Interval = $intervalMs; Polls = $polls; LineCount = @($lines).Count; RectW = $rect.W; RectH = $rect.H; OccErr = $occErrSeen }
      if ($expect.Count -gt 0) {
        # a not-found expectation keeps the pre-v3.0.0 wording for a single needle and names
        # the whole list when there are several; for a gone-list it says what is STILL there.
        $r.Needle = (@($expect) -join ' | ')
        $r.LastSeen = (Format-OcrSampleTail $lines 5)
      } else {
        $r.Needle = (@($stillThere | ForEach-Object { [string]$_[0] }) -join ' | ')
        $r.StillPresent = $r.Needle
      }
      return $r
    }
    Start-Sleep -Milliseconds $intervalMs
  }
}

# v1.5.7 ("self-reported value" coverage, the last sub-item of the v1.5.7 task row): the expect family
# printed only HOW LONG IT WAITED, never what patience and polling interval it actually ran
# with - so `--timeout 30` honoured and `--timeout` dropped on the floor looked identical,
# which is the same "parameter only lives in the signature" shape --verify-timeout had in
# v1.5.3. Both numbers are now in BOTH verdicts, and they are the values the LOOP used
# (interval after its 100 ms floor, not what was typed). Pure, so both branches are
# assertable offline instead of waiting for a --live round to notice.
function Format-ExpectationVerdict([bool]$ok, [double]$elapsed, [double]$timeoutSec, [int]$intervalMs, [string]$needle, [string]$what, [string]$where, [string]$verb) {
  $patience = 'patience ' + [math]::Round($timeoutSec, 1) + 's, polled every ' + $intervalMs + ' ms'
  if ($ok) { return "  + verified in $([math]::Round($elapsed, 1)) s ($patience)" }
  return "$verb OK but expectation NOT met: '$needle' $what in $where after $([math]::Round($elapsed, 1))s of $([math]::Round($timeoutSec, 1))s ($patience) - the action may have had no visible effect (pass --no-expect to silence)"
}

# v3.0.0 (B-1): the OTHER half of the evidence. A satisfied expectation proved "something
# with that text is on screen" and then THREW AWAY the rect it had just read, so a caller
# that wanted to click it or tell where it was had to run a second read - a second read
# re-resolves <sel>, re-samples occlusion and re-pays the OCR round trip, and this repo's
# own pits 0b/16 say a second read is a different fact, not the same fact twice.
# Pure, and it never claims more than the result object carries: no rect -> no at=, a
# confusable-fold match MUST say so (same rule as the fold marker on the locators, R-10).
function Format-ExpectationProof($er) {
  $bits = @()
  if (Get-OptValue $er 'Matched') { $bits += "matched=$(Get-OptValue $er 'Matched')" }
  if ((Get-OptValue $er 'Rect')) { $bits += "at=$((Get-OptValue $er 'Rect'))" }
  if (Get-OptValue $er 'Centre') { $bits += "centre=$(Get-OptValue $er 'Centre')" }
  if ((Get-OptValue $er 'Hits') -gt 1) { $bits += "hits=$(Get-OptValue $er 'Hits')" }
  if ((Get-OptValue $er 'Via')) { $bits += "via=$((Get-OptValue $er 'Via'))" }
  if ((Get-OptValue $er 'FoldedHits')) { $bits += (Get-FoldMarkerFromCounts ([int](Get-OptValue $er 'FoldedHits')) ([int](Get-OptValue $er 'Hits'))) }
  if ((Get-OptValue $er 'Polls') -gt 0) { $bits += "polls=$(Get-OptValue $er 'Polls')" }
  if (Get-OptValue $er 'OccErr') { $bits += "occ-sampler=$(Get-OptValue $er 'OccErr')" }
  if (@($bits).Count -eq 0) { return '' }
  return ' ' + ($bits -join ' ')
}

# The retry geometry as ONE honest word: what the locator that satisfied this expectation
# actually ran. Single producer, because three call sites spelling '2x'/'tiled' differently
# is how a self-report starts to disagree with the engine.
# Deliberately UNTYPED parameters: a missing key reads back as $null here, and [bool]$x on
# $null is a parameter-conversion ERROR - which would abort the command AFTER the action had
# already succeeded, turning a bookkeeping gap into a false failure. Truthiness instead.
function Get-ExpectationVia($scaled, $tiled, $tiles) {
  if ($tiled) { return 'tiled(' + [int]$tiles + ')' }
  if ($scaled) { return '2x' }
  return '1x'
}

# Shared tail for every expect-capable command: print "+ verified in X.X s" on
# success; on failure THROW (not exit) so standalone callers get ERROR + exit 1
# via the outer catch while script steps record a normal, non-gate FAIL - the
# action itself already happened and the message must say so.
# v3.1.0 (P-03): the fail-closed half of the anchor fix - one producer for the refusal
# text. A caller that HAD a target but cannot get its rect anymore (window closed or
# hidden between the send and the wait) must not silently slide onto the whole virtual
# screen; that is the exact fail-closed shape the content guard already uses for the
# same situation ('content guard: cannot determine target window rect').
function Confirm-ExpectAnchor($target, $baseRect) {
  if ($null -ne $target -and $null -eq $baseRect) {
    throw 'expectation anchor: cannot determine the target window rect (window may be closed or hidden) - NOT waiting on the whole screen'
  }
}

function Invoke-ActionExpectation($p, $target, [string]$verb) {
  $presentList = @(@($p.Expect) + @($p.ExpectAny)) | Where-Object { "$_" -ne '' } | Select-Object -Unique
  $goneList = @(@($p.ExpectGone) + @($p.ExpectAnyGone)) | Where-Object { "$_" -ne '' } | Select-Object -Unique
  $presentList = @($presentList)
  $goneList = @($goneList)
  if ($presentList.Count -eq 0 -and $goneList.Count -eq 0) { return }
  $base = if ($target) { Get-TargetRect $target } else { $null }
  Confirm-ExpectAnchor $target $base
  $exHandle = [IntPtr]::Zero
  if ($target) { $exHandle = $target.Handle }
  $er = Invoke-Expectation $base $presentList $goneList $p.ExpectRegion $p.TimeoutSec $p.IntervalMs $exHandle
  if ($er.Ok) {
    # Via is only meaningful alongside a rect (both come from the same satisfied hit);
    # a gone-list success has nothing to point at, so it gets polls= and nothing else.
    if (Get-OptValue $er 'Rect') { $er.Via = Get-ExpectationVia (Get-OptValue $er 'Scaled') (Get-OptValue $er 'Tiled') (Get-OptValue $er 'TileCount') }
    Write-Output ((Format-ExpectationVerdict $true $er.Elapsed $er.Timeout $er.Interval '' '' '' $verb) + (Format-ExpectationProof $er))
    return
  }
  $needle = $er.Needle
  $what = 'not visible'
  if ($presentList.Count -eq 0) { $what = 'still visible' }
  elseif ($goneList.Count -gt 0) { $what = 'list not satisfied (a text is missing and/or one is still there)' }
  # v1.5.9 (P-4): an unmet expectation on a large near-empty read may be an in-window
  # scrim hiding the needle, not a failed action - hint before the verdict line.
  $mld = 1.5
  if ($null -ne $p -and $null -ne $p.MinLineDensity) { $mld = [double]$p.MinLineDensity }
  if (Test-SparseReadability $er.RectW $er.RectH $er.LineCount $mld) {
    Write-Output (Build-SparseReadWarn $er.RectW $er.RectH $er.LineCount $mld)
  }
  throw (Format-ExpectationVerdict $false $er.Elapsed $er.Timeout $er.Interval $needle $what $er.Where $verb)
}

# v1.5.9 (P-1, owner-approved default-on): paste/paste-file used to prove only DELIVERY
# ("pasted N chars"); a webview that never accepted focus swallowed the ^v and both the
# tool and the agent called it green while the box stayed empty (2026-09-30: a 600-char
# send lost twice, third attempt landed by luck). When the caller gives NO expect at all,
# the payload TAIL is now OCR-read back from the target and an unreadable send exits 1.
# The tail (last non-empty line, trimmed, first 24 chars) is the most distinctive thing
# to look for: it lands at the caret and a truncated render cuts it off first.
# Deliberately NOT applied to `type`: SendInput Unicode is a different send path with a
# different miss mode, and its --verify stays opt-in (mixing the two would make any
# regression unattributable).
# Pure: returns the needle and prints nothing (object-returning functions must not
# pipeline-write); '' means "nothing to look for" and callers skip the readback.
function Get-AutoExpectNeedle([string]$text) {
  if ([string]::IsNullOrEmpty($text)) { return '' }
  $lines = @("$text" -split "\r?\n" | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
  if (@($lines).Count -eq 0) { return '' }
  $tail = [string]$lines[@($lines).Count - 1]
  if ($tail.Length -gt 24) { $tail = $tail.Substring(0, 24) }
  return $tail
}

# v2.2.0 (plan doc section 3, owner-approved 2026-10-01): the readback above asks to SEE the
# payload tail. An input that folds a long text into an attachment chip never renders it, so
# that ask is a guaranteed false negative - it fired on both real dispatches of 2026-10-01
# (12,774 and 8,556 chars) while both sends had actually worked. These are the second
# criterion the plan asked for: accept "the target demonstrably received content", and say
# out loud which receipt was used. Single producers, so the knobs are readable and testable.
function Get-PasteFoldThreshold { return 200 }
function Get-PasteReceiptHeightMin { return 8 }

# v2.3.0 (real-machine red-1/red-2, evidence 2026-10-02 in .cowork-temp/zq-t1-RED-*.md): the
# weak receipt legs read the SCREEN rectangle of the target, so on a covered target they
# measured the COVERER: a playing video moved the pixel hash and jittered the OCR line count,
# and the paste's own foreground switch repaints the previous foreground's title bar. Both
# real-machine negative controls were falsely accepted on Program Manager (lines 212->211 and
# 209->210, exit 0). The gate value: the weak receipt chain runs ONLY while the target rect
# is clean of other windows at decision time (Get-OcclusionVerdict, the same 25-point sampler
# behind every occ: echo). 0 means any covered sample point closes the gate; the measured
# percentage is self-reported in the echo and lands in actions.log as readback=occluded-refused.
function Get-PasteReceiptOcclusionMax { return 0 }

# Pure - the whole decision, so the truth table is provable offline and the IO below only
# reports numbers. Criterion names are what the caller sees; Degraded marks every verdict
# that did NOT come from reading the payload text itself.
function Get-PasteReceiptVerdict($o) {
  if ($o.VerbatimOk) {
    return @{ Ok = $true; Degraded = $false; Criterion = 'verbatim-tail'; Detail = 'payload tail read back as text' }
  }
  $thr = [int]$o.Threshold
  $hmin = [int]$o.HeightMin
  $pc = [int]$o.PayloadChars
  if ($thr -le 0) {
    return @{ Ok = $false; Degraded = $false; Criterion = 'verbatim-tail'; Detail = 'receipt route disabled by fold-threshold=0, and the tail was not visible' }
  }
  if ($pc -lt $thr) {
    return @{ Ok = $false; Degraded = $false; Criterion = 'verbatim-tail'; Detail = ('payload is ' + $pc + ' chars, under fold-threshold=' + $thr + ' - a body this short must be readable, so no weaker receipt is offered') }
  }
  $uiTxt = 'nodes ' + [int]$o.UiaBefore + '->' + [int]$o.UiaAfter
  $hTxt = 'h ' + [int]$o.HeightBefore + '->' + [int]$o.HeightAfter + ' (needs +' + $hmin + ')'
  $lTxt = 'lines ' + [int]$o.LinesBefore + '->' + [int]$o.LinesAfter + ' hash ' + ('' + $o.HashBefore).Substring(0, [math]::Min(8, ('' + $o.HashBefore).Length)) + '->' + ('' + $o.HashAfter).Substring(0, [math]::Min(8, ('' + $o.HashAfter).Length))
  # v2.3.0 front gate (real-machine red-1/red-2): every leg below reads the target's SCREEN
  # rect, so while other windows cover that rect the legs measure the coverer - a playing
  # video moved the pixel hash and jittered the OCR line count, and the paste's own foreground
  # switch repaints the previous foreground's title bar. Both real-machine negatives were
  # falsely accepted on Program Manager (exit 0 on a target that received nothing). So past
  # the gate value the whole weak chain is closed outright: the refusal still lists every
  # leg's measured numbers, plus occluded-refused=<pct> and who covered the rect. The primary
  # verbatim road above is untouched, and on a clean target (occluded=0) the legs behave
  # exactly as shipped.
  $occPct = 0.0
  try { $occPct = [double]$o.OccludedAfter } catch { }
  if ($occPct -gt [double](Get-OptValue $o 'OcclusionMax')) {
    return @{ Ok = $false; Degraded = $false; Criterion = 'occluded-refused'; Detail = ($uiTxt + '; ' + $hTxt + '; ' + $lTxt + ' - occluded-refused=' + $occPct + '% coveredBy=' + ('' + $o.CoveredBy) + ': the target rect is covered by other windows, so a screen-derived receipt cannot tell the target from its coverer (raise the target or pass --no-expect for send-only)') }
  }
  if (([int]$o.UiaBefore -ge 0) -and ([int]$o.UiaAfter -gt [int]$o.UiaBefore)) {
    return @{ Ok = $true; Degraded = $true; Criterion = 'uia-nodes'; Detail = $uiTxt }
  }
  if ((([int]$o.HeightAfter) - ([int]$o.HeightBefore)) -ge $hmin) {
    return @{ Ok = $true; Degraded = $true; Criterion = 'grow-height'; Detail = $hTxt }
  }
  if (([int]$o.LinesBefore -ge 0) -and ([int]$o.LinesAfter -ge 0) -and ($o.LinesBefore -ne $o.LinesAfter) -and ('' + $o.HashBefore) -ne ('' + $o.HashAfter)) {
    return @{ Ok = $true; Degraded = $true; Criterion = 'lines-changed'; Detail = $lTxt }
  }
  # None of the three spoke. The refusal names ALL of them with what each measured - a bare
  # "not visible" would leave the caller guessing whether the receipt route even ran.
  return @{ Ok = $false; Degraded = $false; Criterion = 'none-of-three'; Detail = ('uia ' + $uiTxt + '; ' + $hTxt + '; ' + $lTxt) }
}

# IO pair for the receipt, called BEFORE and AFTER the send with the SAME function so a drift
# between the two sides cannot masquerade as evidence. Prints nothing. A failed leg is -1/''
# (unknown), which the verdict treats as "this criterion cannot speak", never as a change.
# Geometry is RE-QUERIED by handle on every call: Get-TargetRect trusts the fields the target
# object carried when it was resolved, and the whole point of the grow-height leg is a window
# that changed size after that snapshot (the first live round measured h 287->287 while `wins`
# saw 287->335 - the leg could never fire on the cached rect).
function Get-PasteReceipt($target) {
  $r = $null
  try {
    $rec = @(Get-WinList | Where-Object { $_.Handle -eq $target.Handle })
    if (@($rec).Count -gt 0) { $r = @{ X = $rec[0].Left; Y = $rec[0].Top; W = $rec[0].W; H = $rec[0].H } }
  } catch { }
  if ($null -eq $r) { $r = Get-TargetRect $target }
  if ($null -eq $r) { return @{ H = -1; Lines = -1; Nodes = -1; Hash = ''; Rect = @(); Occluded = -1; CoveredBy = '' } }
  $hash = ''
  $lines = -1
  $nodes = -1
  $occPct = -1
  $occBy = ''
  try { $hash = Get-RegionHash ([int]$r.X) ([int]$r.Y) ([int]$r.W) ([int]$r.H) } catch { }
  try { $oc = Invoke-OcrRegion ([int]$r.X) ([int]$r.Y) ([int]$r.W) ([int]$r.H); $lines = @($oc).Count } catch { }
  try {
    $rr = Uia-Roots $target
    if (@($rr.Roots).Count -gt 0) { $nodes = @(Uia-WalkAll $rr.Roots).Count }
  } catch { }
  # v2.3.0: the same rect, sampled by the same occlusion machinery every occ: echo uses. The
  # AFTER-side reading is what gates the weak legs (the paste's own activation can clear
  # occlusion by raising the target; the decision-time state is the honest one). -1 = the
  # sampler itself failed, which the verdict treats as gate-open (a broken sampler must not
  # silently convert every receipt into a refusal).
  try {
    $ovR = Get-OcclusionVerdict ([int]$r.X) ([int]$r.Y) ([int]$r.W) ([int]$r.H) $target.Handle 5
    $occPct = [double]$ovR.Pct
    if (@($ovR.Covering).Count -gt 0) { $occBy = (Format-OcclusionCovering $ovR.Covering $ovR.Checked).Summary }
  } catch { }
  return @{ H = [int]$r.H; Lines = $lines; Nodes = $nodes; Hash = "$hash"; Rect = ($r.X, $r.Y, $r.W, $r.H); Occluded = $occPct; CoveredBy = "$occBy" }
}

# True when a parsed parameter set ALREADY states an expectation, so the automatic
# readback has nothing to add. One producer because two gates enumerated the flags by
# hand and both missed the v3.0.0 list form (audit 2026-10-04 #2): --expect-any was
# merged into the explicit expectations at the action layer but not here, so a call
# that had already asserted an any-of list paid the verbatim-tail readback on top and
# could be failed by it. Absent keys and empty arrays both read as "nothing given";
# $null parameter set reads as "given" (the caller cannot be trusted to know the target).
function Test-ExpectationGiven($p) {
  if ($null -eq $p) { return $true }
  if ($p.NoExpect) { return $true }
  if ("$($p.Expect)" -ne '' -or "$($p.ExpectGone)" -ne '' -or "$($p.ExpectRegion)" -ne '') { return $true }
  foreach ($tKey in @('ExpectAny', 'ExpectAnyGone')) {
    foreach ($tItem in @(Get-OptValue $p $tKey)) { if ("$tItem" -ne '') { return $true } }
  }
  return $false
}

# Cheap half of the same measurement, used to decide BEFORE the send whether the receipt
# route is even in play (a short payload must never pay for it).
function Get-PasteReceiptBaseline($p, $target, [string]$text) {
  if (Test-ExpectationGiven $p) { return $null }
  if ([string]::IsNullOrEmpty($text)) { return $null }
  if ($text.Length -lt (Get-PasteFoldThreshold)) { return $null }
  return Get-PasteReceipt $target
}

# The P-1 readback itself. Returns a hashtable, prints NOTHING - the caller renders the
# message and decides the exit, so script steps keep their per-step FAIL accounting:
#   @{ Ran; Ok; NeedleChars; Elapsed; Timeout; Interval; Message; Criterion; Degraded; Receipt }
# Skips (Ran=$false) when the caller gave any explicit expectation - the single form,
# the v3.0.0 list form, or --no-expect - or the needle is empty; see
# Test-ExpectationGiven for why that enumeration is one function. The failure message
# deliberately does NOT quote the needle: it is payload text, and neither stdout nor
# actions.log carries payload (the log gets only the autoexpect=<N>chars quantity).
function Invoke-AutoPasteExpect($p, $target, [string]$needle, $receiptBase, [int]$payloadChars) {
  $skip = Test-ExpectationGiven $p
  if ($skip -or [string]::IsNullOrEmpty($needle)) {
    return @{ Ran = $false; Ok = $true; NeedleChars = 0; Elapsed = 0.0; Timeout = 0.0; Interval = 0; Message = ''; Criterion = ''; Degraded = $false; Receipt = '' }
  }
  $base = if ($target) { Get-TargetRect $target } else { $null }
  Confirm-ExpectAnchor $target $base
  $exHandle = [IntPtr]::Zero
  if ($target) { $exHandle = $target.Handle }
  $er = Invoke-Expectation $base $needle '' '' ([double]$p.TimeoutSec) ([int]$p.IntervalMs) $exHandle
  $tag = 'autoexpect=' + $needle.Length + 'chars'
  $rv = @{ Ok = $er.Ok; Degraded = $false; Criterion = 'verbatim-tail'; Detail = 'payload tail read back as text' }
  if ((-not $er.Ok) -and ($null -ne $receiptBase)) {
    $ra = Get-PasteReceipt $target
    $rv = Get-PasteReceiptVerdict @{
      VerbatimOk = $false; Threshold = (Get-PasteFoldThreshold); HeightMin = (Get-PasteReceiptHeightMin)
      PayloadChars = $payloadChars
      UiaBefore = [int]$receiptBase.Nodes; UiaAfter = [int]$ra.Nodes
      HeightBefore = [int]$receiptBase.H; HeightAfter = [int]$ra.H
      LinesBefore = [int]$receiptBase.Lines; LinesAfter = [int]$ra.Lines
      HashBefore = ('' + $receiptBase.Hash); HashAfter = ('' + $ra.Hash)
      OccludedAfter = [double]$ra.Occluded; OcclusionMax = (Get-PasteReceiptOcclusionMax); CoveredBy = "$($ra.CoveredBy)"
    }
  }
  if ($er.Ok) {
    return @{ Ran = $true; Ok = $true; NeedleChars = $needle.Length; Elapsed = $er.Elapsed; Timeout = $er.Timeout; Interval = $er.Interval; Criterion = $rv.Criterion; Degraded = $false; Receipt = "$($rv.Detail)"; Message = ('  + verified in ' + [math]::Round($er.Elapsed, 1) + ' s (patience ' + [math]::Round($er.Timeout, 1) + 's, polled every ' + $er.Interval + ' ms) - ' + $tag + ' read back from target - readback=' + $rv.Criterion) }
  }
  if ($rv.Ok) {
    # Degradation announced as it happens, in the same breath as the verdict: the caller must
    # not read a chip receipt as if the payload text had been seen.
    $m = ('  + accepted on receipt=' + $rv.Criterion + ' (' + $rv.Detail + ') - the payload tail was NOT visible, so this is the weaker second criterion for a folded long payload (' + $tag + ', scanned ' + $er.Where + ' for ' + [math]::Round($er.Elapsed, 1) + 's, patience ' + [math]::Round($er.Timeout, 1) + 's, polled every ' + $er.Interval + ' ms)')
    return @{ Ran = $true; Ok = $true; NeedleChars = $needle.Length; Elapsed = $er.Elapsed; Timeout = $er.Timeout; Interval = $er.Interval; Criterion = $rv.Criterion; Degraded = $true; Receipt = "$($rv.Detail)"; Message = $m }
  }
  # v4.2.0 (external feedback item 1, 2026-10-10): the FAILURE path has to carry numbers,
  # not a shrug. Two shapes, both self-labelled:
  #   * baseline existed (payload >= fold-threshold) -> $rv already ran all three v2.2.0
  #     legs (uia-nodes / grow-height / lines-changed) and $rv.Detail reports what each
  #     one measured, so none-of-three reads as "we looked, here are the numbers";
  #   * no baseline (short payload) -> the SAME three measurements are taken on the AFTER
  #     state alone and printed as after-state:, explicitly marked "not a verdict" because
  #     there is no before to compare against. Offline ($target $null) skips the read.
  # The old code printed neither, so the failure read as "probably nothing landed" while
  # the text was already in the composer - and the suggested exit was a RESEND.
  $diagTxt = 'after-state: diag-skipped(no-target)'
  $why = ''
  if ($null -ne $receiptBase) {
    $why = ' receipt-tried=' + $rv.Criterion + ' (' + $rv.Detail + ', fold-threshold=' + (Get-PasteFoldThreshold) + ')'
    $failReceipt = "$($rv.Detail)"
  }
  else {
    if ($null -ne $target) {
      try {
        $raD = Get-PasteReceipt $target
        $diagTxt = ('after-state: uia-nodes=' + [int]$raD.Nodes + ' grow-height=' + [int]$raD.H + ' lines-changed=' + [int]$raD.Lines + ' occluded=' + [double]$raD.Occluded + '% coveredBy=' + "$($raD.CoveredBy)")
      } catch { $diagTxt = 'after-state: unavailable (receipt reader threw)' }
    }
    $why = ' receipt-tried=verbatim-tail-only (tail NOT read back; fold-threshold=' + (Get-PasteFoldThreshold) + ', payload below it so no baseline was taken and no weaker receipt can be offered; ' + $diagTxt + ' - AFTER-state only, not a verdict)'
    $failReceipt = $diagTxt
  }
  return @{ Ran = $true; Ok = $false; NeedleChars = $needle.Length; Elapsed = $er.Elapsed; Timeout = $er.Timeout; Interval = $er.Interval; Criterion = $rv.Criterion; Degraded = $false; Receipt = $failReceipt; Message = ('WARN: payload not visible in target after send -- may already have landed, DO NOT resend blindly (dark/small text is often unreadable to OCR). Verify first with read-text / uia-find / find-text on the target; only if verified absent, click INSIDE the editable text''s own rect first, then paste WITHOUT --to. Or pass --no-expect to accept send-only. (' + $tag + ', scanned ' + $er.Where + ' for ' + [math]::Round($er.Elapsed, 1) + 's, patience ' + [math]::Round($er.Timeout, 1) + 's, polled every ' + $er.Interval + ' ms)' + $why) }
}

# Shared failure gate for the P-1 readback, so the throw (and therefore the standalone
# ERROR + exit 1 and the script-step FAIL line) has ONE wording and is unit-testable
# offline. Silent on a met verdict; throws on an unmet one.
function Confirm-AutoExpect($auto) {
  if ($null -eq $auto -or -not $auto.Ran -or $auto.Ok) { return }
  $extra = ''
  if ($auto.Criterion) { $extra = ' (readback=' + $auto.Criterion + $(if ($auto.Receipt) { ', ' + $auto.Receipt } else { '' }) + ')' }
  throw ('autoexpect NOT met after ' + [math]::Round($auto.Elapsed, 1) + ' s (patience ' + [math]::Round($auto.Timeout, 1) + 's): payload tail (autoexpect=' + $auto.NeedleChars + 'chars) not visible in the target' + $extra + ' - may already have landed, DO NOT resend blindly: verify with read-text / uia-find / find-text first; pass --no-expect to accept send-only')
}

# v1.6.0 (A-1, J-03 A): open-and-pick's optional screenshot sub-region, window-relative
# x,y,w,h in ONE token (the same shape --guard-region/--expect-region use for their
# coordinate part). Pure: format validation only - bounds against the live window are
# checked after Resolve-Target, so bad-format errors are provable offline.
function Parse-OpenPickRegion([string]$spec) {
  if (-not $spec) { return $null }
  if ($spec -notmatch '^(\d+),(\d+),(\d+),(\d+)$') { throw "open-and-pick: --region needs x,y,w,h (window-relative pixels), got: '$spec'" }
  $rx = [int]$Matches[1]; $ry = [int]$Matches[2]; $rw = [int]$Matches[3]; $rh = [int]$Matches[4]
  if ($rw -le 0 -or $rh -le 0) { throw "open-and-pick: --region width/height must be > 0, got: $spec" }
  return @{ X = $rx; Y = $ry; W = $rw; H = $rh }
}

# v2.3.0 (real-machine red-3, evidence 2026-10-02): find --region's inline validation was
# INVERTED - it demanded "count of non-numeric segments == 4", so every VALID x,y,w,h threw
# ("--region needs x,y,w,h") while garbage like a,b,c,d slipped through to die later at the
# [int] cast. Extracted here as the single pure producer of both error strings; the find
# handler must call this and nothing else (selftest lint pins both sides). Negative numbers
# stay legal (the original character class allowed them); w/h<=0 and segment-count<>4 stay
# refused with the same named errors the live machine already showed.
function Parse-FindRegionSpec([string]$spec) {
  $rp = @("$spec" -split ',')
  $bad = @($rp | Where-Object { $_ -notmatch '^-?\d+$' })
  if (@($rp).Count -ne 4 -or @($bad).Count -ne 0) {
    throw "find: --region needs x,y,w,h in screen pixels, got: $spec"
  }
  $rect = @{ X = [int]$rp[0]; Y = [int]$rp[1]; W = [int]$rp[2]; H = [int]$rp[3] }
  if ($rect.W -le 0 -or $rect.H -le 0) { throw "find: --region w/h must be positive, got: $spec" }
  return $rect
}

# v1.5.9/P-4b: occlusion awareness only sees OTHER windows covering the target; a scrim
# INSIDE the target window (in-app modal, loading veil, dark overlay) is invisible to
# wins/occluded% while it destroys the read. Measured incident (2026-09-30): a "finish
# security verification" modal took a ZCode read-text from 54 lines to 2, and "0 hits"
# was briefly misread as "the card is gone". The default policy has an area floor and
# two density bands: below 500000 px2 the threshold is relaxed to 1.0 line per 100k px2
# (legal sparse dialogs), while larger regions retain 1.5 (large masked areas). A caller
# supplied threshold can lower either band; 0 remains the explicit off switch. Stateless
# by design (no cross-call memory), and a HINT ONLY: it never changes a return value or
# an exit code, so the occlusion WARN / guard FAIL grading stays intact.
function Get-SparseReadPolicy([long]$area, [double]$minDensity) {
  $floor = 300000L
  $cutoff = 500000L
  if ($minDensity -le 0) {
    return @{ Enabled = $false; Band = 'off'; Threshold = 0.0; AreaFloor = $floor; AreaCutoff = $cutoff }
  }
  if ($area -lt $floor) {
    return @{ Enabled = $false; Band = 'below-area-floor'; Threshold = $minDensity; AreaFloor = $floor; AreaCutoff = $cutoff }
  }
  $band = if ($area -lt $cutoff) { 'small-area' } else { 'large-area' }
  $threshold = if ($band -eq 'small-area') { [math]::Min($minDensity, 1.0) } else { $minDensity }
  return @{ Enabled = $true; Band = $band; Threshold = [double]$threshold; AreaFloor = $floor; AreaCutoff = $cutoff }
}

function Test-SparseReadability([int]$w, [int]$h, [int]$lineCount, [double]$minDensity) {
  $area = [long]$w * [long]$h
  $policy = Get-SparseReadPolicy $area $minDensity
  if (-not $policy.Enabled) { return $false }
  return (($lineCount / ($area / 100000.0)) -lt $policy.Threshold)
}

# One producer for the sparse-read hint. Self-reports the policy band and threshold in force (the
# v1.5.7 self-reported-value rule) and names the escape hatch, so a reader can act
# instead of guessing what "too few lines" meant.
#
# $subject is not cosmetic. Every other part of a file-mode read insists the numbers are IMAGE px
# (img-rect=, "NOT a screen rect", the --json refusal), so a hint that calls the same thing a
# "region" and blames "a large window" contradicts its own output - and the cause list is genuinely
# different: a stored capture with few lines may simply be a picture, which no window can be.
function Build-SparseReadWarn([int]$w, [int]$h, [int]$lineCount, [double]$minDensity, [string]$subject = 'region') {
  $policy = Get-SparseReadPolicy ([long]$w * [long]$h) $minDensity
  $cause = 'a large window this unreadable usually means an in-window modal/scrim, a loading veil, or a very low-contrast theme'
  $shape = 'region'
  if ($subject -eq 'image') {
    $shape = 'image'
    $cause = 'a stored capture this unreadable usually means a low-contrast theme, an image that is mostly graphics, or an area the recognizer dropped (re-read it with --scale tiled, which subdivides the image)'
  }
  return ('WARN: ' + $shape + ' is ' + $w + 'x' + $h + ' but only ' + $lineCount + ' line(s) read -- ' + $cause + '. Do NOT treat "not found" as "absent". (sparse-policy=' + $policy.Band + '; active-threshold=' + $policy.Threshold + ' lines per 100k px2; min-line-density=' + $minDensity + '; pass --min-line-density 0 to silence)')
}

# --verify for type/type-in: OCR the target window after sending and require
# the typed text (first 40 chars, whitespace-collapsed) to be visible, so a
# swallowed send becomes a loud ERROR instead of a silent one. Naturally fails
# on masked/password fields - do not use it there.
#
# Re-poll the needle rather than sleeping once then looking: a fixed delay was
# a false negative on real terminals (the text had landed, the 500 ms snapshot
# was just early). Waiting for pixel stability is also wrong here - a blinking
# caret means such a region never settles.
function Invoke-TypedVerify($target, [string]$text, [double]$timeoutSec = 4) {
  $eng = Get-OcrEngine
  if ($null -eq $eng) { return '  [verify skipped: OCR unavailable]' }
  $rect = Get-TargetRect $target
  if ($null -eq $rect) { throw 'verify: cannot determine target window rect' }
  $needle = ($text -replace '\s+', ' ').Trim()
  if ($needle.Length -gt 40) { $needle = $needle.Substring(0, 40) }
  if ($timeoutSec -lt 0.5) { $timeoutSec = 0.5 }
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $seenLines = @()
  $polls = 0
  while ($true) {
    $polls++
    $v = Find-OcrHitsScaled $rect.X $rect.Y $rect.W $rect.H $needle
    $seenLines = $v.Lines
    if ($v.Hits.Count -gt 0) {
      return "  [verify: OCR match after $([math]::Round($sw.Elapsed.TotalSeconds, 1))s$(if ($v.Scaled) { ' via 2x upscale' })$(Get-OcrFoldMarker $v.Hits)]"
    }
    if ($sw.Elapsed.TotalSeconds -ge $timeoutSec) { break }
    Start-Sleep -Milliseconds 400
  }
  # v1.5.7: the sample list goes through the one OCR tail, so it states how many lines
  # there really were and how many it hid (a verify failure read "8 lines, none of them
  # mine" and sent people hunting for missing text that was simply not printed).
  $seen = Format-OcrSampleTail $seenLines 6
  # the patience ACTUALLY spent, printed next to the patience asked for: the
  # requested number on its own only proves the value reached this message, while
  # the pair proves it also bounded the loop. v1.5.3's --verify-timeout case needs
  # that - wall-clock timing of a whole child process buries a 1s difference in
  # startup noise (measured: timeout 1 took 3.75s, timeout 2 took 3.51s).
  $waited = [math]::Round($sw.Elapsed.TotalSeconds, 1)
  # assigned to a variable, not interpolated into the message: a dollar-paren
  # wrapper around this helper is the form the source lint forbids (it caught
  # this while being written). Informational only - the throw and the exit code
  # are unchanged, exactly as the task order requires.
  $xcNote = Get-UiaVerifyCrossCheck $target $needle
  throw "verify FAILED after ${timeoutSec}s (waited ${waited}s, $polls OCR read(s)): typed text '$needle' not visible in target window (OCR) - the send may have been swallowed, the field may mask input, or the target renders text OCR cannot read. Visible: $seen$xcNote"
}

# v1.5.2 WP-5 (audit R-10, branch B): when OCR cannot confirm what was typed, the
# accessibility tree can usually answer exactly - Windows controls expose their
# content as the element Name (measured: uia-find returned 'QXHELLO123' verbatim
# while OCR read 'QXHELL01231'). This is INFORMATION ONLY: it never changes the
# verdict or the exit code. Gating on it would be a new capability and needs a
# minor version plus the owner's sign-off (task order section 6).
# Every UIA Name a window exposes, as data. Measured 2026-09-29: a WinForms
# TextBox with UseSystemPasswordChar renders dots on screen yet still reports its
# REAL text as the element Name (masked field holding 'QXMASKPROBE7' -> Name
# 'QXMASKPROBE7'), so this is a byte-exact content channel for exactly the fields
# OCR cannot read. Two consumers: the verify cross-check below (informational)
# and the live --verify-timeout case, which uses it to prove the keys arrived.
function Get-UiaWindowNames($target) {
  $list = New-Object System.Collections.ArrayList
  $err = ''
  try {
    $roots = Uia-Roots $target
    foreach ($el in (Uia-WalkAll $roots.Roots)) {
      $nm = ''
      try { $nm = $el.Current.Name } catch { }
      if ($nm) { [void]$list.Add("$nm") }
    }
  } catch { $err = $_.Exception.Message }
  return @{ Names = @($list); Error = $err }
}

function Get-UiaVerifyCrossCheck($target, [string]$text) {
  $snap = Get-UiaWindowNames $target
  if ($snap.Error) { return " | UIA cross-check unavailable ($($snap.Error))" }
  $names = $snap.Names
  if (@($names).Count -eq 0) { return ' | UIA cross-check: this tree exposes no named elements (a11y-blind app) - nothing to compare against' }
  $hitNames = @($names | Where-Object { $_.IndexOf($text, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 })
  if (@($hitNames).Count -gt 0) {
    $shown = "$($hitNames[0])"
    if ($shown.Length -gt 60) { $shown = $shown.Substring(0, 60) + '...' }
    return " | UIA cross-check: an element IS named with the typed text ('$shown') - the send most likely DID land and OCR misread it (verdict unchanged by design)"
  }
  return " | UIA cross-check: none of the $(@($names).Count) named element(s) contains the typed text - consistent with the OCR miss"
}

# v1.5.2 WP-5 (audit R-11, branch D): read a file that is about to be SENT to a
# real window, and refuse anything that is not valid UTF-8 instead of pasting
# mojibake. Measured live: a GBK/ANSI copy of the 35-char sample came back as
# "pasted 53 chars" of garbage with exit 0 - the target received junk and nothing
# warned. This machine reads BOM-less files as ANSI/GBK in PS 5.1 (cross-project
# rule 13), so mis-encoded payload files are a local hazard, not theoretical.
# Strict decoder (throwOnInvalidBytes): a single invalid byte sequence aborts with
# the leading bytes printed so the caller can see it IS an encoding problem.
function Read-SendFileUtf8([string]$path) {
  $bytes = [System.IO.File]::ReadAllBytes($path)
  $start = 0
  $hadBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
  if ($hadBom) { $start = 3 }
  $strict = New-Object System.Text.UTF8Encoding($false, $true)
  try {
    $text = $strict.GetString($bytes, $start, ($bytes.Length - $start))
  } catch {
    $take = [Math]::Min(16, $bytes.Length)
    $hex = ''
    if ($take -gt 0) { $hex = (($bytes[0..($take - 1)] | ForEach-Object { $_.ToString('X2') }) -join ' ') }
    throw "file is not valid UTF-8: $path (first bytes: $hex) - sending it would paste mojibake into the target. Re-save as UTF-8 without BOM, e.g. [IO.File]::WriteAllText(path, text, (New-Object Text.UTF8Encoding(`$false))), then retry."
  }
  return @{ Text = $text; Bytes = $bytes.Length; HadBom = $hadBom }
}

# Polls GetForegroundWindow until the target actually owns the foreground: six looks
# with a 0/100/200/300/300/300 ms back-off in front of each, so ~1.2 s of total
# patience. v1.5.2 WP-6 (audit R-13): check FIRST, then back off. The old loop slept
# before its first test, so a window that was already (or instantly became)
# foreground still paid a full beat per guarded action, and a chain of them paid it
# again and again. Semantics are unchanged: success still requires
# GetForegroundWindow() == this handle, the total patience is the same ~1.2s, and
# a failure still returns $false so Resolve-Target refuses to send a single key.
function Wait-Foreground($win) {
  foreach ($ms in @(0, 100, 200, 300, 300, 300)) {
    if ($ms -gt 0) { Start-Sleep -Milliseconds $ms }
    if ([DT]::GetForegroundWindow() -eq $win.Handle) { return $true }
  }
  return $false
}

# Returns $true only if the window REALLY ended up in the foreground.
# SetForegroundWindow can silently fail (foreground lock) and merely flash the
# taskbar, so its return value is never trusted - only GetForegroundWindow is.
# On failure, retries once via minimize + restore.
function Activate-Win($win) {
  if ([DT]::IsIconic($win.Handle)) { [void][DT]::ShowWindow($win.Handle, 9) }
  [void][DT]::BringWindowToTop($win.Handle)
  [void][DT]::SetForegroundWindow($win.Handle)
  if (Wait-Foreground $win) { return $true }
  # fallback: minimize (6) then restore (9) and retry once
  [void][DT]::ShowWindow($win.Handle, 6)
  Start-Sleep -Milliseconds 200
  [void][DT]::ShowWindow($win.Handle, 9)
  [void][DT]::BringWindowToTop($win.Handle)
  [void][DT]::SetForegroundWindow($win.Handle)
  return (Wait-Foreground $win)
}

# Keystrokes go to whatever is focused, so every text-sending command reports the
# target it actually used. Never send text blind: pass <sel> or run `focus` first.
function Get-ForegroundInfo {
  $h = [DT]::GetForegroundWindow()
  $procId = 0
  [void][DT]::GetWindowThreadProcessId($h, [ref]$procId)
  return "pid=$procId title='$([DT]::Text($h))'"
}

# --- IME observability ---------------------------------------------------
# The keyboard layout belongs to the FOREGROUND window's thread. HIWORD of the
# HKL != 0 means an IME is active over a base layout (e.g. Chinese) - plain
# SendKeys then gets swallowed by the IME or pops a candidate window.
# `ime` reports the state; type/type-in temporarily request the plain English
# layout (WM_INPUTLANGCHANGEREQUEST = 0x0050, lParam = HKL 0x00000409) on the
# foreground window and restore the original HKL after sending.
function Get-FgThreadInfo {
  $h = [DT]::GetForegroundWindow()
  $procId = 0
  $tid = [DT]::GetWindowThreadProcessId($h, [ref]$procId)
  return @{ Hwnd = $h; Tid = $tid; Pid = $procId; Title = [DT]::Text($h); Hkl = [DT]::GetKeyboardLayout($tid) }
}

function Format-Hkl([IntPtr]$hkl) {
  $v = $hkl.ToInt64()
  $lang = $v -band 0xFFFF
  $imeId = ($v -shr 16) -band 0xFFFF
  $ime = if ($imeId -ne 0) { 'yes' } else { 'no' }
  return "hkl=0x$($v.ToString('X8')) lang=0x$($lang.ToString('X4')) ime=$ime"
}

# v1.3.0: type/type-in no longer switch the HKL - they send via SendInput
# KEYEVENTF_UNICODE, which bypasses the IME entirely. `ime` still reports the
# HKL state; ime-state/ime-en/ime-cn handle the conversion mode.

# Pure branch of Save-ClipboardState: which kind is this clipboard? Extracted
# because a faithful text+FileDrop clipboard CANNOT be synthesized from PS (see
# the note on Save-ClipboardState), so the branch itself has to be unit-tested.
# CU-OPS package G (v4.6.0): the image carrier joins the branch. The two-argument form is
# unchanged for every existing caller; hasImage is an OPTIONAL third argument, and the image
# kinds are named text+image / files+image / text+files+image so a restore can tell which
# parts it must verify and which part is genuinely missing.
function Resolve-ClipboardKind([bool]$hasText, [bool]$hasFiles, [bool]$hasImage = $false) {
  if ($hasImage) {
    $parts = @()
    if ($hasText) { $parts += 'text' }
    if ($hasFiles) { $parts += 'files' }
    if ($parts.Count -eq 0) { return 'image' }
    return (($parts + @('image')) -join '+')
  }
  if ($hasText -and $hasFiles) { return 'both' }
  if ($hasText) { return 'text' }
  if ($hasFiles) { return 'files' }
  return 'other'
}

# CU-OPS package G (v4.6.1): the formats a restore branch can faithfully reproduce.
# Everything outside this set (HTML Format, Rich Text Format, PNG, Preferred DropEffect,
# any private/app format) is content this tool cannot put back. A clipboard carrying text
# AND one of those must NOT be written over on the strength of the text coming back:
# "the text hash matches" is not "every format is preserved".
$script:ClipboardPureFormats = @('UnicodeText', 'Text', 'Locale', 'OEMText', 'FileDrop', 'Bitmap', 'DIB')
function Get-ClipboardFormatPlan([string[]]$formats) {
  $list = @($formats | Where-Object { $_ -ne '' } | Sort-Object -Unique)
  $extras = @($list | Where-Object { $script:ClipboardPureFormats -notcontains $_ })
  $hasText = @($list | Where-Object { $_ -in @('UnicodeText', 'Text', 'Locale', 'OEMText') }).Count -gt 0
  $hasFiles = $list -contains 'FileDrop'
  $hasImage = @($list | Where-Object { $_ -in @('Bitmap', 'DIB') }).Count -gt 0
  $kind = if ($list.Count -eq 0) { 'none' } else { Resolve-ClipboardKind $hasText $hasFiles $hasImage }
  if (@($extras).Count -gt 0) { $kind = 'other' }
  return [pscustomobject]@{ Kind = $kind; Formats = $list; Extras = $extras; HasText = $hasText; HasFiles = $hasFiles; HasImage = $hasImage }
}

# Snapshot of the current clipboard so commands that overwrite it can put the
# old content back afterwards. Supported kinds: text, FileDrop (file list) and the
# image carrier (Bitmap/DIB, saved to a PNG for the restore), plus their combinations.
# v4.6.1: the FORMAT LIST decides first - any format outside $script:ClipboardPureFormats
# makes the snapshot kind=other and its content is deliberately NOT read, because this
# tool cannot put it back; an empty clipboard is reported as 'none'.
# v1.5.2 WP-4 (audit R-05, code-level): text and FileDrop are NO LONGER
# exclusive branches - the old `if ContainsText ... elseif ContainsFileDropList`
# saved only the text, so a clipboard carrying both lost the file list on
# restore. Kind is now none/text/files/both via Resolve-ClipboardKind.
# HONESTY NOTE measured today: this machine never showed a real trigger. A
# WinForms-synthesized mixed clipboard (DataObject with FileDrop + UnicodeText,
# SetDataObject copy=true) reports ContainsFileDropList()=True while
# GetFileDropList() comes back EMPTY, and a fresh process sees no FileDrop at
# all - so it is not a faithful Explorer-style copy; and Explorer's own copy is
# not reproducible from a script (Shell InvokeVerb('copy') is a no-op here).
# The fix is therefore defensive correctness, verified by unit (branch) + live
# (exact text and exact path round trips) + an echo-honesty test, NOT by a
# real-world mixed clipboard.
# NOTE: save/restore is strictly PER INVOCATION (each command captures its own
# $clip local variable and restores it in the same process). There is no shared
# queue: a "clipboard restored (FileDrop ...)" echo during a TEXT paste simply
# means the clipboard held a file list when this paste started (e.g. left there
# on purpose by an earlier copy-file) - restoring it is the correct behaviour.
function Save-ClipboardState {
  $st = @{ Kind = 'other'; Text = ''; Files = @(); ImagePath = ''; ImageSaveError = $false; Formats = @(); Extras = @() }
  try {
    # The FORMAT LIST decides first. A clipboard with formats outside the pure set is not
    # restorable as a whole, so its content is deliberately not read either - nothing this
    # tool could put back is lost by not opening it.
    $formats = @()
    try {
      $do = [System.Windows.Forms.Clipboard]::GetDataObject()
      if ($null -ne $do) { $formats = @($do.GetFormats()) }
    } catch { $formats = @() }
    $plan = Get-ClipboardFormatPlan $formats
    $st.Formats = @($plan.Formats)
    $st.Extras = @($plan.Extras)
    $st.Kind = $plan.Kind
    if ($plan.Kind -eq 'other' -or $plan.Kind -eq 'none') { return $st }
    $hasText = [bool]$plan.HasText
    $hasFiles = [bool]$plan.HasFiles
    $hasImage = [bool]$plan.HasImage
    $txt = ''
    if ($hasText) { $txt = [System.Windows.Forms.Clipboard]::GetText() }
    $files = @()
    if ($hasFiles) { $files = @([System.Windows.Forms.Clipboard]::GetFileDropList()) }
    $imgPath = ''
    $imgErr = $false
    if ($hasImage) {
      # CU-OPS package G: the image is carried as a PNG on disk, because a restore happens
      # in the same process but the DataObject form does not survive a re-save reliably.
      # "detected but could not be saved" is its OWN answer (ImageSaveError), never folded
      # into "no image" - a restore that silently drops it must say so.
      try {
        $img = [System.Windows.Forms.Clipboard]::GetImage()
        if ($null -eq $img) { $imgErr = $true } else {
          try {
            $p = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), ('desktop-clip-' + [guid]::NewGuid().ToString('N') + '.png'))
            $img.Save($p, [System.Drawing.Imaging.ImageFormat]::Png)
            if (Test-Path -LiteralPath $p -PathType Leaf) { $imgPath = $p } else { $imgErr = $true }
          } finally { $img.Dispose() }
        }
      } catch { $imgErr = $true }
    }
    $st = @{ Kind = $plan.Kind; Text = $txt; Files = $files; ImagePath = $imgPath; ImageSaveError = $imgErr; Formats = @($plan.Formats); Extras = @($plan.Extras) }
  } catch { $st = @{ Kind = 'other'; Text = ''; Files = @(); ImagePath = ''; ImageSaveError = $false; Formats = @(); Extras = @() } }
  return $st
}

# CU-OPS package G (v4.6.1): content identity for the image carrier. Width/Height
# equality is NOT content equality - two different pictures share a size - so a
# restore that printed "restored" after a size match could put back the wrong
# picture and still look green. Both sides are normalized to 24bpp RGB and hashed
# over the raw scan lines; the answer is one digest, not a resemblance heuristic.
function Get-BitmapRgbHash($bmp) {
  $clone = $null
  $locked = $null
  $gr = $null
  try {
    $w = [int]$bmp.Width
    $h = [int]$bmp.Height
    $clone = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $gr = [System.Drawing.Graphics]::FromImage($clone)
    $gr.DrawImage($bmp, 0, 0, $w, $h)
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $locked = $clone.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $bytes = New-Object byte[] ([int]$locked.Stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($locked.Scan0, $bytes, 0, $bytes.Length)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $digest = $sha.ComputeHash($bytes) } finally { $sha.Dispose() }
    $hex = (@($digest | ForEach-Object { $_.ToString('x2') }) -join '')
    return @{ W = $w; H = $h; Hash = $hex }
  } finally {
    if ($null -ne $gr) { try { $gr.Dispose() } catch { } }
    if ($null -ne $locked -and $null -ne $clone) { try { $clone.UnlockBits($locked) } catch { } }
    if ($null -ne $clone) { try { $clone.Dispose() } catch { } }
  }
}

# CU-OPS package G (v4.6.1): the restore note is the ONLY thing the caller sees, so
# "did it really come back" has to be readable from it mechanically. paste/paste-file
# turn partial/failed into a non-zero exit - a restore that lost the user's clipboard
# must never end with the same code as one that put it back.
function Get-ClipboardRestoreOutcome([string]$note) {
  if ($note -like 'clipboard PARTIALLY restored*') { return 'partial' }
  if ($note -like 'clipboard restore failed*') { return 'failed' }
  if ($note -like 'skipped clipboard restore*') { return 'skipped' }
  if ($note -like 'clipboard restored*') { return 'ok' }
  return 'unknown'
}

# Returns a human readable note for the command echo. Never throws. The 'both' path
# writes ONE DataObject carrying FileDrop + UnicodeText - two successive Clipboard
# setters would replace each other, which is exactly how the old code lost the files.
# Images and other formats are still NOT restored (verified limitation: they are
# reported as skipped, never claimed as supported).
# v4.6.1 (CU-OPS package G): EVERY branch now reads the content back before claiming
# success - text and FileDrop by exact comparison, the image by RGB digest. A branch
# that only wrote and returned "restored" could not tell a lost clipboard from a
# put-back one, which is the same false-green class this command exists to kill.
function Restore-ClipboardState($st) {
  if ($null -eq $st) { return 'skipped clipboard restore (nothing saved)' }
  $kind = "$($st.Kind)"
  # CU-OPS package G: an image-bearing clipboard is restored through ONE DataObject so
  # text/FileDrop/Bitmap travel together, then EVERY requested part is verified by
  # CONTENT. A part that did not come back makes the answer PARTIALLY, named part by part.
  if ($kind -like '*image*') {
    $path = [string]$st.ImagePath
    if ($path -eq '' -or -not (Test-Path -LiteralPath $path -PathType Leaf)) {
      return 'clipboard restore failed (the image was detected but its PNG could not be saved - the missing part is NOT recoverable)'
    }
    $bmp = $null
    try {
      $bmp = New-Object System.Drawing.Bitmap($path)
      $wantFiles = @($st.Files)
      $wantText = [string]$st.Text
      $sc = New-Object System.Collections.Specialized.StringCollection
      foreach ($f in $wantFiles) { [void]$sc.Add($f) }
      $db = New-Object System.Windows.Forms.DataObject
      if ($wantFiles.Count -gt 0) { [void]$db.SetData([System.Windows.Forms.DataFormats]::FileDrop, $sc) }
      if ($wantText -ne '') { [void]$db.SetData([System.Windows.Forms.DataFormats]::UnicodeText, $wantText) }
      [void]$db.SetData([System.Windows.Forms.DataFormats]::Bitmap, $bmp)
      [System.Windows.Forms.Clipboard]::SetDataObject($db, $true)
      Start-Sleep -Milliseconds 200
      $gotT = ''
      if ([System.Windows.Forms.Clipboard]::ContainsText()) { $gotT = [System.Windows.Forms.Clipboard]::GetText() }
      $gotF = @()
      if ([System.Windows.Forms.Clipboard]::ContainsFileDropList()) { $gotF = @([System.Windows.Forms.Clipboard]::GetFileDropList()) }
      $gotImg = $null
      if ([System.Windows.Forms.Clipboard]::ContainsImage()) { $gotImg = [System.Windows.Forms.Clipboard]::GetImage() }
      $textOk = ($wantText -eq '' -or $gotT -ceq $wantText)
      $filesOk = ($wantFiles.Count -eq 0 -or ($gotF.Count -eq $wantFiles.Count -and (($gotF -join '|') -ceq ($wantFiles -join '|'))))
      # v4.6.1: equal Width/Height was never evidence of equal pixels - the digest is.
      $hWant = Get-BitmapRgbHash $bmp
      $hGot = $null
      if ($null -ne $gotImg) { $hGot = Get-BitmapRgbHash $gotImg }
      $imgOk = ($null -ne $hGot -and ($hWant.Hash -ceq $hGot.Hash))
      $imgNote = if ($null -ne $hGot) {
        if ($imgOk) { "rgb-sha256=$($hWant.Hash.Substring(0, 12))" } else { "different pixels (wanted rgb-sha256=$($hWant.Hash.Substring(0, 12)), got $($hGot.Hash.Substring(0, 12)))" }
      } else { 'no image' }
      if ($null -ne $gotImg) { $gotImg.Dispose() }
      if ($textOk -and $filesOk -and $imgOk) {
        return "clipboard restored (previous content was ${kind}: $($wantText.Length) chars, $(@($wantFiles).Count) file(s), image $($bmp.Width)x$($bmp.Height))"
      }
      return "clipboard PARTIALLY restored (kind=$kind; wanted text=$($wantText.Length) chars / FileDrop=$(@($wantFiles).Count) / image $($bmp.Width)x$($bmp.Height); got text=$($gotT.Length) chars / FileDrop=$($gotF.Count) / $imgNote) - the missing part is NOT recoverable by this tool"
    } catch {
      return 'clipboard restore failed (' + $kind + ')'
    } finally {
      if ($null -ne $bmp) { $bmp.Dispose() }
      Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    }
  }
  switch ($kind) {
    'text' {
      try {
        Set-Clipboard -Value $st.Text
        Start-Sleep -Milliseconds 200
        $gotT = ''
        if ([System.Windows.Forms.Clipboard]::ContainsText()) { $gotT = [System.Windows.Forms.Clipboard]::GetText() }
        if ($gotT -ceq $st.Text) {
          return "clipboard restored (previous content was text, $($st.Text.Length) chars)"
        }
        return "clipboard PARTIALLY restored (wanted text $($st.Text.Length) chars; read back $($gotT.Length) chars that do not match - the text did not come back verbatim)"
      } catch { return 'clipboard restore failed (text)' }
    }
    'files' {
      try {
        $wantF = @($st.Files)
        $sc = New-Object System.Collections.Specialized.StringCollection
        foreach ($f in $wantF) { [void]$sc.Add($f) }
        [System.Windows.Forms.Clipboard]::SetFileDropList($sc)
        Start-Sleep -Milliseconds 200
        $gotF = @()
        if ([System.Windows.Forms.Clipboard]::ContainsFileDropList()) { $gotF = @([System.Windows.Forms.Clipboard]::GetFileDropList()) }
        $filesOk = ($wantF.Count -gt 0 -and $gotF.Count -eq $wantF.Count -and (($gotF -join '|') -ceq ($wantF -join '|')))
        if ($filesOk) {
          return "clipboard restored (previous content was FileDrop, $($wantF.Count) file(s))"
        }
        return "clipboard PARTIALLY restored (wanted FileDrop $($wantF.Count) file(s); got $($gotF.Count) from the read-back - the list did not come back verbatim)"
      } catch { return 'clipboard restore failed (FileDrop)' }
    }
    'both' {
      try {
        $sc = New-Object System.Collections.Specialized.StringCollection
        foreach ($f in @($st.Files)) { [void]$sc.Add($f) }
        $db = New-Object System.Windows.Forms.DataObject
        [void]$db.SetData([System.Windows.Forms.DataFormats]::FileDrop, $sc)
        [void]$db.SetData([System.Windows.Forms.DataFormats]::UnicodeText, $st.Text)
        [System.Windows.Forms.Clipboard]::SetDataObject($db, $true)
        Start-Sleep -Milliseconds 200
        # Verify by CONTENT, not by Contains* flags: measured today, a clipboard
        # written this way answers ContainsFileDropList()=True while
        # GetFileDropList() is EMPTY. A flag check would print "restored" over
        # zero files - exactly the false green this command must never produce.
        $gotT = ''
        if ([System.Windows.Forms.Clipboard]::ContainsText()) { $gotT = [System.Windows.Forms.Clipboard]::GetText() }
        $gotF = @()
        if ([System.Windows.Forms.Clipboard]::ContainsFileDropList()) { $gotF = @([System.Windows.Forms.Clipboard]::GetFileDropList()) }
        $wantF = @($st.Files)
        $textOk = ($gotT -ceq $st.Text)
        $filesOk = ($gotF.Count -eq $wantF.Count -and $gotF.Count -gt 0 -and (($gotF -join '|') -ceq ($wantF -join '|')))
        if ($textOk -and $filesOk) {
          return "clipboard restored (previous content was text + FileDrop, $($st.Text.Length) chars, $($wantF.Count) file(s))"
        }
        return "clipboard PARTIALLY restored (wanted text + FileDrop: $($st.Text.Length) chars / $($wantF.Count) file(s); got text=$($gotT.Length) chars / FileDrop=$($gotF.Count) file(s)) - the missing part is NOT recoverable by this tool"
      } catch { return 'clipboard restore failed (text + FileDrop)' }
    }
    'none' { return 'skipped clipboard restore (empty)' }
    default { return 'skipped clipboard restore (non-text)' }
  }
}

# CU-OPS package G (v4.6.1): name the formats that made a clipboard 'other'. A refusal
# that only says "unknown formats" tells the user nothing they can act on; the names are
# what make --replace-clipboard an informed choice. Short list, bounded length.
function Format-ClipboardFormatNames($formats) {
  $list = @($formats | Where-Object { "$_" -ne '' })
  if ($list.Count -eq 0) { return '' }
  $shown = @($list | Select-Object -First 6)
  $tail = if ($list.Count -gt 6) { ' +' + ($list.Count - 6) + ' more' } else { '' }
  return (($shown -join ', ') + $tail)
}

# CU-OPS package G (v4.6.0): ONE verdict, read by both the write gate and clip-info.
# "Restorable" means this tool has a restore branch that can verify the content back:
# empty, text, FileDrop, both, and the image kinds (whose PNG was actually saved).
# Anything else - custom/unknown formats (Kind=other) - is NOT restorable, and writing
# over it destroys data the tool cannot put back.
function Get-ClipboardStateExtras($st) {
  # StrictMode-safe: callers hand in the plan object (has Extras), the Save-ClipboardState
  # hashtable (has Extras) and unit-test hashtables that may not. A missing key must read as
  # "no extras", not as a property error that kills the caller (measured 2026-10-27 13:22:
  # the property error aborted the whole offline selftest at the clipboard family).
  if ($null -eq $st) { return @() }
  try { return @($st.Extras | Where-Object { "$_" -ne '' }) } catch { return @() }
}

function Get-ClipboardRestorableVerdict($st) {
  if ($null -eq $st) { return 'unknown - nothing was read' }
  $kind = "$($st.Kind)"
  if ($kind -eq 'other') {
    $names = Format-ClipboardFormatNames (Get-ClipboardStateExtras $st)
    if ($names -eq '') { return 'no - unknown formats; a write would need --replace-clipboard' }
    return ('no - unknown formats (' + $names + '); a write would need --replace-clipboard')
  }
  if ($kind -like '*image*' -and [bool]$st.ImageSaveError) { return 'no - an image is present but its PNG could not be saved' }
  # clip-info never attempts the PNG save (read-only), so it can only say the image is
  # restorable IF the writing command manages to carry it; the write gate refuses otherwise.
  if ($kind -like '*image*' -and ([string]$st.ImagePath -eq '')) { return 'yes - if the writing command can save the image carrier (this read did not try; the write gate refuses when that save fails)' }
  return 'yes'
}

function Assert-ClipboardReplaceable($st, [bool]$replace, [string]$cmd) {
  if ($replace) { return }
  if ($null -eq $st) { return }
  $kind = "$($st.Kind)"
  if ($kind -eq 'other') {
    $names = Format-ClipboardFormatNames (Get-ClipboardStateExtras $st)
    $detail = if ($names -ne '') { ' (' + $names + ')' } else { '' }
    throw "$cmd : the clipboard holds formats this tool cannot restore$detail; overwriting them would destroy that content. Pass --replace-clipboard to say that is intended"
  }
  if ($kind -like '*image*' -and [bool]$st.ImageSaveError) {
    throw "$cmd : the clipboard holds an image this tool could not save to a PNG, so it could not be put back; nothing was written. Pass --replace-clipboard to accept losing it"
  }
}

# Puts one file on the clipboard as FileDrop and self-verifies the drop list
# really contains it. Returns $true/$false, never throws.
function Set-ClipboardFileDrop([string]$path) {
  try {
    $sc = New-Object System.Collections.Specialized.StringCollection
    [void]$sc.Add($path)
    [System.Windows.Forms.Clipboard]::SetFileDropList($sc)
    Start-Sleep -Milliseconds 300
    if (-not [System.Windows.Forms.Clipboard]::ContainsFileDropList()) { return $false }
    $lst = [System.Windows.Forms.Clipboard]::GetFileDropList()
    return (@($lst | Where-Object { $_ -eq $path }).Count -gt 0)
  } catch { return $false }
}

# v3.0.0 (B-2): "I want the window I just looked at, not whatever this selector now
# resolves to." The tool does not cache window selections across invocations, so every
# call re-resolves <sel> from scratch - which
# is exactly how the worst incident in this repo's history happened (a paste-file with a
# perfectly good --to landed in a different chat because the app had switched sessions: the
# selector still matched, the foreground guard still passed, the CONTENT guard is what caught
# the class afterwards). A handle pin is the missing identity leg: cheap, mechanical, and it
# fires BEFORE anything is activated, so a refusal cannot itself disturb the desktop.
# Pure: accepts 0x-hex or decimal, reports WHY it refused ('invalid-format' | 'mismatch'),
# and treats an empty expectation as "no pin asked" - never as "match nothing".
function Test-HandlePin([string]$expected, [IntPtr]$actual) {
  $actHex = '0x' + ('{0:x}' -f $actual.ToInt64())
  $e = "$expected".Trim()
  if (-not $e) { return @{ Ok = $true; Expected = ''; Actual = $actHex; Reason = ''; Hint = '' } }
  $n = [Int64]0
  $parsed = $false
  $hint = ''
  # v3.0.1 (audit #24): a 20-digit hex string matched the shape and then died inside
  # [Convert]::ToInt64 with a raw OverflowException - the flag that exists to make a
  # refusal legible produced a .NET stack trace instead. Shape and range are now both
  # refusals, and the refusal says which.
  if ($e -match '^0x[0-9a-fA-F]+$') {
    try { $n = [Convert]::ToInt64($e.Substring(2), 16); $parsed = $true }
    catch { $hint = 'the hex digits after 0x do not fit a 64-bit window handle' }
  }
  elseif ($e -match '^[0-9]+$') {
    try { $n = [Int64]::Parse($e); $parsed = $true }
    catch { $hint = 'the decimal digits do not fit a 64-bit window handle' }
  }
  if (-not $parsed) {
    return @{ Ok = $false; Expected = $e; Actual = $actHex; Reason = 'invalid-format'; Hint = $hint }
  }
  $expHex = '0x' + ('{0:x}' -f $n)
  if ($n -eq $actual.ToInt64()) { return @{ Ok = $true; Expected = $expHex; Actual = $actHex; Reason = ''; Hint = '' } }
  return @{ Ok = $false; Expected = $expHex; Actual = $actHex; Reason = 'mismatch'; Hint = '' }
}

# Pure: the parenthesised "why did the pin refuse" fragment every refusal line prints.
# One producer so a hint added to the verdict reaches all three call sites at once.
function Format-HandlePinReason($pin) {
  $r = "$($pin.Reason)"
  if ("$($pin.Hint)" -ne '') { $r += ': ' + $pin.Hint }
  return $r
}

# Resolves the target and, unless $force, hard-guards that it really is the
# foreground window before the caller sends any keystrokes. If the guard fails
# it throws (ERROR + exit 1) and nothing is sent. With -Force the old behaviour
# is kept: send anyway and print the reconciliation info for manual checking.
#
# !! THIS FUNCTION RETURNS AN OBJECT, SO IT MUST NOT ALSO WRITE TO THE PIPELINE.
# The first version of the activated= verdict used Write-Output; every caller does
# `$tgt = Resolve-Target ...`, so the string was SILENTLY SWALLOWED into $tgt (the
# function then returned an array of [string, object]) and the line never reached a
# user - while member enumeration kept `$tgt.Handle`/`.Pid` working, which is why
# 337 other checks stayed green and hid it. The verdict therefore travels in
# $script:ActivationLine / $script:ActivationNotice and is printed by
# Emit-ResolveNote, which every target-resolving command already calls. A lint
# forbids Write-Output inside this body.
function Format-WindowMissMessage([string]$sel) {
  $missingPid = 0
  if ([int]::TryParse($sel, [ref]$missingPid)) {
    return "no window matching pid: $missingPid - re-run 'wins' and choose a current PID; numeric selectors match PIDs only and never fall back to title"
  }
  if ($sel -match '^hwnd:(.*)$') {
    return "no window with handle '$($Matches[1])' - that exact handle is not on this desktop any more (closed, recreated, or never existed). Re-read 'wins'; an hwnd: selector never falls back to a title match."
  }
  return "no window matching: $sel"
}

function Resolve-Target([string]$sel, [bool]$force = $false, [bool]$alwaysActivate = $false, [string]$expectHandle = '', [string]$created = '') {
  $script:ActivationLine = ''
  $script:ActivationNotice = ''
  if (-not $sel) {
    $h = [DT]::GetForegroundWindow()
    $procId = 0
    [void][DT]::GetWindowThreadProcessId($h, [ref]$procId)
    # no --to is not "no identity requirement": with --expect-handle the caller is saying
    # "act on the window I am LOOKING at", and the foreground window is what would be hit.
    $pinFg = Test-HandlePin $expectHandle $h
    if (-not $pinFg.Ok) {
      throw ("handle pin: this call may only act on $($pinFg.Expected) but the FOREGROUND window is pid=$procId hwnd=$($pinFg.Actual) '$([DT]::Text($h))' ($(Format-HandlePinReason $pinFg)) - NOTHING was sent. Re-check with 'wins' / 'focus', then pass --to <sel> --expect-handle <hwnd>.")
    }
    # CU-OPS package D: --created turns "a window called X" into "the process that owns
    # it, as observed at this time". PID reuse is what it kills: a new process with the
    # old number gets a different creation time and is refused before any activation.
    if ($created) {
      $ciFg = Test-ProcIdentity ([int]$procId) $created
      if (-not $ciFg.Ok) {
        throw ("process identity: --created '$created' does not match the FOREGROUND window's pid=$procId hwnd=$($pinFg.Actual) ($($ciFg.Why)) - NOTHING was sent and nothing was activated. Re-read the process with 'proc-info <pid>' and pass its start= value.")
      }
    }
    $script:ActivationLine = 'activated=n/a (no --to)'
    # v3.1.0 (P-02): the same pre-send popup baseline the --to path takes further down. Without
    # it Test-PostSendForeground falls back to an EMPTY baseline, so a tool palette or floating
    # panel that was ALREADY on top of the foreground window read as "appeared ON TOP after the
    # guard passed" - a false WARN plus exit 1 on a send that worked, while the identical scene
    # with --to stayed green. Two paths, one reality, two exit codes was the defect.
    # The foreground window needs no activation here (it already is foreground), so taking the
    # baseline at this point is the same measurement the --to path takes after activating.
    $fgw = [pscustomobject]@{ Pid = $procId; Handle = $h; Title = [DT]::Text($h); Activated = $false; ActivatedNote = 'n/a (no --to)' }
    $fgw | Add-Member -NotePropertyName PreSendAbove -NotePropertyValue @(Get-SamePidWindowsAbove $fgw) -Force
    return $fgw
  }
  $w = Resolve-Window $sel
  if (-not $w) { throw (Format-WindowMissMessage $sel) }
  # The pin is checked BEFORE Activate-Win on purpose: a refusal that already raised the
  # window would leave the desktop changed by the very call that says it refused.
  $pin = Test-HandlePin $expectHandle $w.Handle
  if (-not $pin.Ok) {
    throw ("handle pin: this call may only act on $($pin.Expected) but selector '$sel' resolves to pid=$($w.Pid) hwnd=$($pin.Actual) '$($w.Title)' ($(Format-HandlePinReason $pin)) - NOTHING was sent and nothing was activated. A fresh re-resolve can land on a same-named window that appeared since you looked; pass --to <sel> --expect-handle <hwnd> from the same 'wins' reading, or drop the pin to accept the new target.")  }
  # CU-OPS package D: the creation-time pin sits beside the handle pin, for the same
  # reason and in the same place - before activation. A reused PID (or a same-title
  # restart) is refused while the desktop is still untouched.
  if ($created) {
    $ci = Test-ProcIdentity ([int]$w.Pid) $created
    if (-not $ci.Ok) {
      throw ("process identity: --created '$created' does not match selector '$sel' (pid=$($w.Pid) hwnd=$($w.Handle) '$($w.Title)'): $($ci.Why) - NOTHING was sent and nothing was activated. Re-read with 'proc-info <pid>' and pass that start= value.")
    }
  }
  # v1.5.6 (D-2/A-2, J-01 option A). Activate-Win used to run BringWindowToTop +
  # SetForegroundWindow on EVERY --to, even when the window already was the foreground
  # one. Those two calls are not no-ops: they re-raise the main window ABOVE a
  # self-drawn popup that currently sits on top of it, which is exactly how "the second
  # click of a dropdown never lands" showed up twice on 2026-09-29 (Steam account menu,
  # TraeWork picker - report D-2 and supplement 2). Skipping the activation when the
  # target is already foreground removes that whole class of mis-click; the IsIconic
  # restore inside Activate-Win is a FEATURE, not a side effect, and a minimized window
  # is never the foreground one, so the skip can never lose it.
  $wasFg = ([DT]::GetForegroundWindow() -eq $w.Handle)
  if ($wasFg -and -not $alwaysActivate) {
    $ok = $true
    $note = 'no (was fg)'
  } else {
    $ok = Activate-Win $w
    $note = if ($wasFg) { 'yes (--always-activate)' } else { 'yes' }
  }
  $w | Add-Member -NotePropertyName Activated -NotePropertyValue $(if ($note -like 'yes*') { $true } else { $false }) -Force
  $w | Add-Member -NotePropertyName ActivatedNote -NotePropertyValue $note -Force
  $script:ActivationLine = "activated=$note"
  if ($w.Activated) {
    # One producer for this NOTICE, on purpose: the danger is real only on the call that
    # actually moved the foreground, and an unconditional warning would be noise that
    # everybody learns to skip. A lint pins that this string exists in exactly one place.
    $script:ActivationNotice = 'NOTICE: this call activated the window - a popup/dropdown opened by the PREVIOUS click may be closed or this click may be swallowed; pass --expect <needle> (or --expect-change) to prove the action took effect. --always-activate is the pre-v1.5.6 behaviour.'
  }
  if (-not $ok -and -not $force) {
    throw ("foreground guard: intended target pid=$($w.Pid) title='$($w.Title)' did not become foreground (actual foreground: $(Get-ForegroundInfo)); no keys sent. Re-run with --force to send anyway.")
  }
  # v1.5.3 R-06 baseline: same-pid windows already on top at the moment the guard
  # passed. Anything new on top by post-send time is what the check reports.
  $w | Add-Member -NotePropertyName PreSendAbove -NotePropertyValue @(Get-SamePidWindowsAbove $w) -Force
  return $w
}

# One gate for "this flag wants a number" (audit 2026-10-04 #17). The bare casts it
# replaces answered a non-numeric value with a raw .NET binding error that named neither
# the flag nor what to do about it, while two neighbours in the SAME parser
# (--verify-timeout, --min-line-density) did explain themselves - one flag family, two
# standards. Range checks stay where they already are; this settles only "is it a number
# at all, and which flag are we talking about". Culture is pinned to invariant so a
# decimal point means the same thing on every machine, and an int flag handed 2.5 is
# refused instead of quietly truncated by [int].
function Read-FlagNumber([string]$name, $raw, [bool]$isInt, [string]$unit) {
  $rfnTxt = "$raw"
  $rfnD = [double]0
  if (-not [double]::TryParse($rfnTxt, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$rfnD)) {
    $rfnShape = 'a number'
    if ($isInt) { $rfnShape = 'a whole number' }
    throw "$name needs $rfnShape$(if ($unit) { " $unit" }), got: $rfnTxt"
  }
  if ($isInt -and ($rfnD -ne [math]::Truncate($rfnD))) { throw "$name needs a whole number$(if ($unit) { " $unit" }), got: $rfnTxt - a fractional part would be dropped, so nothing was assumed" }
  if ($isInt) { return [int]$rfnD }
  return $rfnD
}

function Split-Target([string[]]$words, [string]$cmd = '') {
  $sel = ''
  $force = $false
  $verify = $false
  $logPayload = $false
  $guardText = ''
  $guardRegion = ''
  $scaleMode = 'auto'
  $maxTiles = 16
  $noTile = $false
  $expect = ''
  $expectGone = ''
  # v3.0.0 (B-3): any-of / all-gone needle LISTS, comma separated. They ride beside the
  # single-needle flags rather than replacing them, so every pre-v3.0.0 caller sees the same
  # values; the expect helpers merge the two shapes into one list before matching.
  $expectAny = @()
  $expectAnyGone = @()
  # v3.0.0 (B-2): window-identity pin, threaded into Resolve-Target (see Test-HandlePin).
  $expectHandle = ''
  $expectRegion = ''
  # v1.5.9 (P-1): --no-expect must stay distinguishable from "no expect given" -
  # paste/paste-file derive an autoexpect readback from the latter, and the flag is
  # the documented send-only escape. The three fields above are still cleared, so
  # every pre-v1.5.9 reader of this table sees unchanged values.
  $noExpect = $false
  $timeoutSec = 6
  $intervalMs = 300
  # v1.5.9 (P-4): sparse-read WARN threshold (lines per 100k px2, 0 = hint off)
  $minLineDensity = 1.5
  # v1.5.3 (closes the '--verify 4s not parameterised' leftover): --verify-timeout
  # drives Invoke-TypedVerify's patience. It is deliberately SEPARATE from
  # --timeout (which drives --expect), and the 4-second default is unchanged -
  # changing a default would silently alter every existing caller's behaviour.
  $verifyTimeout = 4
  $allowOutside = $false
  # v1.5.6 (D-2/A-2 + supplement 1): idempotent activation and opt-in proof-of-effect
  $alwaysActivate = $false
  $expectChange = ''
  # v1.5.1 WP-A occlusion overrides (see Split-OcclusionFlags for semantics)
  $occlude = ''
  $occlGrid = 5
  $allowOccluded = $false
  # CU-OPS package G: the explicit permission to overwrite clipboard content this tool
  # cannot restore. Absent = a clipboard holding unknown formats is refused BEFORE writing.
  $replaceClipboard = $false
  $out = New-Object System.Collections.ArrayList
  $i = 0
  while ($i -lt $words.Count) {
    $t = $words[$i]
    if ($t -eq '--force') { $force = $true }
    elseif ($t -eq '--verify') { $verify = $true }
    elseif ($t -eq '--log-payload') { $logPayload = $true }
    elseif ($t -eq '--allow-outside') { $allowOutside = $true }
    elseif ($t -eq '--no-tile') { $noTile = $true }
    elseif ($t -eq '--occlude') {
      $i++
      if ($i -ge $words.Count) { throw '--occlude needs off|warn|strict' }
      $occlude = Resolve-OccludeModeArg $words[$i]
    } elseif ($t -eq '--occlude-grid') {
      $i++
      if ($i -ge $words.Count) { throw '--occlude-grid needs a number (1..21)' }
      $occlGrid = Resolve-OcclGridArg $words[$i]
    } elseif ($t -eq '--allow-occluded') {
      $allowOccluded = $true
    } elseif ($t -eq '--replace-clipboard') {
      # CU-OPS package G: the permission belongs to the two commands that WRITE the
      # clipboard. Anywhere else it is refused by name rather than accepted and ignored -
      # a permission that does nothing is worse than no permission.
      if ($cmd -ne 'paste' -and $cmd -ne 'paste-file') {
        throw "--replace-clipboard belongs to paste and paste-file, the commands that overwrite the clipboard AND restore it; $cmd never restores, so nothing was changed"
      }
      $replaceClipboard = $true
    }
    elseif ($t -eq '--no-expect') { $noExpect = $true; $expect = ''; $expectGone = ''; $expectAny = @(); $expectAnyGone = @(); $expectRegion = '' }
    elseif ($t -eq '--expect') {
      $i++
      if ($i -ge $words.Count) { throw '--expect needs a needle' }
      $expect = $words[$i]
    } elseif ($t -eq '--expect-gone') {
      $i++
      if ($i -ge $words.Count) { throw '--expect-gone needs a needle' }
      $expectGone = $words[$i]
    } elseif ($t -eq '--expect-any' -or $t -eq '--expect-any-gone') {
      # v3.0.0 (B-3): comma-separated needle list. Empty items are dropped (`a,,b` and a
      # trailing comma are user typos, not a request to assert "empty string is on screen",
      # which would pass on every read); the flag with NOTHING left after that is refused,
      # because an expectation that can never fail is worse than no expectation.
      $i++
      if ($i -ge $words.Count) { throw "$t needs a comma-separated needle list, e.g. --expect-any TEXT_A,TEXT_B (no value given)" }
      $items = @("$($words[$i])" -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
      if (@($items).Count -eq 0) { throw "$t needs at least one non-empty needle, got: $($words[$i])" }
      if ($t -eq '--expect-any') { $expectAny += $items } else { $expectAnyGone += $items }
    } elseif ($t -eq '--expect-handle') {
      # v3.0.0 (B-2): shape-checked HERE so a typo (`--expect-handle hwnd=123`) is refused
      # with the flag's own name, not three layers down inside a comparison.
      $i++
      if ($i -ge $words.Count) { throw '--expect-handle needs a window handle (0x1f3a or decimal, from the hwnd= column of wins/info)' }
      if ("$($words[$i])" -notmatch '^(0x[0-9a-fA-F]+|[0-9]+)$') { throw "--expect-handle must be 0x<hex> or decimal, got: $($words[$i])" }
      $expectHandle = "$($words[$i])"
    } elseif ($t -eq '--expect-region') {
      $i++
      if ($i -ge $words.Count) { throw '--expect-region needs x,y,w,h' }
      $expectRegion = $words[$i]
    } elseif ($t -eq '--always-activate') {
      # v1.5.6 (J-08 condition 2): the rollback switch for idempotent activation.
      # Bringing it back means "do the old always-BringWindowToTop thing", which is
      # also the CONTROL GROUP for the live z-order test - so it is not decoration.
      $alwaysActivate = $true
    } elseif ($t -eq '--expect-change') {
      # v1.5.6 (owner supplement 1): opt-in pixel-change check for the action family.
      # The old `delivered to hwnd=...`, current `SendInput-inserted=1/1` and `clicked x,y`
      # are input/destination receipts, not evidence the interface moved (that cost the
      # owner ~15 calls on a wheel picker). Optional
      # value = screen rect, SAME convention as --guard-region; bare = the target's
      # visible rect, or the virtual screen with no --to (and the WARN says which).
      # A value is only consumed if it is four numbers: anything else stays a flag-less
      # use, so `--expect-change --to X` cannot eat the selector. But a token that LOOKS
      # like a rect and is not one must be refused, not silently dropped back into the
      # positional words (measured: `--expect-change 1,2,3` used to click with a bare
      # auto region and leave `1,2,3` as a stray argument).
      # v4.2.0 (feedback item 2): the prefilter used to require COMMAS only, so the same
      # rect passed as one quoted argument with spaces matched nothing, fell into the
      # else-branch and DEGRADED to 'auto' - measured verbatim in shots/actions.log
      # 2026-10-10 00:48 UTC, and the caller only saw "region ... from target rect".
      # Number-shaped tokens now go through ConvertTo-ExpectChangeRect (accept the four
      # numbers, refuse anything else BY NAME); a non-numeric token stays the bare flag
      # so `--expect-change --to X` still cannot eat the selector.
      $ecNext = $(if ($i + 1 -lt $words.Count) { "$($words[$i + 1])" } else { '' })
      if ($ecNext -match '^[-\.0-9][0-9,\.\s-]*$') {
        $ecNorm = ConvertTo-ExpectChangeRect $ecNext
        if ($null -eq $ecNorm) {
          throw "--expect-change needs x,y,w,h in screen pixels (four whole numbers, comma- or space-separated; x and y may be negative, w and h may not), got: $ecNext - or pass the flag with no value at all for the target/virtual screen"
        }
        $i++
        $expectChange = $ecNorm
      } else {
        $expectChange = 'auto'
      }
    } elseif ($t -eq '--timeout') {
      $i++
      if ($i -ge $words.Count) { throw '--timeout needs seconds' }
      $timeoutSec = Read-FlagNumber '--timeout' $words[$i] $false '(seconds)'
    } elseif ($t -eq '--interval') {
      $i++
      if ($i -ge $words.Count) { throw '--interval needs milliseconds' }
      $intervalMs = Read-FlagNumber '--interval' $words[$i] $true '(milliseconds)'
    } elseif ($t -eq '--min-line-density') {
      # v1.5.9 (P-4): tunes the sparse-read WARN (large region, almost no OCR lines).
      # 0 silences the hint entirely; it never changes an exit code.
      $i++
      if ($i -ge $words.Count) { throw '--min-line-density needs a number (lines per 100k px2, 0 disables)' }
      $minLineDensity = Read-FlagNumber '--min-line-density' $words[$i] $false '(lines per 100k px2, 0 disables)'
      if ($minLineDensity -lt 0) { throw "--min-line-density must be >= 0, got: $minLineDensity" }
    } elseif ($t -eq '--verify-timeout') {
      $i++
      if ($i -ge $words.Count) { throw '--verify-timeout needs seconds (e.g. --verify-timeout 8)' }
      if ("$($words[$i])" -notmatch '^[0-9]+(\.[0-9]+)?$') { throw "--verify-timeout needs a number of seconds, got: $($words[$i])" }
      $verifyTimeout = Read-FlagNumber '--verify-timeout' $words[$i] $false '(seconds)'
      if ($verifyTimeout -lt 0.5) { throw "--verify-timeout must be >= 0.5 seconds (the check polls every 400ms), got: $verifyTimeout" }
    } elseif ($t -eq '--scale') {
      $i++
      if ($i -ge $words.Count) { throw '--scale needs auto|1|2|tiled' }
      if ($words[$i] -notin @('auto', '1', '2', 'tiled')) { throw "--scale must be auto|1|2|tiled, got: $($words[$i])" }
      $scaleMode = $words[$i]
    } elseif ($t -eq '--max-tiles') {
      $i++
      if ($i -ge $words.Count) { throw '--max-tiles needs a number' }
      $maxTiles = Read-FlagNumber '--max-tiles' $words[$i] $true '(tiles per tiled OCR pass)'
    } elseif ($t -eq '--to') {
      # --to works ANYWHERE in the list, not only in front: `click x y --to sel`
      # reads naturally and v1.4.0's click-family guards depend on it (a
      # mid-args --to used to stay in the payload and silently drop the selector)
      $i++
      if ($i -ge $words.Count) { throw '--to needs a <sel> value' }
      $sel = $words[$i]
    } elseif ($t -eq '--guard-text') {
      $i++
      if ($i -ge $words.Count) { throw '--guard-text needs a needle' }
      $guardText = $words[$i]
    } elseif ($t -eq '--guard-region') {
      $i++
      if ($i -ge $words.Count) { throw '--guard-region needs x,y,w,h=needle' }
      $guardRegion = $words[$i]
    } elseif ($t -eq '--needle') {
      # v1.5.2 (audit R-08): the ONLY way to feed a literal that starts with --.
      # The bare -- terminator was implemented and then REMOVED: powershell.exe
      # swallows a lone '--' at its own parameter-binding layer (it answers with
      # its own "parameter name '--' is ambiguous" error and the tool never sees
      # the call), so no user can reach it through 'powershell -File'. Do not
      # re-add it, and do not add a synonym either: --needle is reachable from
      # -File, -Command, cmd /c and from script steps (a JSON field, no shell
      # quoting involved).
      $i++
      if ($i -ge $words.Count) { throw '--needle needs a value' }
      [void]$out.Add($words[$i])
    } elseif ($t -like '--*') {
      # unknown --xxx used to fall into the payload/search text: a mistyped
      # --expect or --guard-text then degraded into a different send
      throw (Get-UnknownFlagMessage $cmd $t)
    } else {
      [void]$out.Add($t)
    }
    $i++
  }
  $words = @($out)
  return @{ Sel = $sel; Words = $words; Force = $force; Verify = $verify; LogPayload = $logPayload; GuardText = $guardText; GuardRegion = $guardRegion; Scale = $scaleMode; MaxTiles = $maxTiles; NoTile = $noTile; Expect = $expect; ExpectGone = $expectGone; ExpectAny = $expectAny; ExpectAnyGone = $expectAnyGone; ExpectHandle = $expectHandle; ExpectRegion = $expectRegion; NoExpect = $noExpect; TimeoutSec = $timeoutSec; IntervalMs = $intervalMs; MinLineDensity = $minLineDensity; VerifyTimeout = $verifyTimeout; AllowOutside = $allowOutside; AlwaysActivate = $alwaysActivate; ExpectChange = $expectChange; Occlude = $occlude; OcclGrid = $occlGrid; AllowOccluded = $allowOccluded; ReplaceClipboard = $replaceClipboard }
}

# ---------------------------------------------------------------------------
# v1.8.0 (B): Chrome DevTools Protocol client - the route to page DOM that UIA
# cannot see (Chromium shells expose no page controls to UIA, measured
# 2026-09-30: chrome uia-tree 40 -> 1 Document, page area empty). Constraints
# that shape everything below: SINGLE FILE, ZERO third-party dependencies
# (ClientWebSocket ships in .NET 4.5+, JSON via ConvertFrom-Json), loopback
# ONLY (the tool refuses any non-127.0.0.1 debug host by construction).
# ---------------------------------------------------------------------------
$script:CdpPort = 9222

# Pure gate: the debug host is a construction constant (127.0.0.1). Anything
# else - 0.0.0.0, a LAN IP, a bare port with no host, a hostname - is refused
# BEFORE any connection attempt, so V-4 is enforced by the tool itself, not by
# where Chrome happened to bind. Accepts '127.0.0.1' / '127.0.0.1:9222' / a
# full ws or http URI; returns the normalized http base.
function Get-CdpLoopbackBase([string]$hostOrUri) {
  $h = "$hostOrUri"
  if ($h -match '^(ws|http)s?://([^/]+)') { $h = $Matches[2] }
  $h = $h.TrimEnd('/')
  if ($h -match '^\[?[0-9a-fA-F:.]+\]?:(\d+)$') { $h = $h -replace '^\[?([^:\]]+)\]?:.*$', '$1' }
  if ($h -match '^\d+$') { throw "cdp: debug host must be 127.0.0.1 - a bare port ('$h') has no host and Chrome binds loopback only" }
  if ($h -ne '127.0.0.1') { throw "cdp: refusing non-loopback debug host '$h' - this tool only talks to 127.0.0.1 (never 0.0.0.0, never a LAN address)" }
  return "http://127.0.0.1:$script:CdpPort"
}

# Pure: extract the HOST+PORT of an URL for tab logging. Everything from '?' on
# is dropped, and so is the path: measured 2026-09-30 on the other projects, a
# subscription/API token can sit in the PATH segment just as happily as in the
# query, and a log line is something the operator pastes around. (An earlier
# comment here claimed 'path kept for identification' - the code never did that,
# and host-only is the safer contract, so the comment was wrong, not the code.)
# BRANCH ORDER IS LOAD-BEARING: the internal-scheme branch must come FIRST. The
# generic branch would otherwise swallow 'chrome://settings/login' at the '://'
# and log the word 'chrome' for every browser page - and the scheme branch below
# it would then be unreachable code that a reader trusts.
function Get-CdpUrlDomain([string]$url) {
  $u = "$url"
  # file: URLs are dropped to the bare scheme on purpose: the path IS a personal path
  # (C:\Users\<name>\... or a project tree) and this string goes into actions.log and
  # onto the operator's terminal. Identification value vs identity cost - identity wins.
  if ($u -match '^file:') { return 'file' }
  if ($u -match '^(about|chrome|devtools|view-source):') { return ($u -replace '\?.*$','') }
  if ($u -match '^[a-z][a-z0-9+.-]*://([^/?#]+)') { return $Matches[1] }
  return ''
}

# Pure: normalize the target list Chrome serves at /json.
# WHY THIS EXISTS (measured 2026-09-30, real Chrome 154): PowerShell 5.1 sometimes
# hands the decoded JSON array back as ONE element that is itself an Object[]. The
# obvious `@($x | Where-Object ...)` then yields a single "tab" whose .title / .url
# are MEMBER-ENUMERATED across every real target, so chrome-tabs printed "1 page(s)"
# with a title made of several tab titles glued together - a wrong count AND wrong
# content, with no error. One flatten level was NOT enough (measured: a nested
# Object[] survives `foreach ($y in @($x))` as a SINGLE item), so this drains a
# queue and recurses into anything enumerable except strings. A Queue and not a
# Stack, because Chrome's own tab order is part of the output's meaning.
# Pinned by 'unit: cdp target list yields the same page set flat or nested'.
# Returns an array (not a hashtable): @() at the call site is correct for lists.
function Get-CdpTargetList([string]$jsonText, [string]$typeFilter) {
  if (-not $jsonText) { return @() }
  $out = New-Object System.Collections.ArrayList
  $queue = New-Object System.Collections.Queue
  foreach ($x in @($jsonText | ConvertFrom-Json)) { $queue.Enqueue($x) }
  $guard = 0
  while ($queue.Count -gt 0 -and $guard -lt 20000) {
    $guard++
    $it = $queue.Dequeue()
    if ($null -eq $it) { continue }
    if (($it -is [System.Collections.IEnumerable]) -and -not ($it -is [string])) {
      foreach ($c in $it) { $queue.Enqueue($c) }
      continue
    }
    [void]$out.Add($it)
  }
  $res = @($out.ToArray())
  if ($typeFilter) { $res = @($res | Where-Object { $_.type -eq $typeFilter }) }
  return $res
}

# Fetch + normalize in one step. The base MUST come from Get-CdpLoopbackBase so
# the loopback gate is on the real path, not a value we re-type here.
function Get-CdpTargets([string]$base, [string]$typeFilter) {
  $resp = Invoke-WebRequest -Uri "$base/json" -TimeoutSec 5 -UseBasicParsing
  return @(Get-CdpTargetList ([string]$resp.Content) $typeFilter)
}

# Pure: CSS-px rect (CDP viewbox) -> physical screen rect. dpr is MEASURED per
# call via window.devicePixelRatio (never assumed from the machine's scaling),
# origin is the client area's physical top-left. Round, do not floor: a 0.5px
# rounding drift is inside V-3's <=3px budget, a systematic floor bias is not.
function Convert-CdpRectToScreen($cssRect, [double]$dpr, [int]$clientScreenX, [int]$clientScreenY) {
  return @{
    X = [int][math]::Round($clientScreenX + $cssRect.left * $dpr)
    Y = [int][math]::Round($clientScreenY + $cssRect.top * $dpr)
    W = [int][math]::Round($cssRect.width * $dpr)
    H = [int][math]::Round($cssRect.height * $dpr)
  }
}

# One CDP Runtime.evaluate round trip over ClientWebSocket (.NET built-in).
# Returns a hashtable @{ Ok; Value; Error } - shape rule: no pipeline writes.
# The message pump is deliberately tiny: send id=1, read frames until the id=1
# response arrives or the timeout fires; CDP may interleave events which are
# skipped by id.
# $base is the gate's output (http scheme); the ws:// form is derived from it so
# there is exactly ONE place in this file where a CDP endpoint URL is built.
function Invoke-CdpEval([string]$base, [string]$pageId, [string]$expression, [int]$timeoutMs = 8000) {
  $wsUrl = ($base -replace '^http', 'ws') + "/devtools/page/$pageId"
  $ws = New-Object System.Net.WebSockets.ClientWebSocket
  # TB-2 (2026-10-23): the WHOLE round trip now shares one budget. CancellationToken.None used
  # to be what ConnectAsync and SendAsync were handed, so those two calls had no bound at all -
  # the 2026-09-30 fix below bounded only the receive wait. A peer that accepts the TCP
  # connection and then never answers the upgrade kept ConnectAsync running forever, with the
  # stopwatch and the loop condition never getting a turn: measured against a loopback fixture
  # that holds the socket open without handshaking, the old shape was still open at the 60s
  # harness ceiling. Starting the stopwatch BEFORE the connect is what turns $timeoutMs from a
  # cap on the read phase into a cap on wall time.
  $cts = [System.Threading.CancellationTokenSource]::new($timeoutMs)
  $ct = $cts.Token
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $phase = 'connect'
  $result = @{ Ok = $false; Value = $null; Error = 'not run' }
  try {
    # [void] is load-bearing, not decoration. This call shape writes a VoidTaskResult object into
    # the output stream unless it is discarded, so without the cast the function returns Object[]
    # and every caller that reads .Ok dies under this file's Set-StrictMode -Version Latest.
    # Measured 2026-10-23 against the latency fixture: 2 leaked objects per call on both 5.1.26100
    # and 7.6.7. A synthetic Task.Delay probe does NOT leak on 7.6.7, so this is a fact about this
    # call shape, not a general "PowerShell 7 is safe" claim - do not remove the cast.
    [void]$ws.ConnectAsync([Uri]$wsUrl, $ct).GetAwaiter().GetResult()
    $phase = 'send'
    $req = @{ id = 1; method = 'Runtime.evaluate'; params = @{ expression = $expression; returnByValue = $true; userGesture = $true } } | ConvertTo-Json -Compress -Depth 6
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($req)
    [void]$ws.SendAsync([System.ArraySegment[byte]]::new($bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).GetAwaiter().GetResult()
    $buf = New-Object byte[] (4194304)
    $phase = 'receive'
    while ($sw.ElapsedMilliseconds -lt $timeoutMs) {
      $acc = New-Object System.Collections.ArrayList
      $end = $false
      while (-not $end) {
        $seg = [System.ArraySegment[byte]]::new($buf)
        # BOUNDED wait on purpose. `ReceiveAsync(...).GetAwaiter().GetResult()` blocks
        # forever if the peer neither replies nor closes: measured 2026-09-30, that shape
        # hung a chrome-debug-off call for 8 minutes with the loop condition never getting
        # a turn to re-check the stopwatch. Task.Wait(remaining) keeps the timeout honest.
        $rt = $ws.ReceiveAsync($seg, $ct)
        $left = $timeoutMs - [int]$sw.ElapsedMilliseconds
        if ($left -lt 200) { $left = 200 }
        if (-not $rt.Wait($left)) { throw "cdp: the page never replied within ${timeoutMs}ms and never closed the socket - bounded wait fired instead of hanging forever" }
        $r = $rt.Result
        if ($r.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) { throw "cdp: socket closed by peer ($($r.CloseStatus))" }
        for ($k = 0; $k -lt $r.Count; $k++) { [void]$acc.Add($buf[$k]) }
        $end = $r.EndOfMessage
      }
      $msg = ([System.Text.Encoding]::UTF8.GetString(@($acc.ToArray())) | ConvertFrom-Json)
      # Every read below goes through Get-OptValue on purpose. A successful Runtime.evaluate
      # reply carries id and result and NOTHING ELSE - no error, no exceptionDetails - and
      # this file has run under Set-StrictMode -Version Latest since v4.0.1 (X-02), where a
      # bare $msg.error is a PropertyNotFoundException, not $null. Measured 2026-10-23 on all
      # three engines of this machine: the bare reads threw on every successful page reply,
      # so the whole CDP command family answered "transport or parse failure" for a page that
      # had answered correctly.
      if ((Get-OptValue $msg 'id') -ne 1) { continue }
      $cdpErr = Get-OptValue $msg 'error'
      $cdpRes = Get-OptValue $msg 'result'
      if ($null -ne $cdpErr) { $result = @{ Ok = $false; Value = $null; Error = "$((Get-OptValue $cdpErr 'message'))" } }
      elseif ($null -ne (Get-OptValue $cdpRes 'exceptionDetails')) { $result = @{ Ok = $false; Value = $null; Error = "page exception: $((Get-OptValue (Get-OptValue $cdpRes 'exceptionDetails') 'text'))" } }
      else { $result = @{ Ok = $true; Value = (Get-OptValue (Get-OptValue $cdpRes 'result') 'value'); Error = '' } }
      break
    }
    if ($sw.ElapsedMilliseconds -ge $timeoutMs -and -not $result.Ok) { $result = @{ Ok = $false; Value = $null; Error = "cdp: no response within ${timeoutMs}ms" } }
  } catch {
    # v3.0.1 (audit #24): this try had only a finally, so a non-JSON frame at the
    # ConvertFrom-Json above (or a refused connect, or the [Uri] cast) left as a raw
    # exception. Every caller of this function speaks the Ok/Error contract -
    # Invoke-CdpJson, chrome-find, chrome-a11y - and a bare throw bypasses it, which is
    # how "CDP said something we could not parse" turns into an unattributed stack trace.
    # The exception MESSAGE is deliberately not echoed: a ConvertFrom-Json failure quotes
    # the page payload, and page text must not leave this function unlabelled.
    # TB-2: a token that expired says so, and says WHICH phase it expired in. Before this,
    # cancellation was indistinguishable from a transport fault in the Error field, so an
    # operator could not tell "the page is slow" from "we never even handshook".
    if ($ct.IsCancellationRequested) {
      $result = @{ Ok = $false; Value = $null; Error = "cdp: the ${timeoutMs}ms budget expired during the $phase phase of page $pageId - bounded and returned, not hanging (detail withheld - it would quote the page payload)" }
    } else {
      $result = @{ Ok = $false; Value = $null; Error = "cdp: transport or parse failure ($($_.Exception.GetType().Name) on page $pageId; message withheld - it would quote the page payload)" }
    }
  } finally { $ws.Dispose() }
  # Disposed after the finally rather than inside it: `lint: Invoke-CdpEval answers through the
  # Ok/Error contract` asserts the literal shape of that finally, and this line runs on every
  # path the catch can leave on, so the placement costs nothing.
  $cts.Dispose()
  return $result
}

# JSON-expression helper: wraps a PS-supplied JS snippet so the page returns a
# JSON string we can ConvertFrom-Json (CDP returnByValue already gives plain
# values, but structured results come back as nested objects we re-parse).
function Invoke-CdpJson([string]$base, [string]$pageId, [string]$jsExpression, [int]$timeoutMs = 8000) {
  $wrapped = 'JSON.stringify((function(){ ' + $jsExpression + ' })())'
  $r = Invoke-CdpEval $base $pageId $wrapped $timeoutMs
  if (-not $r.Ok) { return $r }
  try { return @{ Ok = $true; Value = ($r.Value | ConvertFrom-Json); Error = '' } } catch {
    # v3.0.1 (audit #24): this counted "$($r.Value.Length)" - and when the page returned
    # nothing at all, $null.Length is not a number, so the error line printed
    # "non-JSON ( chars" with an empty field where the size belongs. The size is computed
    # first and interpolated through a subexpression either way: the v2.2.0 pin below
    # exists because a BARE $r.Value.Length inside a double-quoted string emits a type
    # name, so the shape "subexpression, never bare member access" must survive the fix.
    $cdpValLen = 0
    if ($null -ne $r.Value) { $cdpValLen = "$($r.Value)".Length }
    $cdpValNote = $(if ($null -eq $r.Value) { ' value=null' } else { '' })
    return @{ Ok = $false; Value = $null; Error = "cdp: page returned non-JSON ($($cdpValLen) chars$cdpValNote, page text not echoed)" }
  }
}

# Graceful whole-browser shutdown over the BROWSER socket (not a page socket).
# Why this is needed and not just WM_CLOSE: measured 2026-09-30 - with an
# extension that has a service worker running, WM_CLOSE removed the Chrome WINDOW
# while the chrome.exe process stayed alive headless for 30s+, still holding the
# debug port. A restart that only checks IsWindow() would then have relaunched
# INTO that zombie via the singleton and reported a restart that never happened.
# Browser.close is the graceful path Chrome itself offers; it saves the session.
function Invoke-CdpBrowserClose([string]$base) {
  $res = @{ Ok = $false; Error = 'not attempted' }
  # TB-2: same shape as Invoke-CdpEval. $ct used to be CancellationToken.None here, so a
  # browser socket that accepted the TCP connection and then stalled the upgrade hung this
  # call before the pump's patience could even start. The source and the stopwatch are
  # declared up front because the outer catch has to be able to ask whether the budget
  # expired - the None token answers 'no' when we never got as far as creating the source
  # (a refused or slow /json/version, which keeps its own -TimeoutSec 4).
  $cts = $null
  $ct = [System.Threading.CancellationToken]::None
  $budgetMs = 4000
  try {
    $v = Invoke-RestMethod -Uri "$base/json/version" -TimeoutSec 4
    # Get-OptValue, not a bare member read: under this file's Set-StrictMode -Version Latest a
    # missing webSocketDebuggerUrl is a PropertyNotFoundException, so the refusal written for
    # that case could never actually run - the exception escaped to the catch instead.
    $browserWsUrl = Get-OptValue $v 'WebSocketDebuggerUrl'
    if ([string]::IsNullOrWhiteSpace($browserWsUrl)) { return @{ Ok = $false; Error = 'json/version carried no webSocketDebuggerUrl' } }
    $ws = New-Object System.Net.WebSockets.ClientWebSocket
    $cts = [System.Threading.CancellationTokenSource]::new($budgetMs)
    $ct = $cts.Token
    $swc = [System.Diagnostics.Stopwatch]::StartNew()
    try {
      # [void] on both: see Invoke-CdpEval - this call shape leaks a VoidTaskResult into the
      # output stream without the cast, and the function then returns Object[].
      [void]$ws.ConnectAsync([Uri]$browserWsUrl, $ct).GetAwaiter().GetResult()
      $bytes = [System.Text.Encoding]::UTF8.GetBytes('{"id":1,"method":"Browser.close"}')
      [void]$ws.SendAsync([System.ArraySegment[byte]]::new($bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).GetAwaiter().GetResult()
      # Pump until the peer hangs up (Chrome closes the socket as it shuts down) or the
      # patience runs out. Disposing straight after SendAsync was measured to leave the
      # browser alive with the port still answering: a CDP command with no reply read is
      # a command with no delivery receipt.
      $buf = New-Object byte[] (65536)
      while ($swc.ElapsedMilliseconds -lt $budgetMs) {
        try {
          $seg = [System.ArraySegment[byte]]::new($buf)
          $rt2 = $ws.ReceiveAsync($seg, $ct)
          # 1200 ms is the tip's silence patience and it stays the per-turn wait: the budget is only
          # a ceiling. Letting the wait grow to the whole budget was measured (2026-10-23, latency
          # fixture, silent-after-handshake) to take this path from 1601 ms to 4402 ms - a peer that
          # says nothing is already known to say nothing, so waiting longer buys no receipt.
          $leftc = $budgetMs - [int]$swc.ElapsedMilliseconds
          if ($leftc -gt 1200) { $leftc = 1200 }
          if ($leftc -lt 200) { $leftc = 200 }
          if (-not $rt2.Wait($leftc)) { break }
          $rr = $rt2.Result
          if ($rr.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) { break }
        } catch { break }
      }
      Start-Sleep -Milliseconds 300
      $res = @{ Ok = $true; Error = '' }
    } finally {
      try { $ws.Dispose() } catch { }
    }
  } catch {
    if ($ct.IsCancellationRequested) {
      $res = @{ Ok = $false; Error = "cdp browser: the ${budgetMs}ms budget expired before Browser.close was delivered - bounded and returned, not hanging" }
    } else {
      $res = @{ Ok = $false; Error = $_.Exception.Message }
    }
  } finally {
    if ($null -ne $cts) { try { $cts.Dispose() } catch { } }
  }
  return $res
}

# Where does the page's (0,0) sit on the physical screen? Returns @{ Ok; X; Y; Pid;
# Formula; Error } - callers must not wrap it in @(). THREE routes were measured
# against a solid colour block on screen (2026-09-30, Chrome 154, 150% scaling):
#  * JS only, screenY + (outerHeight - innerHeight): 10 physical px TOO LOW. That
#    difference also contains the window's bottom border, none of which is above the
#    viewport. (X was fine - left and right borders really do halve.)
#  * Win32 client area (ClientToScreen): 131 px TOO HIGH, because Chrome is a
#    custom-drawn borderless window - its CLIENT area includes the tab strip, the
#    toolbar and the bookmark bar, which are not the page viewport.
# Pure: the JS-route viewport origin, for when the window itself could not be measured.
# Both axes are computed HERE and together, because the shipped version of this fallback
# fed window.screenY into the X coordinate (audit 2026-10-04 #4): the metrics probe never
# even carried screenX, so any call that reached this route reported Ok=true with an X
# that was a Y value scaled by the DPI. Y's shape is the pre-existing one (screenY plus
# the chrome ABOVE the viewport); X mirrors it with the side borders HALVED, since
# outerWidth-innerWidth is left+right together.
function Get-CdpViewportOriginJs([double]$dpr, [int]$screenXCss, [int]$screenYCss, [int]$innerWidthCss, [int]$innerHeightCss, [int]$outerW, [int]$outerH) {
  return @{
    X = [int][math]::Round((([double]$screenXCss + (([double]$outerW - [double]$innerWidthCss) / 2)) * $dpr))
    Y = [int][math]::Round((([double]$screenYCss + ([double]$outerH - [double]$innerHeightCss)) * $dpr))
  }
}

#  * ANCHOR ON THE BOTTOM EDGE (what this does): the viewport's bottom really does
#    coincide with the window's visible bottom, so
#        Y = visibleFrameBottom - innerHeight * dpr
#    needs no knowledge of Chrome's UI height and no border arithmetic at all.
# The visible frame comes from DWM (DWMWA_EXTENDED_FRAME_BOUNDS = 9), because
# GetWindowRect adds the invisible resize border on Win10/11.
# Falls back to the JS route when the window cannot be measured, and SAYS which one it
# used - a mapping must not silently change meaning between runs.
function Get-CdpViewportOrigin([string]$base, [double]$dpr, [int]$innerHeightCss, [int]$innerWidthCss, [int]$screenYCss, [int]$outerH, [int]$innerH2, [int]$screenXCss = 0, [int]$outerW = 0) {
  $out = @{ Ok = $false; X = 0; Y = 0; Pid = 0; Formula = ''; Error = '' }
  $jsPt = Get-CdpViewportOriginJs $dpr $screenXCss $screenYCss $innerWidthCss $innerH2 $outerW $outerH
  $jsY = [int]$jsPt.Y
  $portNum = 0
  if ($base -match ':(\d+)$') { $portNum = [int]$Matches[1] }
  $bp = 0
  if ($portNum -gt 0) {
    $lp = @(Get-NetTCPConnection -State Listen -LocalPort $portNum -ErrorAction SilentlyContinue)
    if (@($lp).Count -ge 1) { $bp = [int]$lp[0].OwningProcess }
  }
  $bw = $(if ($bp -gt 0) { Resolve-Window ([string]$bp) } else { $null })
  if ($bw) {
    $gwr = New-Object DT+RECT
    [void][DT]::GetWindowRect($bw.Handle, [ref]$gwr)
    $ext = New-Object DT+RECT
    $dwmOk = ([DT]::DwmGetWindowAttribute($bw.Handle, (Get-DwmVisibleFrameAttribute), [ref]$ext, [System.Runtime.InteropServices.Marshal]::SizeOf($ext)) -eq 0)
    if ($dwmOk) {
      $vh = [int][math]::Round([double]$innerHeightCss * $dpr)
      $vx = [int][math]::Round([double]$innerWidthCss * $dpr)
      return @{ Ok = $true; X = [int]($ext.Right - $vx); Y = [int]($ext.Bottom - $vh); Pid = $bp; Formula = 'bottom-anchor-dwm'; Error = '' }
    }
  }
  # No measurable window: the JS arithmetic route stands in for it. A resolved window's
  # own Left is still the better answer when we have one (and Resolve-Window was already
  # called above, so it is reused rather than looked up a second time).
  $jsX2 = [int]$jsPt.X
  if ($bw) { $jsX2 = [int]$bw.Left }
  $out.X = $jsX2; $out.Y = $jsY; $out.Pid = $bp; $out.Formula = 'js-outer-minus-inner'; $out.Ok = $true
  if ($bp -le 0) { $out.Ok = $false; $out.Error = "no process is listening on 127.0.0.1:$portNum - is Chrome running with the debug port, on a NON-default --user-data-dir?" }
  return $out
}

# Resolve the tab to act on: the FIRST /json entry whose type is 'page', or the
# one whose title/url contains <sel>. The base must come from the loopback gate.
# Returns @{ Page; Count } - and refuses loudly when NOTHING is a page, because a
# null Page used to surface later as a socket error against '/devtools/page/'.
function Get-CdpPageId([string]$base, [string]$sel) {
  $pages = @(Get-CdpTargets $base 'page')
  if (@($pages).Count -lt 1) { throw "chrome: no page target is open on $base/json (0 page(s)) - is Chrome still running with the debug port, and is it a NON-DEFAULT --user-data-dir? Chrome 136+ refuses the debug port on the default profile." }
  if (-not $sel) { return @{ Page = $pages[0]; Count = $pages.Count } }
  $pick = @($pages | Where-Object { (Test-NameSubstring $_.title $sel) -or (Test-NameSubstring $_.url $sel) })
  if (@($pick).Count -eq 0) { throw "chrome: no open tab matches '$sel' ($($pages.Count) page(s) open)" }
  return @{ Page = $pick[0]; Count = $pages.Count }
}

# ---------- Chrome's own exit path (owner ruling 2026-09-30 22:0x, option B) ----------
# Why this exists: WM_CLOSE is measured to leave chrome.exe alive headless (the
# service-worker extension case), and the debug port that route would need is refused
# outright on a default profile. So the graceful close goes through the browser's OWN
# menu. Floor from the ruling, encoded below: NO blind accelerators (this box runs a
# zh-CN Chrome whose menu access keys are unverified), the exit item is located by its
# LITERAL UIA Name, and if it cannot be read the tool refuses and leaves Chrome where
# it is - it does not fall back to guessed coordinates.
# The decisions are pure functions over row objects so they are provable OFFLINE with
# synthetic rows; a judgement reachable only through --live effectively has no assertion
# behind it (this repo's standing rule).
# Pure: pick THE app-menu button out of walked UIA rows.
# Rows need Name / ControlType / X / Y / W / H. Verdict rules, each with a reason that
# is reported rather than papered over:
#  * Name must EQUAL 'Chrome' - not contain it. Measured 2026-09-30 on the owner's
#    zh-CN Chrome 154: Button name='Chrome' id='view_1007' at 3173,224,52x52 (the
#    three-dots button is named 'Chrome' in the English AND the Chinese build). As a
#    SUBSTRING 'Chrome' also matches every tab-strip item titled
#    "'<page> - Google Chrome'", which is how a menu click could land on a tab.
#  * zero candidates and two-or-more candidates are BOTH refusals; picking "the biggest"
#    or "the first" would be a coin toss wearing the clothes of a decision.
# Returns @{ Ok; Index; Reason; Candidates } - Index is the row index, -1 when refused.
function Select-ChromeMenuButton($rows) {
  $rs = @($rows)
  $hits = New-Object System.Collections.ArrayList
  for ($i = 0; $i -lt $rs.Count; $i++) {
    $row = $rs[$i]
    if ("$($row.ControlType)" -ne 'Button') { continue }
    if ("$($row.Name)".Trim() -ne 'Chrome') { continue }
    if ([int]$row.W -le 0 -or [int]$row.H -le 0) { continue }
    [void]$hits.Add($i)
  }
  if (@($hits).Count -eq 1) {
    return @{ Ok = $true; Index = [int]$hits[0]; Reason = 'single exact-name button'; Candidates = 1 }
  }
  if (@($hits).Count -eq 0) {
    return @{ Ok = $false; Index = -1; Reason = "no Button named exactly 'Chrome' among $($rs.Count) row(s)"; Candidates = 0 }
  }
  return @{ Ok = $false; Index = -1; Reason = "$(@($hits).Count) buttons named exactly 'Chrome' - refusing to guess which one is the app menu"; Candidates = @($hits).Count }
}

# Pure: choose the exit item out of the menu item Names that were actually read.
# Needles are tried MOST specific first, and a needle only wins when it matches exactly
# one row. Deliberately NO bare "quit/exit" stem in the local language: a Chinese Chrome
# menu also carries the sign-out item ("log out of the Google account"), and a matcher
# that cannot tell "quit the browser" from "sign me out" would perform a DIFFERENT
# destructive action on a single unlucky substring. Ambiguity must become a refusal.
  # So: the full localised quit label, then the label as actually read on this build
  # (Chrome 154 zh-CN app menu carries "quit(X)" - label plus access key, so a bare
  # "quit" stem stays forbidden: it is also a substring of the sign-out label, while
  # the paren makes that collision impossible), then the English full label, then plain
  # 'Exit' (which the English app menu uses); two items matching the same needle is a
  # refusal, never a coin toss. An EMPTY read is its own refusal reason - it must not
  # read like "the matcher found nothing to match" (that is the shape of a silently
  # broken scan).
function Find-ChromeExitItem($names) {
  $ns = @($names | ForEach-Object { "$_" })
  if (@($ns).Count -eq 0) { return @{ Ok = $false; Name = ''; Reason = 'no menu item names were read at all - the menu did not open, or it is not exposed to UIA'; Needles = '' } }
  # CJK needles are assembled from code points because this file must stay pure ASCII
  # beyond its BOM: a BOM-less .ps1 is parsed as GBK on PS 5.1 and the literals rot -
  # and the rot is SELF-CONSISTENT, an equality test against the same literal still
  # passes. Only printing code points proves the encoding.
  $zhQuitBrowser = [string]([char]0x9000) + [char]0x51FA + [char]0x6D4F + [char]0x89C8 + [char]0x5668   # "quit browser" (5 glyphs)
  $zhQuitAccel = [string]([char]0x9000) + [char]0x51FA + '(X)'   # "quit(X)" - label as read on this build; "(" cannot occur in the sign-out label
  foreach ($needle in @($zhQuitBrowser, $zhQuitAccel, 'Exit Google Chrome', 'Exit')) {
    $m = @($ns | Where-Object { (Test-NameSubstring $_ $needle) })
    if (@($m).Count -eq 1) { return @{ Ok = $true; Name = "$($m[0])"; Reason = "matched 1 of $(@($ns).Count) item(s) on the exit needle"; Needles = $needle } }
    if (@($m).Count -gt 1) {
      return @{ Ok = $false; Name = ''; Reason = "$(@($m).Count) menu items contain the same exit needle - refusing to guess which one quits the browser: [$(@($m) -join ' ;; ')]"; Needles = $needle }
    }
  }
  return @{ Ok = $false; Name = ''; Reason = "no menu item matched any exit needle (read $(@($ns).Count) item(s)); the refusal path is explicit on purpose"; Needles = 'zh-quit-browser / zh-quit-with-access-key / Exit Google Chrome / Exit' }
}

# Can this UIA rectangle be turned into numbers? UIA answers "I have no rectangle" with
# System.Windows.Rect.Empty, whose members are NOT zero - measured on this machine:
# X=Infinity Y=Infinity Width=-Infinity Height=-Infinity, IsEmpty=True. So the FIRST
# [int] cast of any member throws a RuntimeException, and a comparison like
# "$br.Y -ge $pageTop" is quietly TRUE. Four consumers did exactly that (audit 2026-10-04
# #3/#6/#7 plus find's own uia road): the chrome exit-menu lost its backout (the menu
# stayed on screen), a11y-probe inflated PageHits (collapsed reported as exposed), and
# uia-click / find threw a type error at the caller instead of refusing.
# Pure: no UIA object needed, so this is testable without a desktop.
function Test-UiaRectUsable($r) {
  if ($null -eq $r) { return $false }
  try {
    if ($r.IsEmpty) { return $false }
    foreach ($rv in @([double]$r.X, [double]$r.Y, [double]$r.Width, [double]$r.Height)) {
      if ([double]::IsNaN($rv) -or [double]::IsInfinity($rv)) { return $false }
    }
    return $true
  } catch { return $false }
}

# Pure: does this element sit in the page area? The emptiness question must be asked
# BEFORE the Y comparison, which is the whole bug: Rect.Empty.Y is +Infinity, so an
# element with no rectangle passes any lower-bound test ever written.
function Test-UiaInPageArea($r, [double]$pageTop) {
  if (-not (Test-UiaRectUsable $r)) { return $false }
  return ([double]$r.Y -ge $pageTop)
}

# Top-level UIA elements of a process. Chrome draws its app menu in a SEPARATE
# top-level window, so a walk rooted at the browser frame cannot see the items the
# click just opened - the pid is the honest scope for "what appeared".
function Uia-PidRoots([int]$procId) {
  Add-Type -AssemblyName UIAutomationClient
  Add-Type -AssemblyName UIAutomationTypes
  $list = New-Object System.Collections.ArrayList
  $cond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ProcessIdProperty, $procId)
  $tops = [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
    [System.Windows.Automation.TreeScope]::Children, $cond)
  foreach ($t in $tops) { [void]$list.Add($t) }
  return @{ Roots = $list; Count = $list.Count }
}

# The app-menu button of a Chrome window, as UIA sees it: element + rectangle, decided
# by Select-ChromeMenuButton so the exact-name/ambiguity rules are the ones under test.
function Get-ChromeMenuButton($win) {
  $r = @{ Ok = $false; Element = $null; X = 0; Y = 0; W = 0; H = 0; Candidates = 0; Error = '' }
  $rr = Uia-Roots $win
  if (@($rr.Roots).Count -lt 1) { $r.Error = "no UIA root for pid $($win.Pid)"; return $r }
  $walked = New-Object System.Collections.ArrayList
  $rows = @()
  foreach ($root in @($rr.Roots)) {
    foreach ($el in @(Uia-WalkAll @($root) (Get-UiaBigDepth))) {
      $ct = ''
      try { $ct = $el.Current.ControlType.ProgrammaticName -replace 'ControlType\.', '' } catch { continue }
      $nm = ''
      try { $nm = "$($el.Current.Name)" } catch { }
      $br = $null
      try { $br = $el.Current.BoundingRectangle } catch { continue }
      # Rect.Empty carries X/Y = +Infinity: an [int] cast overflows. The same guard as
      # Uia-Line applies; an empty rect becomes zeros so Select-ChromeMenuButton's own
      # W/H<=0 filter (not a crash) is what drops the row from candidacy.
      $rx = 0; $ry = 0; $rw = 0; $rh = 0
      if ($null -ne $br -and -not $br.IsEmpty) {
        $rx = [int]$br.X; $ry = [int]$br.Y; $rw = [int]$br.Width; $rh = [int]$br.Height
      }
      $rows += [pscustomobject]@{ ControlType = $ct; Name = $nm; X = $rx; Y = $ry; W = $rw; H = $rh }
      [void]$walked.Add($el)
    }
  }
  $pick = Select-ChromeMenuButton $rows
  if (-not $pick.Ok) { $r.Error = $pick.Reason; $r.Candidates = $pick.Candidates; return $r }
  $el2 = $walked[$pick.Index]
  $row = $rows[$pick.Index]
  $r.Ok = $true; $r.Element = $el2; $r.X = $row.X; $r.Y = $row.Y; $r.W = $row.W; $r.H = $row.H; $r.Candidates = $pick.Candidates
  return $r
}

# MenuItem names currently visible under a process. A walk of the browser frame alone
# cannot see an open menu (it lives in its own top-level window), so this takes pid roots.
function Get-UiaMenuItems([int]$procId) {
  $pr = Uia-PidRoots $procId
  $names = @()
  foreach ($root in @($pr.Roots)) {
    foreach ($el in @(Uia-WalkAll @($root) (Get-UiaBigDepth))) {
      $ct = ''
      try { $ct = $el.Current.ControlType.ProgrammaticName -replace 'ControlType\.', '' } catch { continue }
      if ($ct -ne 'MenuItem') { continue }
      $nm = ''
      try { $nm = "$($el.Current.Name)".Trim() } catch { }
      if ($nm.Length -eq 0) { continue }
      $names += $nm
    }
  }
  return @{ Names = @($names); Count = @($names).Count }
}

# Escape, then PROVE the menu went away by comparing against the count measured before
# it was opened - an absolute "0 MenuItems" test would call a browser that legitimately
# carries menu items in its frame permanently "not dismissed".
function Dismiss-UiaMenu([int]$procId, [int]$baseline) {
  try { [System.Windows.Forms.SendKeys]::SendWait('{ESC}') } catch { }
  Start-Sleep -Milliseconds 300
  $after = (Get-UiaMenuItems $procId).Count
  return @{ Dismissed = ($after -le $baseline); Left = $after; Baseline = $baseline }
}

# v3.0.0 (B-5, borrowed from the built-in browser tool's handle_dialog): the cross-project
# operating rule says "system dialogs are closed with CANCEL, never with OK" - and until now
# the tool had NO way to express that. Cancelling meant reading the dialog with wins, finding
# a text row with menu-pick and clicking it, which is three chances to hit the wrong button
# on the most destructive dialog class on the machine (a Save/Replace/Format prompt). These
# three functions make it one call, and the CANDIDATE SET IS CLOSED on purpose.
#
# The CJK word for CANCEL, and the English one, ONLY. Deliberately NOT the word for OK /
# Yes / Retry (the whole point is that this command can never confirm anything), and NOT
# "close" either: on several Win11 dialogs Close is the accepting action, and a command that
# is safe only on MOST dialogs is not safe. Escape stays as the fallback and is labelled.
# The CJK stem is assembled from code points (the file must stay pure ASCII). TWO traps, both
# found by the unit checks below rather than by reading:
#   1) [char]+[char] is INTEGER addition - cast each half to [string] first.
#   2) in PowerShell the comma binds TIGHTER than +, so `@(A + B, 'cancel')` is not a
#      two-element array - it is A + (B,'cancel'), which stringifies to ONE value (the CJK
#      stem, a space, then the word cancel) and quietly makes the set one stem long with the
#      English one unreachable. Every element of an array literal that is itself an
#      expression needs its own parens.
function Get-DialogCancelStems { return @( ([string][char]0x53D6 + [string][char]0x6D88), 'cancel' ) }

# Pure: matches a control name against the closed stem set, tolerating the accelerator
# suffix Windows puts on dialog buttons ("Cancel", the CN stem followed by "(&C)", or the
# bare stem with stray spaces around it).
function Test-DialogCancelName([string]$name) {
  $n = "$name".Trim().ToLowerInvariant()
  if (-not $n) { return $false }
  foreach ($stem in @(Get-DialogCancelStems)) {
    $s = "$stem".ToLowerInvariant()
    if ($n -eq $s) { return $true }
    # "cancel(c)" / "<CN stem>(&c)" - the stem must be everything BEFORE the first bracket
    if ($n.StartsWith($s + '(') -or $n.StartsWith($s + ' (') -or $n.StartsWith($s + '&')) { return $true }
  }
  return $false
}

# Pure: is this window a dialog/menu shape we are willing to press buttons in?
# Owner-present covers modal children (the file picker belongs to its app); '#32*' covers the
# native dialog and menu classes. Anything else is an ordinary app window and this command
# must not be hunting for a button in it - that is the "click whatever contains the text"
# behaviour menu-pick already refuses by design.
function Test-DialogWindow($w) {
  if ($null -eq $w) { return $false }
  $cls = "$($w.Class)"
  if ($cls.StartsWith('#32')) { return $true }
  try { if ([int64]$w.Owner -ne 0) { return $true } } catch { }
  return $false
}

# Pure: given the cancel-shaped controls found in the dialog, decide what to press.
# ONE match -> press it. ZERO -> caller falls back to Escape. TWO OR MORE -> refuse, because
# "the first cancel-looking button in z-order" is a guess, and on a dialog the wrong guess is
# the accepting button. Extracted as a pure function on purpose: the ambiguous case needs two
# real buttons inside a real dialog, and without this seam no offline check could ever catch a
# regression here (a mutation that removed the refusal stayed green until this existed).
function Resolve-DialogCancelPick($hits) {
  $n = @($hits).Count
  if ($n -eq 0) { return @{ Action = 'escape'; Pick = $null; List = '' } }
  if ($n -eq 1) { return @{ Action = 'invoke'; Pick = @($hits)[0]; List = '' } }
  $lst = (@($hits | ForEach-Object { "'" + $_.Name + "'" }) -join ' ')
  return @{ Action = 'refuse'; Pick = $null; List = $lst }
}

# How long a dialog-cancel verdict waits for the window to actually disappear. One owner:
# both routes (invoke and Escape) used to carry their own copy of the 1500ms polling loop,
# byte for byte, which is how a patience change applied to one and not the other would have
# looked like a flaky command rather than a bug (audit 2026-10-04 #16).
function Get-DialogCancelPatienceMs { return 1500 }

# Pure-in-CASE, live-in-FALSE: poll IsWindow until the handle is gone or the patience runs
# out, and report BOTH the verdict and the time spent (the echo line prints the second).
function Wait-WindowGone($handle, [int]$patienceMs, [int]$stepMs) {
  $waited = 0
  while ($waited -lt $patienceMs) {
    if (-not [DT]::IsWindow($handle)) { return @{ Gone = $true; WaitedMs = $waited } }
    Start-Sleep -Milliseconds $stepMs
    $waited += $stepMs
  }
  return @{ Gone = (-not [DT]::IsWindow($handle)); WaitedMs = $waited }
}

function Invoke-DialogCancel($w, [bool]$allowWindow) {
  if (-not (Test-DialogWindow $w) -and -not $allowWindow) {
    $ownTxt = '-'
    try { if ([int64]$w.Owner -ne 0) { $ownTxt = "$($w.Owner)" } } catch { }
    throw ("dialog-cancel: pid=$($w.Pid) class='$($w.Class)' owner=$ownTxt is not a dialog shape (class does not start with #32 and the window has no owner) - refusing to hunt for a button in an ordinary app window. Inspect it with uia-tree, then pass --allow-window if you are sure.")
  }
  $rr = Uia-Roots $w
  if (@($rr.Roots).Count -lt 1) { throw "dialog-cancel: no UIA root for pid $($w.Pid) - nothing pressed" }
  $hits = New-Object System.Collections.ArrayList
  foreach ($root in @($rr.Roots)) {
    foreach ($el in @(Uia-WalkAll @($root) (Get-UiaBigDepth))) {
      $ct = ''
      try { $ct = $el.Current.ControlType.ProgrammaticName -replace 'ControlType\.', '' } catch { continue }
      if ($ct -ne 'Button') { continue }
      $nm = ''
      try { $nm = "$($el.Current.Name)".Trim() } catch { }
      if (Test-DialogCancelName $nm) { [void]$hits.Add(@{ Name = $nm; El = $el }) }
    }
  }
  $pick = Resolve-DialogCancelPick $hits
  if ($pick.Action -eq 'invoke') {
    $echo = Invoke-UiaClickable $pick.Pick.El
    # Receipt is not proof: pressing a button that closes the dialog is asynchronous, so the
    # verdict is the handle being gone (same patience win-close's auto-release uses), and
    # the echo says how long it waited either way.
    $goneW = Wait-WindowGone $w.Handle (Get-DialogCancelPatienceMs) 150
    return @{ Via = 'uia-invoke'; Confirmed = $goneW.Gone; Pressed = $pick.Pick.Name; Note = $echo; WaitedMs = $goneW.WaitedMs }
  }
  if ($pick.Action -eq 'escape') {
    $d = Dismiss-UiaMenu $w.Pid 0
    $goneW = Wait-WindowGone $w.Handle (Get-DialogCancelPatienceMs) 150
    if ($goneW.Gone) { return @{ Via = 'escape'; Confirmed = $true; Pressed = ''; Note = 'no cancel button in the tree; Escape sent and the window is gone'; WaitedMs = $goneW.WaitedMs } }
    return @{ Via = 'escape'; Confirmed = $false; Pressed = ''; Note = "no cancel button in the tree and Escape did NOT close it (menu-count left=$($d.Left))"; WaitedMs = $goneW.WaitedMs }
  }
  throw "dialog-cancel: $(@($hits).Count) cancel-shaped buttons in this dialog ($($pick.List)) - refusing to guess which one dismisses it. Nothing was pressed."
}

# The tab manifest is the before/after reconciliation data for the graceful restart
# (owner ruling 2, 2026-09-30 22:0x): count + title + TabItem rectangle per tab. It is
# written to a UTF-8 BOM file, NOT to the console - the console is GBK on this machine
# and would corrupt the very data the comparison depends on.
function Get-ChromeTabRows($win) {
  $rows = New-Object System.Collections.ArrayList
  $rr = Uia-Roots $win
  if (@($rr.Roots).Count -lt 1) { return @{ Rows = @(); Count = 0; Error = "no UIA root for pid $($win.Pid)" } }
  foreach ($root in @($rr.Roots)) {
    foreach ($el in @(Uia-WalkAll @($root) (Get-UiaBigDepth))) {
      $ct = ''
      try { $ct = $el.Current.ControlType.ProgrammaticName -replace 'ControlType\.', '' } catch { continue }
      if ($ct -ne 'TabItem') { continue }
      $nm = ''
      try { $nm = "$($el.Current.Name)" } catch { }
      $br = $null
      try { $br = $el.Current.BoundingRectangle } catch { continue }
      # same IsEmpty guard as Get-ChromeMenuButton: Rect.Empty carries Infinity
      $x = 0; $y = 0; $rw = 0; $rh = 0
      if ($null -ne $br -and -not $br.IsEmpty) { $x = [int]$br.X; $y = [int]$br.Y; $rw = [int]$br.Width; $rh = [int]$br.Height }
      [void]$rows.Add([pscustomobject]@{ Name = $nm; X = $x; Y = $y; W = $rw; H = $rh })
    }
  }
  # visual order = rectangle X ascending: UIA sibling order was never proven to match
  # what the user sees on this build, so the manifest never trusts it
  $sorted = @($rows | Sort-Object -Property X)
  return @{ Rows = $sorted; Count = $sorted.Count; Error = '' }
}

function Format-TabManifestLine([int]$idx, $row) {
  return ([string]$idx) + '|' + "$($row.Name)" + '|' + "$($row.X),$($row.Y),$($row.W)x$($row.H)"
}

# Right-anchored parse: idx = before the first '|', rect = after the LAST '|', name =
# everything between. A title containing '|' round-trips losslessly - no escape table
# to drift out of sync with the formatter.
function Parse-TabManifestLine([string]$line) {
  $i1 = "$line".IndexOf('|')
  if ($i1 -lt 0) { return @{ Idx = "$line"; Name = ''; Rect = '' } }
  $i2 = "$line".LastIndexOf('|')
  if ($i2 -eq $i1) { return @{ Idx = "$line".Substring(0, $i1); Name = ''; Rect = '' } }
  return @{ Idx = "$line".Substring(0, $i1); Name = "$line".Substring($i1 + 1, $i2 - $i1 - 1); Rect = "$line".Substring($i2 + 1) }
}

# Pure: reconcile the before/after manifests. The gate is count + title + order (owner
# ruling 2 wording); rectangles ride along in the files for the operator to eyeball -
# gating on pixels would fail a relaunch that restored at a slightly different size.
function Compare-TabManifest($beforeLines, $afterLines) {
  $b = @($beforeLines); $a = @($afterLines)
  if ($b.Count -ne $a.Count) {
    $bNames = @($b | ForEach-Object { (Parse-TabManifestLine "$_").Name })
    $aNames = @($a | ForEach-Object { (Parse-TabManifestLine "$_").Name })
    $missing = @($bNames | Where-Object { $aNames -notcontains $_ })
    $added = @($aNames | Where-Object { $bNames -notcontains $_ })
    return @{ Ok = $false; Reason = "count drift: before=$($b.Count) after=$($a.Count)" + $(if (@($missing).Count -gt 0) { "; missing: [$(@($missing) -join ' ;; ')]" } else { '' }) + $(if (@($added).Count -gt 0) { "; added: [$(@($added) -join ' ;; ')]" } else { '' }) }
  }
  for ($i = 0; $i -lt $b.Count; $i++) {
    $pb = Parse-TabManifestLine "$($b[$i])"
    $pa = Parse-TabManifestLine "$($a[$i])"
    if ("$($pb.Name)" -cne "$($pa.Name)") {
      return @{ Ok = $false; Reason = "order/content drift at position $($i + 1): before='$($pb.Name)' after='$($pa.Name)'" }
    }
  }
  return @{ Ok = $true; Reason = 'Same'; Count = $b.Count }
}

function Write-TabManifest($win, [string]$tag) {
  $r = @{ Path = ''; Lines = @(); Count = 0; Error = '' }
  $tr = Get-ChromeTabRows $win
  if ($tr.Error) { $r.Error = $tr.Error; return $r }
  if ($tr.Count -eq 0) {
    # the cold-start first contact can read an empty tree (A-6b) - re-measure once
    # before believing "zero tabs"
    Start-Sleep -Milliseconds 800
    $tr = Get-ChromeTabRows $win
    if ($tr.Error) { $r.Error = $tr.Error; return $r }
  }
  $lines = New-Object System.Collections.ArrayList
  for ($i = 0; $i -lt $tr.Rows.Count; $i++) {
    [void]$lines.Add((Format-TabManifestLine ($i + 1) $tr.Rows[$i]))
  }
  $dir = Join-Path $PSScriptRoot 'shots'
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $path = Join-Path $dir ('tab-manifest-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $tag + '.txt')
  # v3.0.1 (audit #24): the writer used to be closed by a straight $sw.Close() after the
  # loop, so any throw in the middle left the file open AND half-written - and this is
  # the evidence file a tab-restoration verdict is read back from. Disposed in a finally,
  # and the caller still gets its return object (no pipeline writes in here).
  $swMan = $null
  try {
    $swMan = New-Object System.IO.StreamWriter($path, $false, (New-Object System.Text.UTF8Encoding($true)))
    foreach ($l in @($lines)) { $swMan.WriteLine($l) }
  } finally {
    if ($null -ne $swMan) { $swMan.Dispose() }
  }
  # not matched by shots-cleanup (it only handles *.png/*.jpg/*.map.txt) - tiny text
  # evidence, kept
  $r.Path = $path; $r.Lines = @($lines); $r.Count = @($lines).Count
  return $r
}

# Open Chrome's app menu, read every MenuItem Name, and (unless told to commit) close
# the menu again WITHOUT clicking anything. Returns the item list plus how the menu was
# opened and whether the dismissal was verified - an operator deciding "is the exit
# route drivable on this build" reads exactly those three fields.
function Read-ChromeMenuItems($win, [int]$waitMs, [switch]$KeepOpen) {
  $r = @{ Opened = $false; Items = @(); Count = 0; Via = ''; Dismissed = $false; Baseline = 0; Error = '' }
  $baseline = (Get-UiaMenuItems $win.Pid).Count
  $r.Baseline = $baseline
  $mb = Get-ChromeMenuButton $win
  if (-not $mb.Ok) { $r.Error = "menu button: $($mb.Error)"; return $r }
  try {
    $mb.Element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
    $r.Via = 'InvokePattern'
  } catch {
    # clicking the element's OWN rectangle (read from that same element) - this is not
    # a guessed coordinate, and the distinction is what the ruling's floor is about.
    Move-Click ($mb.X + [int]($mb.W / 2)) ($mb.Y + [int]($mb.H / 2)) 'left'
    $r.Via = 'click-own-rect'
  }
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  while ($sw.ElapsedMilliseconds -lt $waitMs) {
    Start-Sleep -Milliseconds 250
    $seen = Get-UiaMenuItems $win.Pid
    if ($seen.Count -gt $baseline) {
      $r.Opened = $true; $r.Items = @($seen.Names); $r.Count = $seen.Count
      break
    }
  }
  if (-not $r.Opened) { $r.Error = "menu opened via $($r.Via) but no new MenuItem appeared under pid $($win.Pid) within ${waitMs}ms (baseline=$baseline) - the menu is not exposed to UIA on this build"; return $r }
  if ($KeepOpen) { return $r }
  $d = Dismiss-UiaMenu $win.Pid $baseline
  $r.Dismissed = $d.Dismissed
  if (-not $d.Dismissed) { $r.Error = "menu still shows $($d.Left) MenuItem(s) after Escape (baseline $($d.Baseline)) - close it yourself before trusting any later measurement" }
  return $r
}

# Drive Chrome's own exit. -Commit is the ONLY mode that leaves the browser closed;
# without it this reads the menu and backs out, which is how the route gets evidence
# on a browser that is still in use.
function Invoke-ChromeExitMenu($win, [switch]$Commit) {
  $r = @{ Ok = $false; ExitName = ''; Items = 0; Via = ''; Committed = $false; Error = '' }
  $rd = Read-ChromeMenuItems $win 4000 -KeepOpen:$Commit
  $r.Via = $rd.Via; $r.Items = $rd.Count
  $backout = { if ($Commit) { [void](Dismiss-UiaMenu $win.Pid $rd.Baseline) } }
  if (-not $rd.Opened) { $r.Error = $rd.Error; return $r }
  $pick = Find-ChromeExitItem $rd.Items
  if (-not $pick.Ok) { &$backout; $r.Error = "exit item: $($pick.Reason) (read: $(@($rd.Items) -join ' ;; '))"; return $r }
  $r.ExitName = $pick.Name
  if (-not $Commit) {
    $r.Ok = $true
    $r.Error = "dry run: found '$($pick.Name)' and did NOT click it (menu dismissed=$($rd.Dismissed))"
    return $r
  }
  # click the item by its own rectangle: Chrome's menu items expose ExpandCollapse/
  # Invoke inconsistently across versions, and the rectangle came from the element
  # itself - it is not a guessed coordinate.
  $hit = $null
  $pr = Uia-PidRoots $win.Pid
  foreach ($root in @($pr.Roots)) {
    foreach ($el in @(Uia-WalkAll @($root) (Get-UiaBigDepth))) {
      $nm = ''
      try { $nm = "$($el.Current.Name)".Trim() } catch { }
      if ($nm -eq $pick.Name) { $hit = $el; break }
    }
    if ($null -ne $hit) { break }
  }
  if ($null -eq $hit) { &$backout; $r.Error = "item '$($pick.Name)' vanished between reading and clicking - refusing to click anything else"; return $r }
  $invoked = $false
  try { $hit.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke(); $invoked = $true } catch { }
  if (-not $invoked) {
    $br = $null
    try { $br = $hit.Current.BoundingRectangle } catch { }
    if (-not (Test-UiaRectUsable $br) -or [int]$br.Width -le 0) { &$backout; $r.Error = "item '$($pick.Name)' has no clickable rectangle and no InvokePattern"; return $r }
    Move-Click ([int]($br.X + $br.Width / 2)) ([int]($br.Y + $br.Height / 2)) 'left'
    $r.Via = "$($r.Via) then click-item-own-rect"
  } else { $r.Via = "$($r.Via) then InvokePattern on item" }
  $r.Ok = $true; $r.Committed = $true
  return $r
}

# The ONE Chrome restart path. Used by chrome-a11y and chrome-debug-off, so the
# two never drift apart on the part that actually bites: how a graceful close is
# confirmed. Returns @{ Closed; CloseVia; CloseNote; ExitName; Survivors; Window; WaitedMs;
# ChromeExe; Error } - no pipeline writes inside (a returned object plus a stray
# Write-Output is how a judgement line used to vanish from the echo).
# Measured facts this encodes (2026-09-30, Chrome 154, this machine):
#  * WM_CLOSE is NOT sufficient: with a service-worker extension active the window
#    disappeared while chrome.exe lived headless for 30 s+, still holding 9222.
#    So the gate here is ZERO chrome PROCESSES, not IsWindow().
#  * Relaunching while a survivor lives is not a restart - the singleton forwards
#    the new command line to the old process, so the new flags are ignored. Hence:
#    refuse to relaunch and say so.
#  * Switches are joined into one argument string and handed to Process.Start with
#    UseShellExecute=false. Start-Process -ArgumentList does NOT quote a switch
#    value containing a space: that truncated "--user-data-dir=...\Chrome\User
#    Data" to ...\Chrome\User and silently created a stray profile directory.
function Restart-ChromeWithFlags([string[]]$flags, [string]$base, [int]$timeoutMs) {
  $r = @{ Closed = $false; CloseVia = 'none'; CloseNote = ''; ExitName = ''; Survivors = 0; Window = $null; WaitedMs = 0; ChromeExe = ''; NewPid = 0; Scope = ''; AnchorPid = 0; AnchoredBy = ''; Scoped = 0; LaunchArgs = ''; Error = '' }
  $w = Resolve-Window 'Chrome'
  # WHICH chrome.exe counts as "the browser being restarted": the MAIN processes
  # (no ' --type=' child flag) that share the target's --user-data-dir.
  # ANCHORING IS THE PART THAT MATTERS. Anchoring on 'the biggest window whose title
  # contains Chrome' was measured to be wrong with two instances open: chrome-debug-off
  # closed the OWNER's browser (2607x1570, larger) instead of the scratch one it was
  # asked to shut down. When a debug base is given, the browser being talked to is
  # whatever process LISTENS on that port - that is the only unambiguous answer.
  # WITHOUT a base (the chrome-a11y path) there is no port to ask, so the largest
  # Chrome window remains the anchor and the operator is told which pid was chosen.
  $defaultUdd = ''
  try { $defaultUdd = (Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data') } catch { }
  $cimMain = @(Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -notmatch ' --type=' })
  if (@($cimMain).Count -lt 1) { $r.Error = 'no chrome.exe browser process is running - there is no Chrome to restart'; return $r }
  $anchorPid = 0
  if ($base -and ($base -match ':(\d+)$')) {
    $portNum = [int]$Matches[1]
    $lp = @(Get-NetTCPConnection -State Listen -LocalPort $portNum -ErrorAction SilentlyContinue)
    if (@($lp).Count -ge 1) { $anchorPid = [int]$lp[0].OwningProcess; $r.AnchoredBy = "listen-port-$portNum" }
  }
  if ($anchorPid -le 0 -and $w) { $anchorPid = [int]$w.Pid; $r.AnchoredBy = 'largest-chrome-window' }
  $anchor = $cimMain[0]
  foreach ($c in $cimMain) { if ([int]$c.ProcessId -eq $anchorPid) { $anchor = $c } }
  $r.AnchorPid = [int]$anchor.ProcessId
  $anchorUdd = ''
  if (("$($anchor.CommandLine)") -match '--user-data-dir=("[^"]*"|[^\s]*)') { $anchorUdd = ($Matches[1] -replace '"', '') }
  if (-not $anchorUdd) { $anchorUdd = $defaultUdd }
  $r.Scope = $anchorUdd
  $beforePids = @()
  foreach ($c in $cimMain) {
    $cu = ''
    if (("$($c.CommandLine)") -match '--user-data-dir=("[^"]*"|[^\s]*)') { $cu = ($Matches[1] -replace '"', '') }
    if (-not $cu) { $cu = $defaultUdd }
    if ($cu -eq $anchorUdd) { $beforePids += [int]$c.ProcessId }
  }
  $r.Scoped = @($beforePids).Count
  # the window we post WM_CLOSE to must belong to the ANCHOR, not to whichever Chrome
  # happens to be largest on screen
  $wTarget = Resolve-Window ([string]$r.AnchorPid)
  if (-not $wTarget) { $wTarget = $w }
  $exe = ''
  try { $exe = [string]$anchor.ExecutablePath } catch { $exe = '' }
  if (-not $exe) { $exe = 'C:\Program Files\Google\Chrome\Application\chrome.exe' }
  $r.ChromeExe = $exe
  if ($base) {
    $bc = Invoke-CdpBrowserClose $base
    if ($bc.Ok) { $r.CloseVia = 'browser-close' }
  }
  if ($r.CloseVia -ne 'browser-close') {
    # Owner ruling 2026-09-30 22:0x, option B: drive Chrome's OWN exit menu before
    # WM_CLOSE. WM_CLOSE is the one that was measured leaving chrome.exe alive headless
    # (service-worker extension) while still holding the debug port, so a relaunch after
    # it is a singleton hand-off, not a restart. The menu route refuses rather than
    # guessing: no blind accelerators, and the exit item is matched by literal Name.
    if ($wTarget) {
      $ex = Invoke-ChromeExitMenu $wTarget -Commit
      if ($ex.Ok) {
        $r.CloseVia = 'uia-exit-menu'; $r.ExitName = $ex.ExitName
        $r.CloseNote = "exit item '$($ex.ExitName)' opened via $($ex.Via)"
      } else {
        $r.CloseNote = "exit menu refused: $($ex.Error)"
      }
    } else {
      $r.CloseNote = 'no window for the anchored pid, so the exit menu was not attemptable'
    }
  }
  if ($r.CloseVia -ne 'browser-close' -and $r.CloseVia -ne 'uia-exit-menu') {
    if ($null -eq $wTarget) { $r.Error = "no window for the anchored chrome pid $($r.AnchorPid) and no debug endpoint answered - refusing to kill chrome.exe by force"; return $r }
    [void][DT]::PostMessage($wTarget.Handle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $r.CloseVia = 'wm-close'
  }
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  while ($sw.ElapsedMilliseconds -lt $timeoutMs) {
    $alive = @($beforePids | Where-Object { $null -ne (Get-Process -Id $_ -ErrorAction SilentlyContinue) })
    if (@($alive).Count -eq 0) { break }
    Start-Sleep -Milliseconds 400
  }
  $r.WaitedMs = [int]$sw.ElapsedMilliseconds
  $r.Survivors = @($beforePids | Where-Object { $null -ne (Get-Process -Id $_ -ErrorAction SilentlyContinue) }).Count
  if ($r.Survivors -gt 0 -and $r.CloseVia -eq 'browser-close') {
    # Browser.close was accepted but the browser is still here: escalate to the OTHER
    # graceful path (WM_CLOSE on the scoped window) before declaring failure. Force
    # killing is not ours to do - it loses the session Chrome is about to save.
    $wEsc = $wTarget
    if (-not $wEsc) { foreach ($ep in $beforePids) { $wEsc = Resolve-Window ([string]$ep); if ($wEsc) { break } } }
    if ($wEsc) {
      [void][DT]::PostMessage($wEsc.Handle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
      $r.CloseVia = 'browser-close then wm-close'
      $sw3 = [System.Diagnostics.Stopwatch]::StartNew()
      while ($sw3.ElapsedMilliseconds -lt $timeoutMs) {
        if (@($beforePids | Where-Object { $null -ne (Get-Process -Id $_ -ErrorAction SilentlyContinue) }).Count -eq 0) { break }
        Start-Sleep -Milliseconds 400
      }
      $r.WaitedMs = $r.WaitedMs + [int]$sw3.ElapsedMilliseconds
      $r.Survivors = @($beforePids | Where-Object { $null -ne (Get-Process -Id $_ -ErrorAction SilentlyContinue) }).Count
    }
  }
  if ($r.Survivors -gt 0) {
    $r.Error = "chrome.exe still running ($($r.Survivors) of the $($beforePids.Count) browser process(es) this call scoped to) ${timeoutMs}ms after $($r.CloseVia) - a relaunch now would be handed to that survivor and the new flags ignored. Close the remaining Chrome manually (or turn off 'Continue running background apps when Google Chrome is closed')."
    return $r
  }
  $r.Closed = $true
  Start-Sleep -Milliseconds 1200
  # Relaunch the browser that WAS closed, not whichever profile Chrome picks by default.
  # Measured 2026-09-30: chrome-debug-off shut the scratch-profile browser and then
  # relaunched with only --restore-last-session, so what came back was a DEFAULT-profile
  # Chrome - a different browser, with the operator's other windows missing. The scope is
  # only echoed by callers, so the helper itself has to carry it across the restart.
  $launchFlags = @($flags)
  if ($anchorUdd -and $defaultUdd -and ($anchorUdd -ne $defaultUdd)) {
    $launchFlags = @('--user-data-dir="' + $anchorUdd + '"') + @($flags)
  }
  $si = New-Object System.Diagnostics.ProcessStartInfo
  $si.FileName = $exe
  $si.Arguments = (@($launchFlags) -join ' ')
  $r.LaunchArgs = $si.Arguments
  $si.UseShellExecute = $false
  $newProc = [System.Diagnostics.Process]::Start($si)
  if ($null -ne $newProc) { $r.NewPid = [int]$newProc.Id }
  # Prefer the window of the process WE started; a title match could otherwise land on
  # a different Chrome instance's window and report the restart as verified when the
  # instance we launched is not the one being looked at.
  $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
  while ($sw2.ElapsedMilliseconds -lt $timeoutMs) {
    Start-Sleep -Milliseconds 500
    if ($r.NewPid -gt 0) {
      $wp = Resolve-Window ([string]$r.NewPid)
      if ($wp) { $r.Window = $wp; break }
    }
    $w2 = Resolve-Window 'Chrome'
    if ($w2) { $r.Window = $w2; break }
  }
  if ($null -eq $r.Window) { $r.Error = "Chrome relaunched but no Chrome window appeared within ${timeoutMs}ms" }
  return $r
}

# ---------------------------------------------------------------------------
# CU-OPS-COMPLETE-20261026-01 (package B): modifier-owned mouse gestures.
#
# The rules this block exists to enforce, all of them from SendInput's documented
# behaviour (SendInput returns how many events it INSERTED and does NOT reset a key
# state that was already down):
#   * a modifier this call did not press is never released - if the caller (or the
#     user) already holds Ctrl, the gesture refuses instead of toggling their key;
#   * press -> act -> release happens inside ONE call, and the release runs in a
#     finally block, so a refusal or a failed event still cleans up this call's keys;
#   * every event carries its inserted count; 0 is a failure, never a success;
#   * a button that this family does not offer is refused BEFORE any input.
# finally is not a guarantee against a hard process kill: a killed process leaves its
# keys down like any other writer, which is why the same-call bound is the default and
# there is no "leave Ctrl down for later" mode.
$script:MouseButtonNames = @('left', 'right', 'middle', 'back', 'forward')
$script:ModifierVk = @{ 'ctrl' = 0x11; 'shift' = 0x10; 'alt' = 0x12 }
$script:LastMouseReceipt = ''

# Pure: 'ctrl+shift' / 'ctrl,shift' -> ordered, de-duplicated list of known names.
# An empty/absent spec yields an empty list (no modifiers), which is the unchanged
# pre-CU-OPS path. Unknown names and the Windows key are refused here, before input.
function Resolve-MouseModifiers([string]$spec) {
  $list = @()
  foreach ($raw in @("$spec" -split '[+,]')) {
    $n = ("$raw").Trim().ToLowerInvariant()
    if (-not $n) { continue }
    if ($n -eq 'control') { $n = 'ctrl' }
    if ($n -eq 'windows' -or $n -eq 'win') {
      throw "mouse gestures do not drive the Windows key: OS-reserved combinations cannot be verified from a fixture and this tool does not pretend to synthesise them; accepted modifiers are ctrl, shift, alt"
    }
    if (-not $script:ModifierVk.ContainsKey($n)) { throw "unknown mouse modifier '$raw' - accepted: ctrl, shift, alt (combine with + or ,)" }
    if ($list -notcontains $n) { $list += $n }
  }
  # Plain output on purpose: returning the array with a leading comma would emit an
  # EMPTY array as ONE item, so an empty spec would arrive as a one-element list whose
  # element is '' and the gesture would then look up a modifier that does not exist.
  return $list
}

# Pure: button name -> the two input flags plus the XBUTTON id SendInput expects.
function Get-MouseButtonSpec([string]$name) {
  switch (("$name").Trim().ToLowerInvariant()) {
    'left'    { return @{ Name = 'left'; Down = 0x0002; Up = 0x0004; Data = 0 } }
    'right'   { return @{ Name = 'right'; Down = 0x0008; Up = 0x0010; Data = 0 } }
    'middle'  { return @{ Name = 'middle'; Down = 0x0020; Up = 0x0040; Data = 0 } }
    'back'    { return @{ Name = 'back'; Down = 0x0080; Up = 0x0100; Data = 1 } }
    'x1'      { return @{ Name = 'back'; Down = 0x0080; Up = 0x0100; Data = 1 } }
    'forward' { return @{ Name = 'forward'; Down = 0x0080; Up = 0x0100; Data = 2 } }
    'x2'      { return @{ Name = 'forward'; Down = 0x0080; Up = 0x0100; Data = 2 } }
  }
  throw "unknown mouse button '$name' - accepted: left, right, middle, back/x1, forward/x2"
}

# Measured state of a button, so a press/release claim can be checked instead of
# trusted. GetAsyncKeyState covers every button; the left one keeps the older
# Control.MouseButtons reading for the existing press-pair contract.
function Get-MouseButtonDown([string]$name) {
  if (("$name").Trim().ToLowerInvariant() -eq 'left') { return (Get-LeftButtonDown) }
  $vk = switch (("$name").Trim().ToLowerInvariant()) {
    'right'   { 0x02 }
    'middle'  { 0x04 }
    'back'    { 0x05 }
    'x1'      { 0x05 }
    'forward' { 0x06 }
    'x2'      { 0x06 }
    default   { 0 }
  }
  if ($vk -eq 0) { throw "unknown mouse button '$name'" }
  return (([DT]::IsVkDown([int]$vk)) -ne 0)
}

# One button DOWN or UP with its inserted count checked. $data is the XBUTTON id.
function Invoke-MouseButtonEvent([string]$button, [bool]$down) {
  $mb = Get-MouseButtonSpec $button
  $flag = if ($down) { [uint32]$mb.Down } else { [uint32]$mb.Up }
  $n = [uint32][DT]::SendMouseButtonInput($flag, [uint32]$mb.Data)
  if ($n -ne 1) {
    $win32 = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    throw "mouse button $($mb.Name) $(if ($down) { 'DOWN' } else { 'UP' }): SendInput inserted $n of 1 (win32 error $win32) - the button state is not what the caller asked for"
  }
  return $n
}

# Press the requested modifiers, run the action, and release ONLY the keys this call
# pressed. Refuses when one of them is already down: that state belongs to someone
# else, and neither pressing nor releasing it would be this tool's to do.
function Invoke-ModifierGesture([string[]]$mods, [scriptblock]$action) {
  $rc = @{ Mods = @($mods); Pressed = @(); Released = @(); Inserted = 0; Error = ''; ReleaseError = '' }
  if (@($mods).Count -eq 0) { & $action; return $rc }
  foreach ($m in @($mods)) {
    $vk = [int]$script:ModifierVk[$m]
    if (([DT]::IsVkDown($vk)) -ne 0) {
      throw "modifier '$m' is already held down (not by this call); this tool will not press or release a key it does not own - let go of it first, then retry"
    }
  }
  try {
    foreach ($m in @($mods)) {
      $vk = [int]$script:ModifierVk[$m]
      $n = [uint32][DT]::SendKeyInput($vk, $false, $false)
      if ($n -ne 1) { throw "modifier '$m' DOWN: SendInput inserted $n of 1; no gesture was performed" }
      $rc.Inserted = [int]$rc.Inserted + 1
      $rc.Pressed = @($rc.Pressed) + $m
      Start-Sleep -Milliseconds 30
    }
  } catch {
    $rc.Error = $_.Exception.Message
    $rf = @()
    foreach ($m in @($rc.Pressed)) {
      try {
        $n = [uint32][DT]::SendKeyInput([int]$script:ModifierVk[$m], $true, $false)
        if ($n -eq 1) { $rc.Released = @($rc.Released) + $m } else { $rf += "$m(inserted $n/1)" }
      } catch { $rf += "$m($($_.Exception.Message))" }
    }
    if (@($rf).Count) { throw ($rc.Error + ' | modifier UP failed for: ' + ($rf -join ', ') + ' - those keys may still be down; run key-state / key-release') }
    throw $rc.Error
  }
  $actionErr = $null
  try {
    & $action
  } catch {
    $actionErr = $_
  } finally {
    # CU-OPS-ADJ-03: every modifier UP is verified. The old code ignored SendKeyInput's
    # return and swallowed exceptions, so a failed UP was still receipted as released.
    $rf = @()
    foreach ($m in @($rc.Pressed)) {
      try {
        $n = [uint32][DT]::SendKeyInput([int]$script:ModifierVk[$m], $true, $false)
        if ($n -eq 1) { $rc.Released = @($rc.Released) + $m } else { $rf += "$m(inserted $n/1)" }
      } catch { $rf += "$m($($_.Exception.Message))" }
    }
    Start-Sleep -Milliseconds 40
    if (@($rf).Count) { $rc.ReleaseError = 'modifier UP failed for: ' + ($rf -join ', ') + ' - those keys may still be down; run key-state / key-release' }
  }
  if ($null -ne $actionErr) {
    $msg = $actionErr.Exception.Message
    if ($rc.ReleaseError) { throw ($msg + ' | ' + $rc.ReleaseError) }
    throw $msg
  }
  if ($rc.ReleaseError) { throw $rc.ReleaseError }
  return $rc
}

function Format-ModifierReceipt($rc) {
  if ($null -eq $rc -or @($rc.Mods).Count -eq 0) { return '' }
  return (" mods=" + (@($rc.Mods) -join '+') + " mods-pressed-inserted=" + $rc.Inserted + "/" + @($rc.Mods).Count + " mods-released=" + (@($rc.Released) -join '+'))
}

# The one producer of a button click. Left/right without modifiers keep the exact
# pre-CU-OPS event shape and pace; every other case goes through SendInput with a
# counted receipt. $mods is a '+'-separated spec ('' = none).
function Move-Click([int]$x, [int]$y, [string]$button, [string]$mods = '') {
  $modList = @(Resolve-MouseModifiers $mods)
  $mb = Get-MouseButtonSpec $button
  $script:LastMouseReceipt = ''
  $act = {
    [void][DT]::SetCursorPos($x, $y)
    Start-Sleep -Milliseconds 150
    if ($modList.Count -eq 0 -and $mb.Name -eq 'left') {
      [DT]::mouse_event($MOUSE_LDOWN, 0, 0, 0, [IntPtr]::Zero)
      Start-Sleep -Milliseconds 60
      [DT]::mouse_event($MOUSE_LUP, 0, 0, 0, [IntPtr]::Zero)
    } elseif ($modList.Count -eq 0 -and $mb.Name -eq 'right') {
      [DT]::mouse_event($MOUSE_RDOWN, 0, 0, 0, [IntPtr]::Zero)
      Start-Sleep -Milliseconds 60
      [DT]::mouse_event($MOUSE_RUP, 0, 0, 0, [IntPtr]::Zero)
    } else {
      # CU-OPS-ADJ-06: a new button (middle/side) is DOWN only for the span of this
      # block, and the UP runs in a finally - a failure between the two must not leave
      # the button held down with a receipt that claims a completed click.
      [void](Invoke-MouseButtonEvent $mb.Name $true)
      try {
        Start-Sleep -Milliseconds 60
      } finally {
        [void](Invoke-MouseButtonEvent $mb.Name $false)
      }
    }
    Start-Sleep -Milliseconds 200
  }
  if ($modList.Count -gt 0) {
    $rc = Invoke-ModifierGesture $modList $act
    $script:LastMouseReceipt = (Format-ModifierReceipt $rc)
  } else {
    & $act
    $script:LastMouseReceipt = ''
  }
}

# ---------------------------------------------------------------------------
# v2.0.1 (P-3): the drag MID-STATE - press-down / drag-to / press-up.
#
# Why: a surface that takes its verdict when you LET GO (slider puzzles above all)
# is only safe to drive if the button can stay down while the caller LOOKS. `drag`
# presses, travels and releases inside one call, so the caller has to gamble blind -
# --expect-change can prove "something moved", never "the position is right".
#
# Why it needs watchdogs: each invocation is a fresh process, but a held button is MACHINE-WIDE
# state. A process that exits mid-press leaves the owner's mouse in a drag. Three
# layers, each covering the previous layer's blind spot:
#   1. --max-hold  - a timer in the process that pressed, so the hold cannot outlive
#                    its own promise (a CLI press-down therefore STAYS ALIVE until
#                    the release; an echo promising auto-release while the process
#                    has already exited would be a lie);
#   2. the entry watchdog - every later invocation releases a button it finds down
#                    (covers the crash / kill that beat the timer);
#   3. the echo    - press-down prints "button is DOWN, will auto-release after Nms".
# The DECISION is one pure function (measured state in, action out), so the state
# machine is a unit test and not a live race.
# ---------------------------------------------------------------------------
# Per-process press bookkeeping. Deliberately NOT persisted anywhere: the button
# itself is the only truth about the mid-state, these fields only carry the log
# pairing (PressId) and whether this process may block waiting for it (PressTopLevel,
# cleared by a script step). The hold deadline lives in the native timer (DT.HoldReleased).
$script:PressSeq = 0
$script:PressId = ''
$script:PressTopLevel = $true

function Get-LeftButtonDown {
  # NOT [System.Windows.Forms.MouseButtons]::Buttons - that form silently returns
  # NOTHING (MouseButtons is an enum type; the state lives on Control), and a
  # measurement that reads empty makes every gate built on it read "not pressed".
  # Measured 2026-10-01 with the button physically down:
  #   [Windows.Forms.MouseButtons]::Buttons -> ''   [Windows.Forms.Control]::MouseButtons -> Left
  return ((([System.Windows.Forms.Control]::MouseButtons -band [System.Windows.Forms.MouseButtons]::Left)) -ne 0)
}

# Pure gate. $op is the press operation; for 'watchdog' the COMMAND NAME decides,
# because two commands act ON the press state and must not have it destroyed first.
function Get-PressGate([string]$op, [string]$cmd, [bool]$down) {
  $g = @{ Release = $false; Refuse = $false; Reason = ''; Warn = '' }
  if ($op -eq 'watchdog') {
    if ($cmd -eq 'press-up' -or $cmd -eq 'drag-to') { return $g }
    if ($down) { $g.Release = $true; $g.Warn = 'released a button left down by a previous run' }
    return $g
  }
  if ($op -eq 'press-down') {
    if ($down) { $g.Refuse = $true; $g.Reason = 'the left button is already down - press-down/press-up stay a 1:1 pair, release it first' }
    return $g
  }
  if ($op -eq 'press-up') {
    if ($down) { $g.Release = $true }
    else { $g.Refuse = $true; $g.Reason = 'the left button is not down - nothing to release (press-down first, or --max-hold already expired, or the entry watchdog released a stray press)' }
    return $g
  }
  if ($op -eq 'drag-to') {
    if (-not $down) { $g.Refuse = $true; $g.Reason = 'needs an existing press state (drag-to travels while HELD; press-down first, or use the one-call drag <x1> <y1> <x2> <y2>)' }
    return $g
  }
  $g.Refuse = $true; $g.Reason = "unknown press op: $op"
  return $g
}

# One producer for the two mouse events so the DOWN/UP pairing has one owner.
function Invoke-LeftPress([bool]$down) {
  if ($down) { [DT]::mouse_event($MOUSE_LDOWN, 0, 0, 0, [IntPtr]::Zero) }
  else { [DT]::mouse_event($MOUSE_LUP, 0, 0, 0, [IntPtr]::Zero) }
  Start-Sleep -Milliseconds 60
}

# The ONLY producer of the pairing line's text (v2.2.0 hardening of the P3-6 contract).
# Precedence is deliberate: an id the caller HANDS over beats whatever this process happens
# to remember, because the party that saw the release is usually NOT the party that pressed.
# And a release that cannot be attributed still writes a line - the old `if ($script:PressId)`
# skipped the write entirely in a fresh process, which left the DOWN dangling with no trace
# at all, so P3-6 could only say "unpaired" and point at nothing.
function Format-PressReleaseLine($explicitId, $processId, $cause) {
  $use = "$explicitId"
  $src = 'caller'
  if (-not $use) { $use = "$processId"; $src = 'process' }
  if (-not $use) { $src = 'none' }
  if ($src -eq 'none') {
    return ('button=UP id= cause=' + $cause + ' id-source=none (this process never held the press id - the DOWN line it belongs to stays open ON PURPOSE so the pairing contract names the gap instead of losing it)')
  }
  return ("button=UP id=$use cause=$cause id-source=$src")
}

# Single producer for the release echo and for the DOWN/UP pairing line. The line says WHERE
# the id came from, so a release attributed to the process memory is not silently relabelled
# as one the caller handed over.
function Release-Press([string]$id, [string]$cause, $logArgs, [string]$CmdName) {
  Stop-PressHoldTimer
  $rpResolved = "$id"
  if (-not $rpResolved) { $rpResolved = "$script:PressId" }
  Invoke-LeftPress $false
  Log-Action $logArgs (Format-PressReleaseLine $id "$script:PressId" $cause) $CmdName
  $script:PressId = ''
  return "button is UP (id=$rpResolved cause=$cause)"
}

function Stop-PressHoldTimer { [void][DT]::CancelLeftUpHold() }

function Test-PressHoldFired { return (([int][DT]::HoldReleased) -eq 1) }

# Watchdog 1: hand the deadline to the NATIVE timer. See the note on DT.ArmLeftUpHold -
# a PowerShell scriptblock as a Timer callback kills the process, and a dead process is
# precisely the thing that must not happen while the button is down.
function Start-PressHoldTimer([int]$ms) { [void][DT]::ArmLeftUpHold($ms) }

# The native release runs outside PowerShell, so the UP line is written by whoever
# NOTICES it. Without this the log would keep an unpaired DOWN for a release that really
# happened, and P3-6's pairing contract would accuse the wrong thing.
# v2.2.0 hardening: the id is a PARAMETER. The caller that pressed passes the id it issued;
# a caller that merely noticed the release in another process passes nothing and the line
# says so - it never drops the write, and it never rebuilds an id by guessing.
function Close-PressHold($logArgs, [string]$id, [string]$CmdName) {
  Stop-PressHoldTimer
  Log-Action $logArgs (Format-PressReleaseLine $id "$script:PressId" 'max-hold') $CmdName
  $script:PressId = ''
}

# The CLI press-down keeps its own process alive so its promise is kept. Returns why the
# hold ended: 'max-hold' (the deadline), 'external' (something else let go - e.g. a
# press-up from another process), or 'deadline' (the timer never fired).
function Wait-PressRelease([int]$ms) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  while ($sw.ElapsedMilliseconds -lt ($ms + 3000)) {
    if (Test-PressHoldFired) { return 'max-hold' }
    if (-not (Get-LeftButtonDown)) {
      # Re-check the deadline flag after a short grace: the native callback releases and
      # then flags, so "the button went up" alone cannot tell max-hold from an external
      # press-up - and a wrong cause in the audit line is still a wrong audit.
      Start-Sleep -Milliseconds 120
      if (Test-PressHoldFired) { return 'max-hold' }
      return 'external'
    }
    Start-Sleep -Milliseconds 50
  }
  return 'deadline'
}

# Watchdog 2, at the entry of every invocation. Deliberately NOT inside
# Invoke-DesktopCommand: a per-command watchdog would release the button between the
# steps of the very script that pressed it (press-down -> look -> drag-to -> press-up
# is the whole point), and it is process entry - not command entry - that a crash can
# skip. RETURNS the line rather than printing it: a caller that wraps the call in
# [void] (as this one must, to keep the verdict out of the output stream) would
# otherwise swallow its own warning - measured 2026-10-01, the release happened and was
# logged while the WARNING never reached stdout.
function Invoke-PressWatchdog([string]$cmdName) {
  $g = Get-PressGate 'watchdog' $cmdName (Get-LeftButtonDown)
  if (-not $g.Release) { return '' }
  Invoke-LeftPress $false
  Log-Action @() (Format-PressReleaseLine '' '' 'entry-watchdog') $cmdName
  return "WARNING: $($g.Warn) - the left button is up again before this command ran"
}

# v4.2.0 (external feedback item 2, 2026-10-10): THE one rule for what counts as an
# --expect-change rectangle, read by BOTH the flag parser (Split-Target) and the region
# reader (Get-ExpectChangeRegion), so a value the parser admits can never be re-refused
# downstream and a value handed over from a script step goes through the same rule.
# Four whole numbers, comma- OR space-separated: a rect really does arrive as ONE quoted
# argument with spaces - shots/actions.log 2026-10-10 00:48 UTC carries
# `--expect-change '1600 1050 700 200'` verbatim, and the old comma-only prefilter
# matched nothing, silently set ExpectChange='auto', and the verdict then measured the
# WHOLE target window (959,428 1924x1234) while the caller believed it had pinned
# 1600,1050,700,200. Returns the canonical x,y,w,h string, or $null when the value is not
# a rect - the CALLER decides between refusing and degrading, never this helper.
function ConvertTo-ExpectChangeRect([string]$raw) {
  if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
  $parts = @("$raw" -split '[,\s]+' | Where-Object { "$_" -ne '' })
  if (@($parts).Count -ne 4) { return $null }
  foreach ($pp in @($parts)) { if ("$pp" -notmatch '^-?[0-9]+$') { return $null } }
  if ([int]$parts[2] -le 0 -or [int]$parts[3] -le 0) { return $null }
  return (@($parts | ForEach-Object { [int]$_ }) -join ',')
}

# v1.5.6 (owner supplement 1): opt-in pixel-change check for the action family. The
# receipts these commands print (`SendInput-inserted=...`, `delivered to hwnd=...`,
# `clicked x,y`) report input insertion or an observed destination, not that the interface
# MOVED - the owner read a wheel echo as "it scrolled" while the cursor sat on a closed
# picker and burned ~15 calls on it. This is
# deliberately NOT automatic: "nothing changed" does not equal "it did not work" (the
# effect can be in another region, or the action may already have been satisfied), so an
# automatic version would manufacture new false signals - which is why option D in the
# task order was rejected. Opt-in, default off, and the WARN names the rect it measured.
function Get-ExpectChangeRegion($p, $tgt) {
  if ($p.ExpectChange -and $p.ExpectChange -ne 'auto') {
    # v4.2.0 (feedback item 2): normalise through the ONE rule, and make the Source carry
    # the rect THIS call will really measure - the echo is the only place a caller can see
    # that its own rect (not the whole window) was taken.
    $ecNorm = ConvertTo-ExpectChangeRect "$($p.ExpectChange)"
    if ($null -eq $ecNorm) { throw "--expect-change needs x,y,w,h in screen pixels (same convention as --guard-region), got: $($p.ExpectChange)" }
    $parts = @($ecNorm -split ',')
    return @{ X = [int]$parts[0]; Y = [int]$parts[1]; W = [int]$parts[2]; H = [int]$parts[3]; Source = ('--expect-change rect ' + $ecNorm) }
  }
  if ($null -ne $tgt -and $p.Sel) {
    $r = Get-TargetRect $tgt
    return @{ X = $r.X; Y = $r.Y; W = $r.W; H = $r.H; Source = "target '$($tgt.Title)' rect" }
  }
  $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
  return @{ X = $vs.X; Y = $vs.Y; W = $vs.Width; H = $vs.Height; Source = 'virtual screen (no --to)' }
}

# Returns $null when the flag is absent, otherwise the region PLUS the pre-action hash.
# The baseline has to be taken before the action, so callers grab it first and hand it
# to the check afterwards - a "did it change?" helper that sampled only afterwards would
# always say yes (the cursor moved) and be worthless.
function Get-ExpectChangeBaseline($p, $tgt) {
  if (-not $p.ExpectChange) { return $null }
  $r = Get-ExpectChangeRegion $p $tgt
  $r.Hash = Get-RegionHash $r.X $r.Y $r.W $r.H
  return $r
}

# The decision and its wording, split out from the capture so BOTH branches can be
# asserted without depending on whether the screen happens to change between two grabs.
# Measured reason: while the comparison lived inline, a mutation that made the WARN
# branch unreachable stayed green offline - only --live could see it, which is the
# "live-only assertion is no assertion" trap this project keeps hitting.
function Format-ExpectChangeVerdict($base, [string]$now, [string]$what) {
  $rs = "region ($($base.X),$($base.Y)) $($base.W)x$($base.H) from $($base.Source)"
  if ($now -eq $base.Hash) {
    return "WARN: --expect-change: after $what the $($rs) is PIXEL-IDENTICAL (md5 $now) - input was delivered, nothing moved here. NOT proof of failure: the effect may be outside this rect or the action may already have been satisfied. Widen the rect, or assert content with --expect <needle>."
  }
  return "expect-change: after $what the $($rs) changed (md5 $($base.Hash) -> $now)"
}

function Invoke-ExpectChangeCheck($p, $base, [string]$what) {
  if (-not $p.ExpectChange -or $null -eq $base) { return }
  $now = Get-RegionHash $base.X $base.Y $base.W $base.H
  Write-Output (Format-ExpectChangeVerdict $base $now $what)
}

# (Escape-SendKeys was removed in v1.4.1: type/type-in went through it until
# v1.3.0 switched them to SendInput Unicode, and no production path referenced
# it afterwards - audit 2026-09-29 #10, dead-code rule.)

# UIA roots for the SELECTED window. Primary path: AutomationElement.FromHandle
# on the resolved hwnd, so uia-* acts on exactly the window <sel> picked (a
# process can own several top level windows, e.g. main window + modal dialog,
# and the old pid-based FindFirst grabbed whichever came first). Fallback when
# FromHandle fails: every top level desktop child belonging to the pid, all of
# them included in the search.
function Uia-Roots($win) {
  Add-Type -AssemblyName UIAutomationClient
  Add-Type -AssemblyName UIAutomationTypes
  $roots = New-Object System.Collections.ArrayList
  $via = 'handle'
  $el = $null
  try { $el = [System.Windows.Automation.AutomationElement]::FromHandle($win.Handle) } catch { }
  if ($null -ne $el) {
    [void]$roots.Add($el)
  } else {
    $via = 'pid-enum'
    $cond = New-Object System.Windows.Automation.PropertyCondition(
      [System.Windows.Automation.AutomationElement]::ProcessIdProperty, $win.Pid)
    $tops = [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
      [System.Windows.Automation.TreeScope]::Children, $cond)
    foreach ($t in $tops) { [void]$roots.Add($t) }
  }
  return @{ Roots = $roots; Via = $via }
}

# Breadth-first walk over one or more roots.
# Breadth-first walk of every descendant of the given roots.
# $maxDepth (0 = unlimited, the historical behaviour) exists because a11y-probe
# advertises a depth argument: a knob that changes nothing is a fake flag, and the
# repo has been bitten repeatedly by green checks over inert parameters. The
# 6000-node safety cap is unchanged.
function Uia-WalkAll($roots, [int]$maxDepth = 0) {
  $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
  $out = New-Object System.Collections.ArrayList
  $queue = New-Object System.Collections.Queue
  foreach ($r in @($roots)) { $queue.Enqueue(@($r, 0)) }
  $n = 0
  while ($queue.Count -gt 0 -and $n -lt 6000) {
    $n++
    $pair = $queue.Dequeue()
    $el = $pair[0]
    $d = [int]$pair[1]
    [void]$out.Add($el)
    if ($maxDepth -gt 0 -and $d -ge $maxDepth) { continue }
    try {
      $child = $walker.GetFirstChild($el)
      while ($null -ne $child) { $queue.Enqueue(@($child, ($d + 1))); $child = $walker.GetNextSibling($child) }
    } catch { }
  }
  return $out
}

# The ONE page-area verdict for Chromium/Electron shells (A-0/A-6): a11y-probe prints
# it, chrome-a11y uses it to self-verify a relaunch. Two copies of this judgement is
# how a live check would keep passing while saying something different from the tool
# the operator actually reads.
# Returns a hashtable - no pipeline writes in here.
# Why the lower half of the window is the signal: measured 2026-09-30 on Chrome with
# the page DOM hidden, EVERY control sat in the y=155-235 toolbar band of a 1565px
# window (24 Button / 1 Document / 1 Edit, none of them page content). Counting
# controls alone stays green while the page is unreachable - the position filter is
# what carries the meaning.
function Measure-A11yTree($win, [int]$maxDepth) {
  $r = @{ Nodes = 0; Interactive = 0; PageHits = 0; Tabs = 0; Rectless = 0; Kinds = ''; Sample = ''; Verdict = 'no-root' }
  $rr = Uia-Roots $win
  if (@($rr.Roots).Count -lt 1) { return $r }
  $inter = 'Button|MenuItem|ListItem|TabItem|Hyperlink|Text|Edit|ComboBox|CheckBox|RadioButton'
  $pageTop = $win.Top + [int]($win.H / 2)
  $kinds = @{}
  $samples = New-Object System.Collections.ArrayList
  foreach ($r0 in @($rr.Roots)) {
    foreach ($el in @(Uia-WalkAll @($r0) $maxDepth)) {
      $r.Nodes++
      $ct = ''
      try { $ct = $el.Current.ControlType.ProgrammaticName -replace 'ControlType\.', '' } catch { continue }
      if ($ct -eq 'TabItem') { $r.Tabs++ }
      if ($ct -notmatch "^($inter)$") { continue }
      $r.Interactive++
      $br = $null
      try { $br = $el.Current.BoundingRectangle } catch { $r.Rectless++; continue }
      # v3.0.1 (audit #6): this used to be a bare "$br.Y -ge $pageTop", and Rect.Empty's
      # Y is +Infinity - an element with NO rectangle passed it and was counted as page
      # content. PageHits is exactly what the exposed/collapsed verdict rests on, so the
      # inflation was a wrong verdict, not a cosmetic one. Rectless keeps the count of
      # what was skipped visible instead of silently losing it.
      if (-not (Test-UiaRectUsable $br)) { $r.Rectless++ }
      if (Test-UiaInPageArea $br $pageTop) {
        $r.PageHits++
        if (-not $kinds.ContainsKey($ct)) { $kinds[$ct] = 0 }
        $kinds[$ct] = $kinds[$ct] + 1
        # a Name sample from the page area is what turns 'page-area=28' into evidence:
        # a live check asserts these are page text, not toolbar chrome.
        $nmS = ''
        try { $nmS = $el.Current.Name } catch { }
        $nmST = "$nmS".Trim()
        if ($nmST.Length -ge 2 -and @($samples).Count -lt 4) {
          # Sample is DISPLAY, not a machine-readable field: a live case that re-parses it
          # to build a needle breaks the moment the format changes, and Names taken from a
          # live page are volatile anyway (a status Button carries a clock). Cases that
          # need a stable Name use a synthetic fixture instead.
          [void]$samples.Add("$ct|$($nmST.Substring(0, [Math]::Min(40, $nmST.Length)))")
        }
      }
    }
  }
  # Sample is capped at 4 entries and truncated to 40 chars: it exists so an operator can
  # SEE what the page area holds, not so a test can re-parse it.
  $r.Verdict = $(if ($r.PageHits -gt 0) { 'exposed' } else { 'collapsed' })
  $ks = New-Object System.Collections.ArrayList
  foreach ($e in $kinds.GetEnumerator()) { [void]$ks.Add("$($e.Key)=$($e.Value)") }
  $r.Kinds = ((@($ks) | Sort-Object) -join ',')
  $r.Sample = ((@($samples)) -join ' ;; ')
  return $r
}

# Pure: "does this Name contain the caller's substring?" - implemented with IndexOf,
# NOT with -like. -like treats [ ] * ? as wildcards, so a control whose Name literally
# contains one of them cannot be found by its own Name: measured 2026-09-30, a live case
# fed uia-find a Name the SAME measurement had just returned and got hits=0, because that
# Name contained '*'. Case-insensitive to keep the previous behaviour for ordinary
# needles. An empty needle is refused here as well as at the command, so a caller that
# skips the command's check still cannot get "matches everything".
# v3.0.1 (external-review follow-up): which root-level docs count as AUTHORITY docs? Pure, so
# both directions are testable without building a real repo. The live guard used to ask the
# FILESYSTEM, and that let an unrelated untracked .md (a review report someone dropped into the
# project root, first line mentioning desktop.ps1 like any real authority doc) change the count
# from 2 to 3 and turn two version checks red without anything about the shipped tree changing.
# Tracked-in == authority-in; an untracked file is reported, never silently dropped. With no git
# to ask, the guard falls back to the disk list and LABELS that it did - a helper binary having a
# bad moment must not fail a version check, and must not quietly redefine what is counted either.
function Split-AuthorityDocNames([string[]]$diskNames, [string[]]$trackedNames, [bool]$haveTracked) {
  $disk = @($diskNames | ForEach-Object { "$_" })
  if (-not $haveTracked) {
    return @{ Mode = 'disk-fallback'; Kept = $disk; Dropped = @() }
  }
  $trk = @($trackedNames | ForEach-Object { "$_".Trim() } | Where-Object { "$_" -ne '' })
  $kept = @($disk | Where-Object { (@($trk) -contains $_) })
  $dropped = @($disk | Where-Object { -not (@($trk) -contains $_) })
  return @{ Mode = 'tracked'; Kept = $kept; Dropped = $dropped }
}

function Test-NameSubstring($name, [string]$needle) {
  if ($null -eq $name) { return $false }
  if ("$needle".Length -eq 0) { return $false }
  return ([string]$name).IndexOf([string]$needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
}

# ---------- v2.1.0 (plan doc 1.2): the UIA cold-start re-contact ----------
# A first contact that returns 0 hits on a tree that barely scanned anything is the
# Chromium/Chromium-shell cold-start shape: the UIA client connection is what lights
# renderer accessibility, and it lights AFTER the walk that triggered it has already
# finished (measured 2026-09-30 on the owner's own default-profile Chrome: contact #1
# page-area=0 / 60 nodes, contacts #2-4 19 / 100). Measuring again is therefore part of
# the measurement, not a retry loop.
# Floor and decision are separate functions so the threshold has ONE producer and both
# directions are unit-testable. The WALK is injected by the caller, which is what makes
# "a re-contact turns a cold zero into a hit" a unit test rather than a race - the same
# split this repo uses everywhere (the RULE stays pure, the P/Invoke stays with the
# caller). An end-to-end live cold-start proof stays structurally unavailable and is NOT
# claimed: any compliant restart path lights the tree before the reader's first contact
# (owner ruling 2026-10-01 closing v1.8.0 limitation 15).
function Get-UiaReprobeFloor { return 25 }

# v4.2.0 (external feedback item 5, 2026-10-10): the ONE way a walk bound is printed, so
# find, uia-find and any later walker cannot spell the same fact three ways. 0 is
# Uia-WalkAll's "unlimited" - which is what these two roads actually run by default, a
# fact the echo used to keep to itself while callers blamed "the depth".
function Format-UiaWalkDepth([int]$maxDepth) {
  if ($maxDepth -le 0) { return 'unlimited (6000-node safety cap)' }
  return ("max=" + $maxDepth)
}

# ---------- v3.0.1 (audit #16): the numbers that were typed more than once ----------
# Same rule the project already applies to verdict strings - one literal, one owner -
# measured over the file: the UIA "big depth" was written five times, the DWM visible-frame
# attribute four, the viewer-width threshold twice, and the challenge probe alphabet twice
# (in two different live child scripts). A constant living in several places is a constant
# that can disagree with itself, and each of these decides something the tool reports.
function Get-UiaBigDepth { return 40 }
function Get-DwmVisibleFrameAttribute { return 9 }
function Get-ShotViewerWidePx { return 1000 }
function Get-ChallengeProbeAlphabet { return 'ACDEFHJKLMNPRTUVWXY' }

# Pure: given what the first contact measured, re-contact or not?
function Get-UiaReprobeDecision([int]$hits, [int]$scanned, [int]$floor) {
  if ($hits -gt 0) { return @{ Rerun = $false; Reason = 'hit on first contact' } }
  if ($floor -le 0) { return @{ Rerun = $false; Reason = 'reprobe disabled (floor 0)' } }
  if ($scanned -ge $floor) { return @{ Rerun = $false; Reason = "scanned=$scanned >= floor=$floor - the tree is deep enough that 0 hits reads genuinely absent, not cold" } }
  return @{ Rerun = $true; Reason = "scanned=$scanned < floor=$floor with 0 hits: cold-start shape, re-contact once" }
}

# Literal Name matching for a walked element list (same Test-NameSubstring rule the
# rest of the UIA family uses, so 'find' and 'uia-find' cannot disagree about what a
# Name contains). Returns the matching elements, in tree order.
function Measure-UiaElements($elements, [string]$needle, [string]$typeRe) {
  $out = New-Object System.Collections.ArrayList
  foreach ($el in @($elements)) {
    if ($null -eq $el) { continue }
    $nm = ''; $ct = ''
    try { $nm = $el.Current.Name } catch { }
    if ($typeRe) { try { $ct = $el.Current.ControlType.ProgrammaticName -replace 'ControlType\.', '' } catch { } }
    if ((Test-NameSubstring $nm $needle) -and (-not $typeRe -or $ct -match $typeRe)) { [void]$out.Add($el) }
  }
  return $out
}

# Run the search. $walk is a caller-supplied delegate invoked as `& $walk <contactNumber>`
# returning @{ Elements = @(...); Scanned = int; Roots = int; Via = string }. The SECOND
# contact is where a cold tree has usually finished lighting; any patience between
# contacts belongs to the walker (production sleeps there), not to this rule, so the
# rule stays testable offline.
function Search-UiaTree($walk, [string]$needle, [string]$typeRe, [int]$floor) {
  $p1 = & $walk 1
  $r = @{
    Hits = @(Measure-UiaElements $p1.Elements $needle $typeRe)
    Scanned = [int]$p1.Scanned; Roots = [int]$p1.Roots; Via = "$($p1.Via)"
    # v4.2.0 (feedback item 5): Walked/Depth are what separate THREE different zeros that
    # Scanned alone used to collapse into one number - a walk that stopped early, a region
    # filter that dropped everything, and an element that really is not there. Measured
    # 2026-10-10: find said "uia scanned 14" for a window uia-tree later walked at 184
    # nodes, and no reader could tell which of the three it was. Absent keys read 0
    # (Get-OptValue), so a fixture walk that does not supply them still works.
    Walked = [int](Get-OptValue $p1 'Walked'); Depth = [int](Get-OptValue $p1 'Depth')
    Walks = 1; Reprobe = 'no'; Reason = ''
  }
  $dec = Get-UiaReprobeDecision @($r.Hits).Count $r.Scanned $floor
  if (-not $dec.Rerun) { $r.Reason = $dec.Reason; return $r }
  $p2 = & $walk 2
  $h2 = @(Measure-UiaElements $p2.Elements $needle $typeRe)
  $r.Walks = 2
  # the LAST walk is the one a zero verdict rests on, so walked/depth follow it
  $r.Walked = [int](Get-OptValue $p2 'Walked'); $r.Depth = [int](Get-OptValue $p2 'Depth')
  $r.Reason = $dec.Reason
  $r.Reprobe = $(if (@($h2).Count -gt 0) { 'yes -> scanned=' + [int]$p2.Scanned + ', hits=' + @($h2).Count } else { 'yes -> still 0 (scanned=' + [int]$p2.Scanned + ')' })
  if (@($h2).Count -gt 0) {
    $r.Hits = $h2; $r.Scanned = [int]$p2.Scanned; $r.Roots = [int]$p2.Roots; $r.Via = "$($p2.Via)"
  }
  return $r
}

# ---------- v2.1.0 (plan doc 1.1): the composite locator 'find' ----------
# Which road answered, and it must never be silent: 'find' tries UIA first (cheaper,
# exact Name/rect/enabled/offscreen) and falls back to OCR. The DEGRADATION is the
# load-bearing fact for the caller - an agent that believes it got a UIA hit while
# actually getting OCR has different confidence in the coordinates. So the source is a
# required key in both the echo and --json, and a miss must name what EACH road
# measured (a bare 'not found' is how '0 hits' gets read as 'absent').
function Get-FindSourceDecision([int]$uiaHits, [int]$ocrHits) {
  if ($uiaHits -gt 0) { return @{ Source = 'uia'; Degraded = $false; Refuse = $false } }
  if ($ocrHits -gt 0) { return @{ Source = 'ocr'; Degraded = $true; Refuse = $false } }
  return @{ Source = 'none'; Degraded = $true; Refuse = $true }
}

# Both volumes or it did not happen: the miss line has to carry what the UIA road
# scanned and what the OCR road read, plus the reason each one came up short.
function Format-FindMiss([string]$needle, [int]$uiaWalked, [string]$uiaNote, [int]$ocrLines, [string]$ocrNote, [string]$regionTxt, [string]$occTxt) {
  # v4.2.0 (feedback item 5): $uiaWalked is what the walk actually REMOVED from the tree
  # (the region-filtered keep count is spelled out in $uiaNote instead), and a walk that
  # stayed under the reprobe floor never had a fair chance at the answer. That shape gets
  # its own sentence naming the READ-ONLY next step - materializing the tree costs a
  # uia-tree call, which has no side effect on any real session, unlike "just try again".
  # The threshold comes from the same producer the re-contact rule reads (one floor).
  $shallowTxt = ''
  if ($uiaWalked -gt 0 -and $uiaWalked -lt (Get-UiaReprobeFloor)) {
    $shallowTxt = " SHALLOW-TREE: the walk ended at $uiaWalked element(s), under the reprobe floor $((Get-UiaReprobeFloor)) - this a11y tree did not light, so the zero above measures the walk, not the screen. Materialize it READ-ONLY with 'uia-tree <sel> 45' and ask again; do not read this as absence."
  }
  return ("find: '$needle' found by NEITHER road - uia scanned $uiaWalked element(s) ($uiaNote); OCR read $ocrLines line(s) from $regionTxt ($ocrNote)$occTxt. " +
    "'not found' is NOT 'absent': the text may be painted without a control, folded by OCR into another line, or hidden behind an in-window scrim.$shallowTxt " +
    "Widen the region, try 'read-text' to see what is actually there, or 'zoom <x> <y> <w> <h> 3' on a small strip - and never go back to eyeballing a downscaled screenshot: use imgclick with the .map.txt the capture already wrote.")
}

# find's own --json envelope. It SHARES the global schemaVersion marker with the OCR
# envelopes but NOT their pinned key sets - adding a key to find's shape is still a
# contract change for find's consumers, which is what Find-JsonTopKeys + its lint below
# exist to catch. The two published find-text / read-text envelopes stay untouched.
function Get-FindJsonTopKeys { return @('schemaVersion', 'source', 'target', 'contentTrust', 'occluded', 'coveredBy', 'hits') }

# v3.1.0: the published read-text / find-text --json key contract, in ONE place. v3.0.0 (B-6)
# added `contentTrust` and bumped schemaVersion, and updated the OFFLINE copy of this list only -
# the live end-to-end case kept its own stale literal, so two live checks were red from the day
# they shipped and nobody noticed for two rounds because neither round ran --live. A contract
# written twice drifts; a lint now forbids a second literal copy of either list.
function Get-JsonContractKeySet([string]$which) {
  if ($which -eq 'read') { return (@('schemaVersion', 'contentTrust', 'occluded', 'coveredBy', 'lines') | Sort-Object) -join ',' }
  if ($which -eq 'find') { return (@('schemaVersion', 'contentTrust', 'occluded', 'coveredBy', 'hits') | Sort-Object) -join ',' }
  throw "Get-JsonContractKeySet: unknown envelope '$which' (expected read or find)"
}
function New-FindJsonEnvelope([string]$source, [string]$target, $gate, $hits) {
  $occJ = $null
  $covJ = @()
  if ($null -ne $gate) {
    if (-not $gate.Err) { $occJ = [int][math]::Round($gate.Pct) }
    $covJ = @($gate.Covering | ForEach-Object { [pscustomobject]@{ pid = $_.Pid; proc = $_.Proc; title = $_.Title; count = $_.Count } })
  }
  $map = @{
    schemaVersion = [int]$script:JsonSchemaVersion
    source = $source
    target = $target
    contentTrust = (Get-UntrustedContentTag)
    occluded = $occJ
    coveredBy = $covJ
    hits = @($hits)
  }
  return [pscustomobject]$map
}

function Uia-Line($el, [int]$depth, $path = $null, $actions = $null) {
  $ct = ''; $nm = ''; $aid = ''; $rect = '-'; $en = $false; $off = $true
  try { $ct = $el.Current.ControlType.ProgrammaticName -replace 'ControlType\.', '' } catch { }
  try { $nm = $el.Current.Name } catch { }
  try { $aid = $el.Current.AutomationId } catch { }
  try { $en = $el.Current.IsEnabled } catch { }
  try { $off = $el.Current.IsOffscreen } catch { }
  try {
    $r = $el.Current.BoundingRectangle
    if (-not $r.IsEmpty) { $rect = "$([int]$r.X),$([int]$r.Y),$([int]$r.Width)x$([int]$r.Height)" }
  } catch { }
  # v2.4.0: path= and actions= are APPEND-ONLY fields - the six historical fields
  # keep their order and spelling, and both new fields are $null-skipped, so
  # callers that pass nothing (uia-find, the c40 fixtures) emit the exact
  # pre-2.4.0 line. actions= is bracketed here so a probed-but-empty node prints
  # actions=[] and stays distinguishable from a node that was never probed
  # (no field at all).
  $line = (' ' * ($depth * 2)) + "$ct | name='$nm' | id='$aid' | $rect | enabled=$en offscreen=$off"
  if ($null -ne $path) { $line += " | path=$path" }
  if ($null -ne $actions) { $line += " | actions=[$actions]" }
  return $line
}

# v2.4.0: $ctx (uia-tree only) carries the output knobs and the cost counters:
#   NoPaths   - suppress the path= field (paths cost NO extra cross-process call:
#               the child index exists in the walk itself, so they default on)
#   NoActions - suppress pattern probing entirely
#   AllActions- probe every node, not just the interactive-type allowlist
#   Nodes / Probed / ProbeMs / Sw - what the actions-probed= footer reports
# $basePath is the parent's own path (/0 for the root), so a child's field is
# basePath + '/' + its sibling index, counted by the SAME enumeration the dump
# prints - a path read off a uia-tree line addresses exactly that line.
function Uia-Dump($el, [int]$depth, [int]$maxDepth, $ctx = $null, [string]$basePath = '') {
  if ($depth -gt $maxDepth) { return }
  $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
  $child = $walker.GetFirstChild($el)
  $idx = 0
  while ($null -ne $child) {
    $pField = $null
    $aField = $null
    if ($null -ne $ctx) {
      if (-not $ctx.NoPaths) { $pField = "$basePath/$idx" }
      if (-not $ctx.NoActions) {
        $t0 = $ctx.Sw.Elapsed.TotalMilliseconds
        $toks = Get-UiaActionTokens $child $ctx.AllActions
        $ctx.ProbeMs += ($ctx.Sw.Elapsed.TotalMilliseconds - $t0)
        if ($null -ne $toks) { $aField = "$toks"; $ctx.Probed++ }
      }
      $ctx.Nodes++
    }
    Uia-Line $child $depth $pField $aField
    Uia-Dump $child ($depth + 1) $maxDepth $ctx $pField
    $child = $walker.GetNextSibling($child)
    $idx++
  }
}

# v4.2.0 (external feedback item 4): THE --path decision, pure so both directions are
# offline checks. Rules: header lines (scan:/root:/note:) always ride along; a line with a
# path= field is kept when it IS the token (the node), is below it (the subtree), or is an
# ANCESTOR of it (so the caller sees where in the tree this reply sits); siblings and
# everything else is dropped. Ok=false when the token matched no node at all - an empty
# result must never be readable as "the tree is empty" or "the node is gone".
function Test-UiaPathFilter([string[]]$lines, [string]$token) {
  $kept = New-Object System.Collections.ArrayList
  $subN = 0; $ancN = 0
  foreach ($fl in @($lines)) {
    $s = "$fl"
    if ($s.StartsWith('scan:') -or $s.StartsWith('root:') -or $s.StartsWith('note:')) { [void]$kept.Add($s); continue }
    $pm = [regex]::Match($s, '\| path=(\S+)')
    if (-not $pm.Success) { continue }
    $lp = $pm.Groups[1].Value
    if ($lp -eq $token -or $lp.StartsWith($token + '/')) { [void]$kept.Add($s); $subN++ }
    elseif ($token.StartsWith($lp + '/')) { [void]$kept.Add($s); $ancN++ }
  }
  if ($subN -eq 0) { return @{ Ok = $false; Lines = @($kept); Sub = 0; Anc = 0; Summary = "$token -> 0 node(s)" } }
  return @{ Ok = $true; Lines = @($kept); Sub = $subN; Anc = $ancN; Summary = "path=$token -> $subN node(s) below it + $ancN ancestor(s)" }
}

function Uia-Find($root, [string]$nameSub, [string]$typeRe) {
  foreach ($el in (Uia-WalkAll $root)) {
    $nm = ''; $ct = ''
    try { $nm = $el.Current.Name } catch { }
    try { $ct = $el.Current.ControlType.ProgrammaticName -replace 'ControlType\.', '' } catch { }
    if ((Test-NameSubstring $nm $nameSub) -and (-not $typeRe -or $ct -match $typeRe)) { return $el }
  }
  return $null
}

# ---------- v2.4.0: action tokens + structural path handles ----------
# What a node can DO (the read side belongs to read-text/uia-find). Every
# GetCurrentPattern/GetSupportedPatterns call is a CROSS-PROCESS round trip, so
# uia-tree probes only an interactive-type allowlist by default; --actions-all
# lifts it and --no-actions skips probing entirely. Non-allowlisted nodes carry
# NO actions= field at all, so "not probed" and "probed but none" (actions=[])
# stay distinguishable.
$script:UiaActionAllowRe = '^(Button|MenuItem|Edit|CheckBox|RadioButton|ComboBox|ListItem|TabItem|TreeItem|Hyperlink|Slider|SplitButton)$'

# Pure: order an already-fetched pattern list into the fixed verb vocabulary.
# Read-side patterns (Text/Window/...) are deliberately NOT mapped: what a node
# can be read with is not an action. Returns a comma string ('' = probed and
# none) - a string survives the function boundary where an empty array would
# unwrap into a silent $null.
function Get-UiaActionTokensFromPatterns($patterns) {
  $found = @()
  foreach ($p in @($patterns)) { if ($null -ne $p) { $found += @($p) } }
  $toks = New-Object System.Collections.ArrayList
  foreach ($pair in @(
    @('invoke', [System.Windows.Automation.InvokePattern]::Pattern),
    @('toggle', [System.Windows.Automation.TogglePattern]::Pattern),
    @('select', [System.Windows.Automation.SelectionItemPattern]::Pattern),
    @('expand', [System.Windows.Automation.ExpandCollapsePattern]::Pattern),
    @('value',  [System.Windows.Automation.ValuePattern]::Pattern),
    @('scroll', [System.Windows.Automation.ScrollPattern]::Pattern),
    @('scroll', [System.Windows.Automation.ScrollItemPattern]::Pattern),
    @('range',  [System.Windows.Automation.RangeValuePattern]::Pattern))) {
    if (@($found) -contains $pair[1]) { if (-not $toks.Contains($pair[0])) { [void]$toks.Add($pair[0]) } }
  }
  return (@($toks) -join ',')
}

# Live probe: ONE GetSupportedPatterns call per probed node - that call IS the
# cross-process cost the actions-probed= footer reports. Returns $null when the
# node must not carry an actions= field (outside the allowlist and not
# --actions-all), '' when probed and nothing is supported, else the verb string.
function Get-UiaActionTokens($el, [bool]$all = $false) {
  $ct = ''
  try { $ct = $el.Current.ControlType.ProgrammaticName -replace 'ControlType\.', '' } catch { return '' }
  if (-not $all -and ("$ct" -cnotmatch $script:UiaActionAllowRe)) { return $null }
  $pats = @()
  try { $pats = @($el.GetSupportedPatterns()) } catch { $pats = @() }
  return (Get-UiaActionTokensFromPatterns $pats)
}

# Pure: a path token (already stripped of the @) must be /0 or /0/<i>... - digits
# only, and the first segment is the root by definition. Anything else is
# refused before any walk happens.
function Test-UiaPathTokenShape([string]$tok) {
  return ("$tok" -match '^/0(?:/\d+)*$')
}

# Walk a /0/2/1 route from the FIRST root, with the same ControlView walker,
# enumeration order and sibling counting as the uia-tree dump, so a path read
# off a uia-tree line lands on the node that line printed. maxDepth uses the
# uia-tree convention (0 = unlimited; a node at depth D is reachable iff
# D <= maxDepth), and a path needing more depth than the bound reports
# "path depth N > walked M" instead of failing silently. Returns a hashtable
# (hashtables survive the function boundary; string arrays do not):
#   Ok / El / Path / Reason / Detail / Depth / WalkedDepth / AtPath
function Resolve-UiaPath($roots, [string]$tok, [int]$maxDepth) {
  $r = @{ Ok = $false; El = $null; Path = "$tok"; Reason = 'malformed'; Detail = ''; Depth = 0; WalkedDepth = 0; AtPath = '' }
  if ("$tok" -notmatch '^@/') { $r.Detail = "path token must start with '@/' - got: $tok"; return $r }
  $t = "$tok".Substring(1)
  if (-not (Test-UiaPathTokenShape $t)) { $r.Detail = "path must look like /0/2/1 (digits, the root is /0) - got: $t"; return $r }
  $segs = @("$t".TrimStart('/').Split('/') | ForEach-Object { [int]$_ })
  $r.Depth = @($segs).Count - 1
  $r.WalkedDepth = $maxDepth
  if ($maxDepth -gt 0 -and $r.Depth -gt $maxDepth) {
    $r.Reason = 'too-deep'; $r.Path = $t
    $r.Detail = "path depth $($r.Depth) > walked $maxDepth"
    return $r
  }
  $rootList = @($roots)
  if ($rootList.Count -lt 1) { $r.Reason = 'no-root'; $r.Detail = 'no UIA root to walk from'; return $r }
  $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
  $cur = $rootList[0]
  $curPath = '/0'
  $segsCount = @($segs).Count
  for ($i = 1; $i -lt $segsCount; $i++) {
    $sibs = New-Object System.Collections.ArrayList
    try {
      $c = $walker.GetFirstChild($cur)
      while ($null -ne $c) { [void]$sibs.Add($c); $c = $walker.GetNextSibling($c) }
    } catch { }
    if ($segs[$i] -ge @($sibs).Count) {
      $r.Reason = 'dead-end'; $r.Path = $t; $r.AtPath = $curPath
      $r.Detail = "dead-end at $curPath (child index $($segs[$i]) of $(@($sibs).Count))"
      return $r
    }
    $cur = $sibs[$segs[$i]]
    $curPath = "$curPath/$($segs[$i])"
  }
  $r.Ok = $true; $r.El = $cur; $r.Path = $curPath
  return $r
}

# The three identity fields the path verification compares, in the exact shape
# the uia-tree line prints them, so a refusal's expected/actual lines can be
# diffed by eye against the tree the path came from.
function Get-UiaIdentity($el) {
  $ct = ''; $nm = ''; $rect = '-'; $parts = $null
  try { $ct = $el.Current.ControlType.ProgrammaticName -replace 'ControlType\.', '' } catch { }
  try { $nm = $el.Current.Name } catch { }
  try {
    $r = $el.Current.BoundingRectangle
    if (-not $r.IsEmpty) {
      $parts = @([int]$r.X, [int]$r.Y, [int]$r.Width, [int]$r.Height)
      $rect = "$($parts[0]),$($parts[1]),$($parts[2])x$($parts[3])"
    }
  } catch { }
  return @{ Type = $ct; Name = "$nm"; Rect = $rect; RectParts = $parts }
}

# Pure: parse the expected-identity token "Type|nameSub|X,Y,WxH" carried by the
# @path forms. The name field may be empty (nameless controls are the reason
# path handles exist); the rect field accepts the tree line's shape with or
# without surrounding parentheses, or '-' for an empty rect. Returns a
# hashtable or $null - exactly three fields, no guessing.
function Parse-UiaExpectToken([string]$tok) {
  $parts = "$tok".Split('|')
  if (@($parts).Count -ne 3) { return $null }
  $type = "$($parts[0])".Trim()
  if ($type.Length -lt 1) { return $null }
  $name = "$($parts[1])"
  $rectS = "$($parts[2])".Trim()
  if ($rectS -eq '-') { return @{ Type = $type; Name = $name; Rect = '-'; RectParts = $null } }
  if ($rectS -notmatch '^\(?(-?\d+),(-?\d+),(\d+)x(\d+)\)?$') { return $null }
  $rp = @([int]$Matches[1], [int]$Matches[2], [int]$Matches[3], [int]$Matches[4])
  return @{ Type = $type; Name = $name; Rect = "$($rp[0]),$($rp[1]),$($rp[2])x$($rp[3])"; RectParts = $rp }
}

# Pure: the three-field verification behind the @path forms. Every field that
# disagrees names itself; the caller turns a $false into a REFUSED block and
# never into a fallback action.
function Test-UiaExpectMatch($expect, $identity) {
  if ("$($expect.Type)" -cne "$($identity.Type)") {
    return @{ Ok = $false; Field = 'ControlType'; Detail = "expected ControlType $($expect.Type), actual $($identity.Type)" }
  }
  # An EMPTY expect name means "expect an unnamed element" (nameless controls are
  # the reason path handles exist) - it must NOT go through Test-NameSubstring,
  # which refuses empty needles by design, or every empty-name expect would be
  # refused forever (caught live on the calculator: a fully-matching node read
  # stale). Empty expects an unnamed actual; non-empty keeps the substring rule.
  if ("$($expect.Name)".Length -eq 0) {
    if ("$($identity.Name)".Length -ne 0) {
      return @{ Ok = $false; Field = 'Name'; Detail = "expected an unnamed element, actual '$($identity.Name)'" }
    }
  } elseif (-not (Test-NameSubstring $identity.Name $expect.Name)) {
    return @{ Ok = $false; Field = 'Name'; Detail = "expected Name containing '$($expect.Name)', actual '$($identity.Name)'" }
  }
  $eR = $expect.RectParts; $aR = $identity.RectParts
  if ($null -eq $eR -and $null -eq $aR) { return @{ Ok = $true; Field = ''; Detail = '' } }
  if (($null -eq $eR) -or ($null -eq $aR)) {
    return @{ Ok = $false; Field = 'rect'; Detail = "expected rect $($expect.Rect), actual rect $($identity.Rect)" }
  }
  for ($i = 0; $i -lt 4; $i++) {
    if ($eR[$i] -ne $aR[$i]) {
      return @{ Ok = $false; Field = 'rect'; Detail = "expected rect $($expect.Rect), actual rect $($identity.Rect)" }
    }
  }
  return @{ Ok = $true; Field = ''; Detail = '' }
}

# Pure: the REFUSED block for every path-handle failure mode. One producer, so
# uia-path and all three @path action routes refuse in the same shape, and every
# refusal names the locate/OCR roads instead of silently falling back to
# coordinates (a stale path must never become a click).
function Format-UiaPathRefusal([string]$tok, $res, $expect, $identity) {
  $path = "$($res.Path)"
  $fb = 'fallback: uia-find / find <text> / find-text (OCR)'
  if ($res.Reason -eq 'stale') {
    $eLine = "expected: $($expect.Type) | name='$($expect.Name)' | rect=$($expect.Rect)"
    $aLine = "actual: $($identity.Type) | name='$($identity.Name)' | rect=$($identity.Rect)"
    return "REFUSED: path=$path stale`n$eLine`n$aLine`n$fb"
  }
  return "REFUSED: path=$path $($res.Reason)`nactual: $($res.Detail)`n$fb"
}

# Shared tail of both uia-click routes: InvokePattern first, else a centre click
# on the VERIFIED element. Returns the echo line, in both routes' wording.
function Invoke-UiaClickable($el) {
  $nm = ''
  try { $nm = $el.Current.Name } catch { }
  try {
    $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
    return "InvokePattern ok: $nm"
  } catch {
    # No InvokePattern means the only road left is a centre click, and a centre click
    # needs a rectangle that exists (audit #7: this cast Rect.Empty's infinities straight
    # into [int], so the caller got a type error AFTER a verified path - or, if the
    # element had gone stale mid-flight, a COM exception from the property read itself).
    # Either way the answer is a refusal that clicked nothing.
    $r = $null
    try { $r = $el.Current.BoundingRectangle } catch { }
    if (-not (Test-UiaRectUsable $r)) {
      throw "uia-click: '$nm' has no InvokePattern and no usable rectangle (UIA reported Rect.Empty) - nothing was clicked"
    }
    $x = [int]($r.X + $r.Width / 2)
    $y = [int]($r.Y + $r.Height / 2)
    Move-Click $x $y 'left'
    return "no InvokePattern, clicked centre ($x,$y) of: $nm"
  }
}

# v2.4.0 path-handle route for uia-click: uia-click <sel> @/0/2/1 "Type|nameSub|X,Y,WxH".
# Walk -> re-verify -> act, in that order, and nothing acts on a failed verify:
# the refusal block goes to stdout and the throw behind it turns into exit 1 at
# the process boundary.
function Invoke-UiaClickByPath($rest) {
  if (@($rest).Count -lt 3) { throw 'usage: uia-click <sel> @/0/2/1 <Type|nameSub|X,Y,WxH>' }
  $w = Resolve-Window $rest[0]
  if (-not $w) { throw "no window matching: $($rest[0])" }
  $rr = Uia-Roots $w
  if ($rr.Roots.Count -lt 1) { throw "no UIA root for pid $($w.Pid)" }
  $xp = Parse-UiaExpectToken $rest[2]
  if ($null -eq $xp) { throw "uia-click: expected token must look like 'Button|OK|123,45,80x24' - got: $($rest[2])" }
  $res = Resolve-UiaPath $rr.Roots $rest[1] 0
  if (-not $res.Ok) {
    Write-Output (Format-UiaPathRefusal $rest[1] $res $xp $null)
    throw "uia-click: path $($res.Path) refused ($($res.Reason)) - nothing was clicked"
  }
  $id = Get-UiaIdentity $res.El
  $m = Test-UiaExpectMatch $xp $id
  if (-not $m.Ok) {
    Write-Output (Format-UiaPathRefusal $rest[1] @{ Ok = $false; Reason = 'stale'; Path = "$($res.Path)" } $xp $id)
    throw "uia-click: path $($res.Path) stale - nothing was clicked"
  }
  return (Invoke-UiaClickable $res.El)
}

# v2.4.0 path-handle route for uia-focus: uia-focus <sel> @/0/2/1 "Type|nameSub|X,Y,WxH".
function Invoke-UiaFocusByPath($rest) {
  if (@($rest).Count -lt 3) { throw 'usage: uia-focus <sel> @/0/2/1 <Type|nameSub|X,Y,WxH>' }
  $w = Resolve-Window $rest[0]
  if (-not $w) { throw "no window matching: $($rest[0])" }
  $rr = Uia-Roots $w
  if ($rr.Roots.Count -lt 1) { throw "no UIA root for pid $($w.Pid)" }
  $xp = Parse-UiaExpectToken $rest[2]
  if ($null -eq $xp) { throw "uia-focus: expected token must look like 'Button|OK|123,45,80x24' - got: $($rest[2])" }
  $res = Resolve-UiaPath $rr.Roots $rest[1] 0
  if (-not $res.Ok) {
    Write-Output (Format-UiaPathRefusal $rest[1] $res $xp $null)
    throw "uia-focus: path $($res.Path) refused ($($res.Reason)) - nothing was focused"
  }
  $id = Get-UiaIdentity $res.El
  $m = Test-UiaExpectMatch $xp $id
  if (-not $m.Ok) {
    Write-Output (Format-UiaPathRefusal $rest[1] @{ Ok = $false; Reason = 'stale'; Path = "$($res.Path)" } $xp $id)
    throw "uia-focus: path $($res.Path) stale - nothing was focused"
  }
  $res.El.SetFocus()
  return "focused element: $($res.Path) ($($id.Type) name='$($id.Name)')"
}

# v2.4.0 path-handle route for uia-settext:
# uia-settext <sel> @/0/2/1 <file> "Type|nameSub|X,Y,WxH" - same
# re-verify-then-act contract, then the existing readback-verified SetValue.
function Invoke-UiaSettextByPath($rest, [string]$CmdName) {
  if (@($rest).Count -lt 4) { throw 'usage: uia-settext <sel> @/0/2/1 <file> <Type|nameSub|X,Y,WxH>' }
  $w = Resolve-Window $rest[0]
  if (-not $w) { throw "no window matching: $($rest[0])" }
  if (-not (Test-Path -LiteralPath $rest[2] -PathType Leaf)) { throw "file not found: $($rest[2])" }
  $text = (Read-SendFileUtf8 $rest[2]).Text
  $rr = Uia-Roots $w
  if ($rr.Roots.Count -lt 1) { throw "no UIA root for pid $($w.Pid)" }
  $xp = Parse-UiaExpectToken $rest[3]
  if ($null -eq $xp) { throw "uia-settext: expected token must look like 'Button|OK|123,45,80x24' - got: $($rest[3])" }
  $res = Resolve-UiaPath $rr.Roots $rest[1] 0
  if (-not $res.Ok) {
    Write-Output (Format-UiaPathRefusal $rest[1] $res $xp $null)
    throw "uia-settext: path $($res.Path) refused ($($res.Reason)) - nothing was written"
  }
  $id = Get-UiaIdentity $res.El
  $m = Test-UiaExpectMatch $xp $id
  if (-not $m.Ok) {
    Write-Output (Format-UiaPathRefusal $rest[1] @{ Ok = $false; Reason = 'stale'; Path = "$($res.Path)" } $xp $id)
    throw "uia-settext: path $($res.Path) stale - nothing was written"
  }
  $vp = Uia-SettableValue $res.El
  if ($null -eq $vp) { throw "element at $($res.Path) ($($id.Type) name='$($id.Name)') exposes no settable ValuePattern; fall back to: click the field then paste <file>" }
  Log-Action @('uia-settext', "$($rest[1])", "$($rest[2])", "$($rest[3])") "pid=$($w.Pid) title='$($w.Title)' path=$($res.Path) file=$($rest[2])" $CmdName
  $vp.SetValue($text)
  $back = $null
  try { $back = $res.El.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value } catch { }
  if ($null -eq $back) { try { $back = $res.El.Current.Name } catch { } }
  if ($back -ne $text) { throw "uia-settext readback mismatch on path $($res.Path) (wrote $($text.Length) chars)" }
  return "set text via ValuePattern on path $($res.Path) ($($id.Type) name='$($id.Name)'): wrote $($text.Length) chars, readback match=True"
}

# Returns the ValuePattern of $el when it is present AND not read-only,
# otherwise $null. Used by uia-settext to pick a genuinely settable element.
function Uia-SettableValue($el) {
  try {
    $vp = $el.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
    if (-not $vp.Current.IsReadOnly) { return $vp }
  } catch { }
  return $null
}

# selftest - mechanical regression checks, run via: desktop.ps1 selftest [--live] [--timing] [--index] [--only <pat>]
#
# Why this exists: v1.3.0 shipped a bug that no amount of reading the code
# caught. In PowerShell 5.1, a function ending in "return ,$list" hands the
# caller the list itself when assigned bare, but @(Fn) captures the OUTER
# 1-element wrapper instead - so $hits.Count is permanently 1 and every
# "if ($hits.Count -eq 0)" check silently never fires. That had disabled
# "type --verify" (and would have disabled the content guard had it used the
# same shape). The lint below forbids that call shape for every comma-returning
# helper, discovered dynamically so a new helper is covered automatically.
#
# v4.3.0 (--index / --only): builders and filters for the scoped-run feature.
# ONE index producer feeds both the --index fast path and the in-run contract check
# ("every emitted name is in the index"), so the two can never disagree. Static sites
# are the literal ST-Check/ST-Skip names; the three region-contract templates are
# expanded once per REGION-BEGIN tag; one extra template covers the step-flag loop
# whose name is assembled from $tc.cmd at run time. The --only filter is consulted
# ONLY through Test-StOnlyAbsorb, whose only two call sites are the two emitters.
function Get-SelftestIndexEntries($lines) {
  $entries = New-Object System.Collections.ArrayList
  $ls = @($lines)
  $tags = New-Object System.Collections.ArrayList
  for ($i = 0; $i -lt $ls.Count; $i++) {
    $mTag = [regex]::Match([string]$ls[$i], 'REGION-BEGIN ([a-z][a-z0-9-]*)')
    if ($mTag.Success) { [void]$tags.Add($mTag.Groups[1].Value) }
    $mChk = [regex]::Match([string]$ls[$i], "^[ \t]*ST-(Check|Skip) '((?:''|[^'])+)'")
    if ($mChk.Success) {
      [void]$entries.Add([pscustomobject]@{ Line = $i + 1; Name = $mChk.Groups[2].Value.Replace("''", "'"); Kind = 'static'; Pattern = '' })
    }
  }
  foreach ($t in @($tags)) {
    [void]$entries.Add([pscustomobject]@{ Line = 0; Name = ("contract: region '" + $t + "' is delimited by both of its marker lines"); Kind = 'region'; Pattern = '' })
    [void]$entries.Add([pscustomobject]@{ Line = 0; Name = ("contract: region '" + $t + "' yields at least one check name from its own source"); Kind = 'region'; Pattern = '' })
    [void]$entries.Add([pscustomobject]@{ Line = 0; Name = ("contract: region '" + $t + "' emitted exactly the check names its source declares"); Kind = 'region'; Pattern = '' })
  }
  [void]$entries.Add([pscustomobject]@{ Line = 0; Name = 'unit: <cmd> string-value step keeps payload clean and flags bare'; Kind = 'template'; Pattern = '^unit: .+ string-value step keeps payload clean and flags bare$' })
  [void]$entries.Add([pscustomobject]@{ Line = 0; Name = 'lint: no @()/$() wrapper around <discovered helper>'; Kind = 'template'; Pattern = '^lint: no @\(\)/\$\(\) wrapper around (?:hashtable helper )?[A-Za-z][A-Za-z0-9-]*$' })
  [void]$entries.Add([pscustomobject]@{ Line = 0; Name = 'lint: pattern detects a planted violation for <discovered helper>'; Kind = 'template'; Pattern = '^lint: pattern detects a planted violation for [A-Za-z][A-Za-z0-9-]*$' })
  return @{ Entries = @($entries) }
}

function Resolve-SelftestOnlyPattern([string[]]$rest) {
  $r = @($rest)
  $idx = [array]::IndexOf($r, '--only')
  if ($idx -lt 0) { return '' }
  if ([array]::IndexOf($r, '--only', $idx + 1) -ge 0) { throw 'selftest: --only was given more than once' }
  if ($idx -ge ($r.Count - 1)) { throw 'selftest: --only needs a pattern value (usage: selftest [--live] [--timing] [--index] [--only <pat>])' }
  $val = [string]$r[$idx + 1]
  if ($val.StartsWith('--')) { throw ("selftest: --only got the flag-like token '" + $val + "' - pass a check-name fragment, e.g. --only P-06") }
  if ($val.Trim().Length -eq 0) { throw 'selftest: --only got an empty pattern' }
  return $val
}

function Test-OnlyPatternMatch([string]$pat, [string]$name) {
  if ($pat -eq '') { return $true }
  return ($name.IndexOf($pat, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
}

function Test-StOnlyAbsorb([string]$name) {
  if (-not $script:StOnlyActive) { return $false }
  return (-not (Test-OnlyPatternMatch $script:StOnlyPat $name))
}

function Format-SelftestSummary($pass, $fail, $skip, $absorbed, $absorbedFail, [string]$onlyPat) {
  $base = '----- selftest: ' + $pass + ' passed, ' + $fail + ' failed, ' + $skip + ' skipped'
  if ($onlyPat -eq '') { return ($base + ' -----') }
  $reported = [int]$pass + [int]$fail + [int]$skip
  $total = $reported + [int]$absorbed
  return ($base + ' (--only ' + "'" + $onlyPat + "': " + $reported + ' reported, ' + $absorbed + ' absorbed incl. ' + $absorbedFail + ' failed, of ' + $total + ') -----')
}

function ST-Check([string]$name, [bool]$ok) {
  if ($null -ne $script:StEmittedAll) { [void]$script:StEmittedAll.Add($name) }
  if ($null -ne $script:StRecord) { [void]$script:StRecord.Add($name) }
  if (Test-StOnlyAbsorb $name) { $script:StAbsorbed++; if (-not $ok) { $script:StAbsorbedFail++ }; return }
  # v4.2.4 (--timing): one bracket per emitted line says how long THIS check took. The recorded
  # NAME stays clean, so the region reconciliation and the PASS line-count contract are blind to
  # it; under a normal run the flag is $false and the output shape is byte-identical to before.
  $stTag = ''
  if ($script:StTiming) {
    $stNow = $script:StSw.Elapsed.TotalMilliseconds
    $stTag = '   [+' + [int]($stNow - $script:StLastMs) + 'ms]'
    $script:StLastMs = $stNow
  }
  if ($ok) {
    $script:StPass++
    if ($null -ne $script:StPassLines) { [void]$script:StPassLines.Add("PASS  $name") }
    Write-Output "PASS  $name$stTag"
  }
  else { $script:StFail++; Write-Output "FAIL  $name$stTag" }
}

# v1.5.1 WP-C: a check that COULD not run (environment-dependent, e.g. no
# click-through overlay windows present on this desktop) is its own outcome.
# It shows up in the summary as skipped - never silently absorbed into passed.
function ST-Skip([string]$name, [string]$reason) {
  if ($null -ne $script:StEmittedAll) { [void]$script:StEmittedAll.Add($name) }
  if ($null -ne $script:StRecord) { [void]$script:StRecord.Add($name) }
  if (Test-StOnlyAbsorb $name) { $script:StAbsorbed++; return }
  $script:StSkip++
  $stTag = ''
  if ($script:StTiming) {
    $stNow = $script:StSw.Elapsed.TotalMilliseconds
    $stTag = '   [+' + [int]($stNow - $script:StLastMs) + 'ms]'
    $script:StLastMs = $stNow
  }
  Write-Output "SKIP  $name - $reason$stTag"
}

# v4.1.3 (external review A/B): a block of checks that cannot run in THIS context used
# to vanish from the count instead of reporting itself, so the offline total measured
# the machine (recognizer reachable, PATH shape, engine) rather than the product - and
# the declared total could only ever agree on one box. The fix is structural: the check
# names inside a marked region are read back out of this file's own source, and the
# cannot-run branch emits one SKIP per name. No hand-maintained list, so a check added
# inside a region cannot be forgotten by the skip side, and ST-ReconcileRegion proves the
# two agree on every machine - including the ones where the region really does run.
function Get-RegionCheckNames {
  param([string[]]$Lines, [string]$Tag)
  $rgBegin = -1
  $rgEnd = -1
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($rgBegin -lt 0) {
      if ($Lines[$i].Contains('REGION-BEGIN ' + $Tag)) { $rgBegin = $i }
      continue
    }
    if ($Lines[$i].Contains('REGION-END ' + $Tag)) { $rgEnd = $i; break }
  }
  $rgNames = New-Object System.Collections.ArrayList
  if ($rgBegin -ge 0 -and $rgEnd -gt $rgBegin) {
    for ($i = $rgBegin + 1; $i -lt $rgEnd; $i++) {
      if ($Lines[$i] -match "ST-Check '([^']+)'") { [void]$rgNames.Add($Matches[1]) }
    }
  }
  return @{ Begin = $rgBegin; End = $rgEnd; Names = @($rgNames) }
}

# The cannot-run half of a region: one SKIP per declared name, so the total does not move.
function ST-SkipRegion([string]$Tag, [string]$Reason) {
  $rg = Get-RegionCheckNames -Lines @($script:StSourceLines) -Tag $Tag
  if ($rg.Begin -lt 0 -or $rg.End -le $rg.Begin) {
    ST-Check ("contract: region '" + $Tag + "' is delimited by both of its marker lines") $false
    return 0
  }
  if (@($rg.Names).Count -lt 1) {
    ST-Check ("contract: region '" + $Tag + "' yields at least one check name from its own source") $false
    return 0
  }
  foreach ($rgn in @($rg.Names)) { ST-Skip $rgn $Reason }
  Write-Output ("      region " + $Tag + ": " + @($rg.Names).Count + " check(s) skipped as a block")
  return @($rg.Names).Count
}

# Runs in BOTH halves of a region. Whatever the region emitted at runtime must be exactly
# the set its source declares - a check that disappears because a precondition went false
# and nobody accounted for it turns this red, which is the point of the mechanism.
function ST-ReconcileRegion([string]$Tag, [array]$Emitted) {
  $rg = Get-RegionCheckNames -Lines @($script:StSourceLines) -Tag $Tag
  $declared = @($rg.Names)
  $got = @($Emitted)
  $a = (@($got) | Sort-Object) -join "`n"
  $b = (@($declared) | Sort-Object) -join "`n"
  ST-Check ("contract: region '" + $Tag + "' emitted exactly the check names its source declares") (
    @($declared).Count -ge 1 -and @($got).Count -eq @($declared).Count -and ($a -ceq $b))
  if ($a -cne $b) {
    $miss = @(@($declared) | Where-Object { -not (@($got) -contains $_) })
    $extra = @(@($got) | Where-Object { -not (@($declared) -contains $_) })
    Write-Output ("      region " + $Tag + " declared=" + @($declared).Count + " emitted=" + @($got).Count +
      " never-emitted=[" + ($miss -join ' | ') + "] unexpected=[" + ($extra -join ' | ') + "]")
  }
}

. (Join-Path $PSScriptRoot 'lib/handlers-read.ps1') # <<< stitch: lib/handlers-read.ps1
. (Join-Path $PSScriptRoot 'lib/handlers-act.ps1') # <<< stitch: lib/handlers-act.ps1
. (Join-Path $PSScriptRoot 'lib/handlers-ui.ps1') # <<< stitch: lib/handlers-ui.ps1
. (Join-Path $PSScriptRoot 'lib/handlers-batch.ps1') # <<< stitch: lib/handlers-batch.ps1
. (Join-Path $PSScriptRoot 'lib/caller-runtime.ps1') # <<< stitch: lib/caller-runtime.ps1
. (Join-Path $PSScriptRoot 'lib/selftest.ps1') # <<< stitch: lib/selftest.ps1
. (Join-Path $PSScriptRoot 'lib/selftest-split-machine.ps1') # <<< stitch: lib/selftest-split-machine.ps1
. (Join-Path $PSScriptRoot 'lib/selftest-repo-contract.ps1') # <<< stitch: lib/selftest-repo-contract.ps1
. (Join-Path $PSScriptRoot 'lib/selftest-clipboard-input.ps1') # <<< stitch: lib/selftest-clipboard-input.ps1
. (Join-Path $PSScriptRoot 'lib/selftest-challenge-workflow.ps1') # <<< stitch: lib/selftest-challenge-workflow.ps1
. (Join-Path $PSScriptRoot 'lib/selftest-capture-ocr.ps1') # <<< stitch: lib/selftest-capture-ocr.ps1
. (Join-Path $PSScriptRoot 'lib/selftest-flags-grammar.ps1') # <<< stitch: lib/selftest-flags-grammar.ps1
. (Join-Path $PSScriptRoot 'lib/selftest-window-targeting.ps1') # <<< stitch: lib/selftest-window-targeting.ps1
. (Join-Path $PSScriptRoot 'lib/selftest-chrome-cdp.ps1') # <<< stitch: lib/selftest-chrome-cdp.ps1
. (Join-Path $PSScriptRoot 'lib/selftest-docs-contract.ps1') # <<< stitch: lib/selftest-docs-contract.ps1
. (Join-Path $PSScriptRoot 'lib/selftest-popup-occlusion.ps1') # <<< stitch: lib/selftest-popup-occlusion.ps1
. (Join-Path $PSScriptRoot 'lib/selftest-audit-output.ps1') # <<< stitch: lib/selftest-audit-output.ps1
. (Join-Path $PSScriptRoot 'lib/selftest-expect-family.ps1') # <<< stitch: lib/selftest-expect-family.ps1
. (Join-Path $PSScriptRoot 'lib/selftest-drag-press.ps1') # <<< stitch: lib/selftest-drag-press.ps1
. (Join-Path $PSScriptRoot 'lib/selftest-live-suite.ps1') # <<< stitch: lib/selftest-live-suite.ps1
. (Join-Path $PSScriptRoot 'lib/selftest-gate-meta.ps1') # <<< stitch: lib/selftest-gate-meta.ps1
function Get-UsageText {
  @'
desktop.ps1 v4.6.1 - Windows desktop automation (DPI-aware, absolute screen pixels)

  per-command help: `help <command>` prints just that command's entry (flags,
  semantics, the version note lines). `help` with no argument is this whole page.

  Each process invocation is recorded under %LOCALAPPDATA%\AgentComputerUse\runtime\v1.
  Independent overlap and unavailable-state warnings go to stderr and do not block commands.
  Caller identity is self-reported from DTX_CALLER_* or inherited Codex session fields.

  read
    shot [outPath] [--fit px] [--grid [step] | --no-grid] [--occlude off|warn|strict]
                                    capture whole virtual screen; one output path
                                    only. For a local image use rect 0 2010 400
                                    80 <outPath> --fit 0, then imgclick or unmap
                                    with the capture's .map.txt sidecar.
    win <sel> [outPath] [--fit px|0] [--grid [step] | --no-grid] [--mark x,y]
              [--occlude off|warn|strict]
                                    capture a window; echoes the image->screen
                                    mapping (screen = image + (L,T), or
                                    (L + ix/scale, T + iy/scale) when fitted)
                                    and the labelled occluded=N% verdict if covered
    rect <x> <y> <w> <h> [outPath] [--fit px|0] [--grid [step] | --no-grid] [--mark x,y]
              [--occlude off|warn|strict]
                                    capture a region. Default fit=900: wider
                                    crops are saved downscaled with an explicit
                                    scale in the echo, so eyeballed coordinates
                                    survive viewer downsampling; --fit 0 keeps
                                    full resolution; --grid overlays a grid
                                    labelled in SCREEN pixels; --mark draws a
                                    crosshair at a candidate click point
                                    v1.5.7: a capture that the caller asked to fit
                                    AND that still comes out wider than 1000px gets
                                    a grid automatically (the echo says "auto"),
                                    because that is exactly the image class where
                                    eyeballed coordinates were measured wrong twice;
                                    --no-grid turns it off. The grid exists only on
                                    the saved PNG (hash/OCR read screen pixels, so
                                    no judgement is polluted), and imgclick warns
                                    when a sidecar says the image carries one.
    zoom <x> <y> <w> <h> [scale] [outPath]
                                    small region enlarged (default 2x) + echo
                                    mapping screen = (x + ix/scale, y + iy/scale)
    wins                            list visible windows: pid proc class popup
                                    owner main rect size title (popup=yes marks
                                    context menus - they are their OWN top-level
                                    windows. main=yes|no is the ONE window a pid
                                    means (largest unowned window of that pid),
                                    owner= is GW_OWNER or '-': a Steam-style promo
                                    popup shares pid, class AND WS_POPUP with the
                                    app window, so popup=yes cannot separate them
                                    and main= was the missing column (D-7))
    status-summary [--json]         read-only checkpoint: HEAD, clean/ahead,
                                    offline selftest counts, latest live log and
                                    red count, plus DTX window residuals
    info <sel>                      pid / handle / proc / class / owner / main /
                                    rects / pick
    rect-of <sel>                   print "x y w h" of <sel> only
    cursor                          print current cursor position
    dpi                             print DPI awareness mode + per-monitor bounds
    color-at <x> <y>                pixel colour as #RRGGBB (link-up LEDs etc.)
    find-color <x> <y> <w> <h> <#RRGGBB> [--tolerance n] [--all]
                                    first match in region (cap 500) or ERROR
    find <text...> [--target <sel>] [--region x,y,w,h] [--depth n] [--needle <text>]
                                    v2.1.0 (plan doc 1.1) COMPOSITE LOCATOR: tries UIA
                                    first (Name/rect/enabled/offscreen, with the
                                    cold-start re-contact of plan 1.2), falls back to OCR
                                    over the same rect, and REPORTS WHICH ROAD ANSWERED
                                    (`source=uia|ocr`) - never silently. A miss names
                                    what BOTH roads measured (elements walked / lines
                                    read), because a bare 'not found' is how a zero gets
                                    read as 'absent'. v4.2.0: the UIA road self-reports
                                    walked= (before the region filter), kept= (after it)
                                    and depth= - so a zero says whether the walk stopped
                                    short, the filter ate the nodes, or the element is
                                    really not there; [--depth n] bounds the walk and 0
                                    (the default) means unlimited, printed as such. A
                                    walk under the reprobe floor ends the miss with a
                                    SHALLOW-TREE sentence pointing at read-only uia-tree.
                                    Read-only: it never activates or
                                    raises a window (raising one is how a second click on
                                    a dropdown silently missed, v1.5.6 D-2/A-2); no
                                    --target/--region means the ACTUAL foreground window,
                                    echoed as via=foreground. --json adds `source` and
                                    `target` to find's own envelope (find-text / read-text
                                    key sets are unchanged). Coordinates in the echo are
                                    physical screen pixels - centre is ready for `click`.
                                    Which road first? The help page prints one ladder
                                    headed "Taking a coordinate off the screen - the ORDER,
                                    not a menu" (find -> uia-find -> find-text/find-click
                                    -> imgclick); eyeballing a fitted or downscaled
                                    screenshot is not a step in it.
    Taking a coordinate off the screen - the ORDER, not a menu (v2.1.0, plan doc 1.3):
      1  find <text>                 UIA first, OCR second, and it SAYS which answered
      2  uia-find <sel> <name>       exact Name/rect/enabled/offscreen; re-contacts once
                                      on the cold-start shape before calling it 0
      3  find-text / find-click      OCR road: line rect + ready centre, no control needed
      4  imgclick <img> <ix> <iy>    the ONLY supported way from a pixel you SAW in a saved
                                      image to a screen click - it reads the .map.txt that
                                      win/rect/zoom wrote beside that image (unmap prints
                                      the mapping without clicking)
      Guessing a point off a fitted or downscaled screenshot is NOT step 5 and is not a
      method: measured on 2026-10-01, four clicks in one session landed on the wrong thing
      that way, and each one cost a retry cycle to notice. Steps 1-3 hand back centre=.
    find-text <sel|x y w h> <needle...> [--all] [--scale auto|1|2|tiled]
                                    OCR the region, return screen rect(s) of
                                    matching lines (structured locator for
                                    a11y-less Qt/Java/Chromium apps). A HIT IS A
                                    LINE, not an occurrence: text that appears
                                    twice on one line is one hit and --index
                                    selects lines - when those two numbers
                                    differ the command prints a hint saying so
                                    (v1.5.7 J-05, line granularity is deliberate)
    read-text <sel|x y w h> [--file <png>] [--max-lines n | --all-lines] [--filter needle]
                                    OCR the region, print lines + screen rects;
                                    --filter keeps matching lines (line numbers
                                    preserved), --max-lines caps the output.
                                    v2.0.0 P-4b: a region >= 300k px2 gets a
                                    modal/scrim WARN when its line density is below
                                    the active area band (small < 500k uses the
                                    relaxed 1.0 default; large uses 1.5; the
                                    self-report names band and threshold). Text mode
                                    only; --min-line-density tunes either band or
                                    silences it, 0 = off.
                                    v2.9.0 CHANGES THAT DEFAULT FOR read-text ONLY, to
                                    0.1, and adds a measurement that is always printed:
                                    readability=<n> lines per 100k px2 (area=..., 
                                    warn-below=..., band=...). Reason is measured: over
                                    489 real captures the 1.5 band fired on 91 of them
                                    (18.6%) because it cuts through the mode of ordinary
                                    traffic - 214 quiet reads sit in [1.5,2.0) alone -
                                    while every genuine failure shape sits far lower (the
                                    modal/scrim incident measured 0.07, blank reads 0.00).
                                    A dump should REPORT its quality; a shout belongs
                                    only where the read cannot support a conclusion.
                                    find-text / assert-text / expect / challenge-probe
                                    KEEP the 1.5 band: there the read is the claim of
                                    absence, so the alarm belongs. --min-line-density 0
                                    silences the WARN and the label together.
                                    v2.7.0 --file <png>: OCR a SAVED capture instead
                                    of a live region, so OCR quality becomes something
                                    you can measure offline, replay, and A/B between
                                    recognizers - no window is raised, nothing is
                                    clicked, no other automation can collide with the
                                    measurement. Lines then carry img-rect=(x,y,WxH),
                                    IMAGE px from the image's own top-left - NOT a
                                    screen rect, and deliberately a different label from
                                    rect= so a file read cannot be pasted into a click.
                                    --json is refused in file mode: the read-text
                                    envelope is a pinned key set with no field to say
                                    which coordinate space it is in, and an ambiguous
                                    one is worse than a refusal. --scale 2 upscales the
                                    image before reading; --scale tiled cuts it in half
                                    along the long side and reads the pieces (v2.8.0).
                                    v2.8.1 auto-retry: a capture of >= 30000 px2 that
                                    reads 0 lines is re-read through a ladder - the whole
                                    image at 2x, then four un-upscaled overlapping crops
                                    - and the header names every pass with what it got,
                                    including zeros, a pass skipped because --max-tiles
                                    refused it, and a pass skipped because the engine's
                                    own dimension limit rules the upscale out (a
                                    6000px-wide capture used to ERROR there rather than
                                    fall through to the crops). That report is the point:
                                    "a photo", "the recognizer lost a region" and "we
                                    never looked" must not print the same line. --no-tile
                                    turns the ladder off. The 300k px2 band belongs to the
                                    sparse WARN only - an empty read is suspicious far
                                    below it. In file mode the sparse WARN says
                                    "image is WxH", never "region".
    hash <sel|x y w h>              MD5 of the region PNG (assert-hash input)
    ime                             foreground thread HKL / IME active
    ime-state                       CONVERSION mode (alphanumeric vs native) -
                                    read via the default IME window
    ime-en [hkl]                    switch the foreground thread's conversion mode
                                    to alphanumeric and READ BACK; the echo prints
                                    the exact command that restores the old mode
    ime-cn [mode]                   switch to native (Chinese composition) and read
                                    back; same restore hint
    assert-window <sel>             exit 0 when a window matches (checkpoint)
    assert-text <sel|x y w h> <needle...> [--scale a|1|2|tiled] [--max-tiles n]
                                    OCR + exit-code check; --allow-occluded /
                                    --occlude as for the other needle commands
    assert-color <x> <y> <#RRGGBB> [tol]
                                    pixel equality as a verdict (LEDs, spinners)
    assert-hash <sel|x y w h> ==|!= <hash>
                                    region MD5 against a hash from 'hash'
    assert-stable <sel|x y w h> <sec> [--interval ms]
                                    two identical consecutive frames = settled
                                    (never true for blinking cursors/animations)
    assert-changed <sel|x y w h> <sec> [--interval ms]
                                    the opposite: wait until the region DOES
                                    change; timeout text says the action probably
                                    did nothing
    ocr-cap                         read-only: OCR engine MaxImageDimension +
                                    installed language packs + current language
    wait-win <sel> <timeoutSec>     poll (500ms) until a matching window appears
    wait-gone <sel> <timeoutSec>    poll until it disappears
    wait-stable <sel|x y w h> <timeoutSec> [--interval ms]
                                    poll until two consecutive captures hash
                                    identical (UI settled - replaces fixed sleeps);
                                    [--changed] is the reverse direction (until the
                                    hash DIFFERS), and assert-stable / assert-changed
                                    are the exit-code pair of the same two reads

  occlusion (v1.5.1): every pixel-reading command samples a 5x5 hit-test grid
          (WindowFromPoint + root window - NOT rectangle overlap, so
          click-through full-screen overlays like the NVIDIA overlay or
          Program Manager never count as coverers). A covered target prints
          scan=<read|guard|assert|hit> rect=(x,y,WxH)
          occluded=N% coveredBy=pid 'title' (k of N points) (+K more) plus a
          stderr WARNING naming EVERY coverer on its own line (v1.5.4: nothing
          past the third is dropped any more). The scan/rect labels matter: one
          command can legitimately scan several rectangles (landing check = the
          whole target rect, content guard = its sub-region) and two correct
          scans of different rectangles can name different coverers - compare
          the labels before calling that a contradiction. --guard-text/
          --guard-region and assert-* REFUSE when occluded - a guard must
          never read a coverer's text and pass. Reads never fail on occlusion
          (the needle may sit in the visible part); raw regions (no target
          window) report their owners instead. Switches: --occlude
          off|warn|strict overrides the per-command default; --occlude-grid n
          (default 5); --allow-occluded downgrades a strict fail to a warning. 
  process (PID identity and lifecycle; observation is read-only, termination previews)
    proc-list [name-filter]         every process, visible window or not. A background
                                    process is listed too - "not in wins" is an absence
                                    of a window, not of the process. Read-only.
    proc-info <pid>                 one identity: name/path/start time/responding/window/
                                    session/threads/working set, plus every top-level
                                    window the PID owns. Unreadable fields print as
                                    denied/unknown instead of disappearing.
    proc-wait <pid> [--exit] [--window] [--created <iso>] [--timeout s] [--interval ms]
                                    bounded wait (default 20s) bound to the PID and,
                                    with --created, to that process's creation time.
                                    Process exit and window appearance are separate
                                    predicates on purpose. A timeout never escalates
                                    to a kill.
    proc-start [--cwd <dir>] [--wait-window s] <exe> [argv...]
                                    start a local exe with structured argv (each
                                    operand quoted here - no shell string, no
                                    elevation, no restart). Prints pid + creation
                                    time; --wait-window polls for a top-level window
                                    and reports a timeout as such (the started
                                    process is NOT stopped).
    proc-kill <pid> [--created <iso>] [--timeout s] [--go]
                                    PREVIEW by default. --go additionally requires
                                    --created (the start time from proc-info) and is
                                    checked again through the very handle that is
                                    terminated, so a reused PID is refused. Never
                                    kills a subtree, never targets a protected
                                    system/session process, this tool, or its own
                                    ancestor chain. A terminate request is not an
                                    exit: success is reported only when the same
                                    process object ends. Unsaved work in the target
                                    can be lost - prefer win-close / dialog-cancel.
  locate / clipboard / surface (read-only)
    tpl-find <templatePng> [--to <sel>] [--region x,y,w,h] [--space screen|window|client]
             [--tolerance n] [--scales 1|1,1.25] [--index n] [--max-ms ms] [--created <iso>]
                                    deterministic template locator: one nearest-neighbour
                                    resample per requested scale (0.5..2.0, at most 3),
                                    integer per-channel tolerance (0..255), a bounded
                                    region (<= 3,000,000 px) and a bounded time budget.
                                    Multi-hit is a REFUSAL unless --index names one -
                                    picking the first would be a guess. It reports
                                    points and NEVER clicks; --space says which origin
                                    the printed coordinates are expressed in.
    clip-info                       clipboard METADATA only: kind, format count and names,
                                    character count, file count, image availability,
                                    and whether this tool can restore it. No text is
                                    printed, no image is decoded, nothing is written.
    wait-cond <sel> [--win] [--gone] [--foreground] [--text <needle>]
                     [--uia <nameSub>] [--state On|Off|Expanded|Collapsed|Selected|NotSelected]
                     [--timeout s] [--interval ms]
                                    ONE bounded wait with exactly ONE predicate, and
                                    three outcomes kept apart: matched, timed out, and
                                    every poll failing to read (a read failure is never
                                    reported as "the condition stayed false").
    capabilities [--json]           the command surface DERIVED from this dispatcher's
                                    own registry: per-command group, private/shared
                                    flags, --json support, plus the entry path + SHA256
                                    and the environment. It recomputes the registry's
                                    total, so a command registered but unreachable is
                                    visible rather than silently missing.
  act (absolute coords)
    move <x> <y>                    move cursor
    hover <x> <y> [--dwell ms]      move and STAY - tooltips need the dwell to
                                    render; pointer popups become screenshotable.
                                    dwell default 800, whole ms, 0..60000
    click <x> <y> [--button left|right|middle|back|forward] [--mods ctrl+shift|ctrl,shift]
                                    [--space screen|window|client] [--created <iso>]
                                    click; optionally --to <sel> activates
    rclick <x> <y> [--mods shift] [--space screen|window|client] [--created <iso>]  + verifies a window first, --guard-text /
    dblclick <x> <y> [--mods ...] [--space screen|window|client] [--created <iso>]  --guard-region x,y,w,h=s asserts context
                                      BEFORE the click (like the text commands).
                                      --mods holds ctrl/shift/alt for the ONE call
                                      only (press -> click -> release); an existing
                                      user-held key is refused, never toggled.
                                      --button covers middle (canvas pan) and the
                                      back/forward side buttons. The Windows key is
                                      refused: OS-reserved combinations are not
                                      synthesised here.
                                      v1.5.0: all pointing commands (move /
                                      hover / click family / find-click) print
                                      hit-window = the window really under the
                                      point, and with --to a point outside the
                                      window's visible rect is REFUSED unless
                                      --allow-outside is passed; v1.5.1: the
                                      hit-window line also carries the target's
                                      labelled (scan=hit) occluded=N% rate;
                                      v4.4.1 (CU-REL-01): relclick walks this
                                      same path, and relclick additionally
                                      refuses when the window under the point
                                      is not the resolved target itself
                                      --space screen|window|client picks the
                                      coordinate space: screen (default,
                                      physical pixels), window (0-based offset
                                      inside the target's visible frame) or
                                      client (0-based offset inside its client
                                      area). window/client need --to and read the
                                      origin at ACTION time, so a move/resize/DPI
                                      change cannot leave a stale point in use; an
                                      offset outside the area is refused, never
                                      clamped or silently sent.
                                      --created <iso> pins the target PROCESS to
                                      its creation time (start= from proc-info),
                                      so a reused PID is refused before any
                                      activation - the handle pin and the process
                                      pin answer different questions.
    drag <x1> <y1> <x2> <y2> [--steps n] [--hold ms] [--button left|middle|right|back|forward] [--mods ctrl+shift] [--space screen|window|client] [--created <iso>] [--to <sel>] [--guard-text <s>]
                                    press, interpolate, release (windows,
                                    sliders, scrollbars); guards like click.
                                    steps default 14 (1..200), hold default 120
                                    (0..10000) - the press time before moving.
                                    --button middle = canvas pan; --mods holds the
                                    modifiers for this one drag only. The cross-call
                                    press-down/press-up pair stays LEFT-button and
                                    modifier-free on purpose: a held key between two
                                    calls is state the user may have to clean up.
    press-down <x> <y> [--max-hold ms] [--to <sel>] [--guard-text <s>] [--force]
                                    v2.0.1 (P-3) MID-STATE: press and LET IT STAY
                                    DOWN so you can look before letting go - the
                                    only safe way to drive a surface that takes its
                                    verdict on release (slider puzzles). Three
                                    watchdogs, because a held button is machine-wide
                                    state: (1) --max-hold (default 15000, 1000..60000)
                                    releases in-process; (2) every later invocation
                                    releases a button it finds down and prints
                                    "released a button left down by a previous run";
                                    (3) the echo says DOWN and names the deadline.
                                    A CLI press-down stays alive until the release
                                    (a script step returns at once - see 'script');
                                    refuses when the button is already down so the
                                    press/release pair stays 1:1
    drag-to <x> <y> [--steps n] [--to <sel>] [--expect-change [x,y,w,h]]
                                    travel WHILE HELD from wherever the cursor is
                                    now. Refuses when nothing is pressed (that is
                                    the one-call 'drag' above), so a missing
                                    press-down cannot read as a successful drag
    press-up <x> <y> [--to <sel>] [--expect-change [x,y,w,h]]
                                    let go at that point - the drop is where the
                                    verdict lands, so --expect-change is honoured
                                    here; refuses when nothing is down (say so,
                                    never report a release that did not happen)
    wheel [amount] [x y] [--unit raw|notches] [--axis vertical|horizontal] [--to <sel>] [--at <sel>]
                                    [--space screen|window|client] [--created <iso>]
                                    [--focus-first] [--expect-change [x,y,w,h]]
                                    [--verify-scroll] [--expect-visible-text <needle>]
                                    [--mods ctrl|shift|alt[+...]]
                                    scroll (raw delta is the default; notches
                                    multiply by 120; vertical + = up / - = down,
                                    horizontal + = right / - = left); no target keeps
                                    the current-cursor path. With --to, x/y or the
                                    current cursor must hit that window; choose one of --to or --at;
                                    --at requires
                                    explicit x/y (the window centre is not a panel).
                                    --focus-first is an explicit real click; the target,
                                    focus and landing are re-read after it. Receipt gives
                                    observed window and SendInput count; that count does
                                    not prove UI effect. --expect-change is optional
                                    (bare = auto, absent = no check, rect = screen pixels)
                                    --verify-scroll reads the target point's ScrollPattern;
                                    if unavailable, only an explicit local rect enables a
                                    pixel-only fallback. --expect-visible-text checks a new
                                    visible UIA name. Polling is bounded; no automatic retry.
                                    --mods presses ctrl/shift/alt for THIS ONE wheel event
                                    and releases them in the same call (the same ownership
                                    as click --mods; a key someone else holds is refused).
                                    What a modified wheel does is the application's
                                    decision: Ctrl+wheel may zoom in one app and pan in
                                    another. A changed scroll position is therefore NOT
                                    accepted as proof of zoom: --verify-scroll is refused
                                    together with --mods, and the receipt says
                                    gesture-scope=application-defined.
    relclick <sel> <dx> <dy>        click inside the window, from a rect
                                    re-read AFTER it is raised: a window that
                                    moved or restored is measured again, and a
                                    point outside it - or one some other
                                    window physically sits under - is refused
                                    (--allow-outside sends anyway and says so)
    find-click <sel|x y w h> <needle...> [--index n] [--aim-line] [--scale a|1|2|tiled]
                                    OCR locates the text and the needle's own
                                    sub-span of the matched line gets clicked
                                    (v1.5.9 P-2; the echo says aim=substring ...);
                                    --aim-line restores the old line-centre aim.
                                    One call instead of find-text -> echo ->
                                    click; honours the 2x retry.
                                    index default 0; hits are OCR LINES in
                                    reading order (top to bottom), so two
                                    occurrences on one line count as one hit
    imgclick <outPath> <ix> <iy> [--to <sel>] [--expect ...] [--dry] [--stale-ok]
                                    reverse-map an image pixel through the
                                    <outPath>.map.txt sidecar (written by win/
                                    rect/zoom) and click the screen point;
                                    --dry prints the mapping only - no manual
                                    ix/scale arithmetic; a win sidecar whose
                                    window moved/resized >2px since capture
                                    FAILS (v1.5.1; --stale-ok maps the OLD
                                    origin anyway)
    unmap <outPath> <ix> <iy> [--stale-ok]
                                    same mapping, print only (no click, no log)
    --expect-change [x,y,w,h]       (v1.5.6, opt-in; click/rclick/dblclick/drag/
                                    find-click/wheel) PROOF OF EFFECT, not a
                                    delivery receipt: hash the region before and
                                    after the action and WARN if it is
                                    pixel-identical. Bare = the --to target's
                                    visible rect, or the virtual screen without
                                    --to (the WARN names which). A WARN here is
                                    NOT proof of failure - the effect may sit
                                    outside the rect, or the action may already
                                    have been satisfied. Default OFF; no effect
                                    on the exit code.
    --always-activate               (v1.5.6 rollback switch) force the pre-v1.5.6
                                    behaviour: every --to re-raises the window
                                    with BringWindowToTop/SetForegroundWindow even
                                    when it is already foreground. Normally NOT
                                    needed - the echo now says activated=yes|no
                                    and only re-raises when the window was not
                                    already in front, because re-raising a window
                                    pushes it above a self-drawn popup that the
                                    previous click had opened.
    --expect <needle> / --expect-gone <needle>  (click/rclick/dblclick/find-click
      [--expect-region x,y,w,h] [--timeout s]    /menu-pick/keys/type/paste/
      [--interval ms] [--no-expect]              paste-file) AFTER the action,
                                    poll OCR until the needle appears/vanishes;
                                    an unmet expectation exits 1 with "clicked
                                    OK but expectation NOT met" (a failed
                                    ACTION stays a different ERROR). Both
                                    verdicts name the patience and polling
                                    interval actually used - "verified in 1.2 s
                                    (patience 6s, polled every 300 ms)" - so a
                                    --timeout that reached the loop is tellable
                                    from one that was silently dropped (v1.5.7).
                                    v3.0.0: a satisfied --expect now ALSO echoes the
                                    evidence the assertion had already read -
                                    at=(x,y,WxH) centre=x,y hits=N via=1x|2x|tiled(N)
                                    polls=K - because proving "it appeared" used to
                                    throw the rect away, forcing a SECOND read to
                                    learn where, and a second read re-resolves <sel>,
                                    re-samples occlusion and is a different fact.
    --expect-any a,b / --expect-any-gone a,b   (v3.0.0) comma-separated needle
                                    LISTS for the same commands: "any of these
                                    appeared" / "all of these are gone". A dialog
                                    whose text follows the UI language, or a claim
                                    that answers one text OR its alternative, are
                                    the shapes this is for. --expect/--expect-gone
                                    may be given together with the lists; then BOTH
                                    conditions must hold (AND), never one for the
                                    other. Empty
                                    items are dropped and a list that ends up empty
                                    is refused - an assertion that cannot fail is
                                    worse than no assertion.
    --expect-handle <hwnd>          (v3.0.0) refuse to act unless the window this
                                    call resolves to IS this handle (0x<hex> from
                                    the hwnd= column of wins/info, or decimal).
                                    Every call re-resolves <sel>, so a same-named
                                    window that appeared since you looked can steal
                                    the send; this pins identity mechanically.
                                    Checked BEFORE activation - a refusal never
                                    leaves the desktop changed by the act of
                                    refusing. Without --to it pins the current
                                    foreground window, which is what would be hit.
    win-move <sel> <x> <y>          place the window (visible top-left at x,y)
    win-resize <sel> <w> <h>        set the VISIBLE size (DWM-border corrected)
    win-max <sel> | win-min <sel> | win-restore <sel> | win-close <sel>
                                    state changes / graceful WM_CLOSE
    dialog-cancel <sel> [--allow-window]
                                    v3.0.0 (B-5): press the CANCEL control of a dialog, or
                                    Escape when its tree exposes no cancel-shaped button,
                                    and PROVE it by the handle being gone (up to 1.5s)
                                    rather than by the press having been delivered. This
                                    command cannot confirm anything: the candidate set is
                                    exactly 'cancel' and its Chinese equivalent (the two
                                    stems are assembled from code points in
                                    Get-DialogCancelStems because this file must stay
                                    ASCII), and the CN word for "close" is deliberately
                                    NOT in it - on several Win11 dialogs Close is the
                                    accepting action.
                                    Refuses a window that is not a dialog shape (class not
                                    #32* and no owner) unless --allow-window says you
                                    inspected it; refuses outright when two buttons match
                                    the same stem. Honours --expect-handle, and never
                                    activates the window (UIA invoke needs no foreground).
    menu-pick <sel> <needle...>     resolve the POPUP menu window, OCR its rows,
          [--index n] [--allow-window]
                                    click the row containing the needle. Refuses
                                    anything that is not a menu window (v1.5.2:
                                    class #32768, or a transient popup shape -
                                    NOT the WS_POPUP style bit, which the desktop
                                    and many app shells carry) because picking a
                                    row from a whole surface would click whatever
                                    contains the text; --allow-window overrides
                                    (Win11 XAML menus may need it). Warns when
                                    several rows match.
    open-and-pick <sel> <opener-x> <opener-y> <needle...> [--region x,y,w,h]
                                    v1.6.0 (A-1): one process clicks the opener
                                    (window-relative), waits a 400ms beat, shoots
                                    the target window (or its --region sub-rect)
                                    and clicks the first line containing the
                                    needle. For self-drawn dropdowns and menus
                                    that menu-pick refuses by design. Supports
                                    the --expect family for the pick verdict;
                                    live-proven behaviour, offline-pinned parsing.

  text   (keystrokes go to the focused window. With --to <sel> the target is
          activated and then VERIFIED via GetForegroundWindow before anything is
          sent; if it did not really come to the foreground the command fails
          with ERROR + exit 1 and no keys are sent. Pass --force to skip the
          guard. The foreground is re-checked AFTER sending too: if another
          process stole it, a WARN is printed and the exit code is 1.)
    focus <sel>                     restore + bring to front, then re-read
                                    the SAME handle: prints fg_ok=True plus
                                    both measured states, and refuses unless
                                    the window really is foreground, not
                                    minimized, visible and on-screen
    type [--to <sel>] <text...> [--verify] [--verify-timeout <sec>] [--log-payload] [--force]
                                    v1.3.0: SendInput + KEYEVENTF_UNICODE -
                                    chars bypass the IME entirely (no candidate
                                    window) and CJK works directly. Payload is
                                    literal; control combos belong to `keys`.
                                    --verify OCR-reads the target window after
                                    sending and fails loudly if the text is not
                                    visible (skip for password fields)
                                    v4.5.5: <text...> is literal text; control
                                    sequences are for `keys`, and a PID belongs
                                    after `--to`, never in the text. `activated=no
                                    (was fg)` means the window was already in
                                    front; it does not mean the send was skipped.
                                    --verify-timeout <sec> how long --verify may
                                    poll before giving up (default 4s, min 0.5s;
                                    raise it for slow-rendering targets)
    type-in <x> <y> [--tab <n>] <text...> [--verify] [--verify-timeout <sec>] [--log-payload]
                                    click a spot, send n TABs (webview forms:
                                    click alone gives no keyboard focus), type
    keys [--to <sel>] <spec> [--log-payload] [--force]
                                    raw SendKeys spec, e.g. ^s  ^a  %{F4}  {ENTER};
                                    use `type` for literal text, not key syntax
                                    (SendKeys still honours the IME - see README)
    key [--to <sel>] <combo> [--repeat n] [--interval ms] [--hold ms] [--guard-text <s>] [--expect <needle>] [--force]
                                    NATIVE key gesture (SendInput), separate from
                                    keys: combo = ctrl/shift/alt/win + one base key,
                                    e.g. 'key ctrl+shift+t', 'key alt+f4',
                                    'key f5 --repeat 3', 'key enter --hold 800'.
                                    Base names: a-z 0-9 F1..F24 numpad0..9 enter tab
                                    esc space backspace delete insert home end
                                    pageup pagedown left up right down capslock
                                    numlock scrolllock printscreen pause apps
                                    minus equal comma period slash semicolon quote
                                    backslash grave add subtract multiply divide
                                    decimal. --repeat 1..50, --interval 0..5000,
                                    --hold 0..20000 (one bounded hold of the BASE
                                    key). Every key is released inside this call;
                                    a modifier someone else already holds is
                                    REFUSED, never pressed or released. Refused by
                                    design: Ctrl+Alt+Del (the Secure Attention
                                    Sequence belongs to the OS) and Win+l/d/u/r
                                    (they act on the whole session, not a window).
                                    Chinese body text still goes through `type`
                                    (Unicode SendInput), never through a keystroke
                                    table or the clipboard.
    key-state                       READ-ONLY: which modifiers/lock keys and
                                    mouse buttons are down right now, plus what
                                    this tool has on record as held. Nothing is
                                    pressed or released.
    key-release [--go]              release ONLY keys this tool recorded as held
                                    (the ledger an interrupted call leaves behind).
                                    DRY RUN by default; keys held by anyone else
                                    are reported, never touched. 'Release all
                                    physical keys' is deliberately not a mode:
                                    an unknown holder is reported, not reset.
    paste [--to <sel>] <file> [--expect <s>|--no-expect] [--replace-clipboard] [--force]
                                    read UTF-8 file, put on clipboard, Ctrl+V;
                                    previous clipboard (text, FileDrop or image) is
                                    saved and restored afterwards. CU-OPS G: when
                                    the clipboard holds formats this tool cannot
                                    put back (custom data), the write is REFUSED
                                    unless --replace-clipboard says losing it is
                                    intended. v1.5.9: with
                                    NO expect flag given, the payload tail (last
                                    non-empty line, <= 24 chars) is OCR-read back
                                    from the target - not visible = WARN + exit 1
                                    (--no-expect = send-only escape). v2.2.0: a
                                    payload of >= fold-threshold chars that folds
                                    into an attachment chip can never show that
                                    tail, so it is then accepted on a receipt
                                    (new UIA node / window grew / line count +
                                    hash changed), and the receipt used is named
                                    in the echo - never silently;
                                    --expect/--expect-gone/--expect-region/
                                    --timeout/--interval all work here too (see
                                    the shared paragraph below)
    --guard-text <needle> / --guard-region x,y,w,h=<needle>
                                    (type/keys/paste/paste-file) AFTER the window
                                    guard passes, OCR the target window or a
                                    window-relative sub-region and send only if
                                    the needle is visible - the tool enforces
                                    "only talk to this conversation". v1.5.1:
                                    an OCCLUDED guard region FAILS before the
                                    OCR (nothing is sent) - the guard must not
                                    read a coverer's text and call it context

  clipboard
    copy-file <path>                put a local file on the clipboard as FileDrop,
                                    self-verified; deliberately keeps it there
    paste-file [--to <sel>] <path> [--guard-text <s>] [--expect <s>|--no-expect] [--replace-clipboard] [--force]
                                    copy-file + foreground guard + content guard
                                    + Ctrl+V, then restore the previous clipboard;
                                    CU-OPS G: unknown clipboard formats are refused
                                    before the write unless --replace-clipboard is
                                    given; v1.5.9: default-on readback like paste (it
                                    looks for the FILE NAME; --no-expect is the
                                    send-only escape; --expect family honoured)

  chrome / page content (v1.8.0)
    chrome-a11y <on|off>           THE page route for your DEFAULT profile: relaunch
                                    Chrome with --force-renderer-accessibility so the
                                    page DOM reaches the UIA tree, then uia-find /
                                    uia-click / read-text work on web content.
                                    Measures the page-area tree before and after and
                                    refuses to claim success. Chrome >=136 prints
                                    "DevTools remote debugging requires a non-default
                                    data directory" and refuses the debug port on the
                                    default profile - measured, not folklore.
    chrome-menu-read                UIA: open Chrome's OWN app menu, list every
                                    MenuItem Name it exposes, then dismiss it (Escape)
                                    WITHOUT clicking anything. This is how option B -
                                    exiting through the browser's own menu, owner
                                    ruling 2026-09-30 22:0x - gets evidence on a
                                    browser that is still in use. NOT read-only (it
                                    opens a menu) and it exits 1 when exactly one exit
                                    item cannot be picked by literal Name. No blind
                                    accelerators, no guessed coordinates: the menu
                                    button must match Name exactly, and items are
                                    clicked on the rectangle read from the item.
    chrome-tabs [--json]            cdp: enumerate open tabs (id/title/HOST+PORT only
                                    - a token can sit in the path as happily as in the
                                    query, so neither is ever printed)
    chrome-read <sel>               cdp: visible text of the matching tab's page
    chrome-find <sel> <text...>     cdp: innermost element containing the text ->
                                    physical screen rect + centre (scale is
                                    measured per call, A-3 reconciles vs OCR)
    chrome-click <sel> <text...> [-dry]
                                    cdp: chrome-find, then the regular injected
                                    click on its centre (guards apply; DOM
                                    synthetic clicks are deliberately not used)
    chrome-debug-off                cdp: graceful close + relaunch WITHOUT the debug
                                    flag + verifies /json/version stops answering

  ui automation (works only if the app exposes its a11y tree; roots are resolved
                 from the SELECTED window handle, not just the first pid window)
    uia-tree <sel> [maxDepth] [--path </0/1/...>] [--dump <file>]
                                    dump control tree (header shows scanned hwnd
                                    and the depth actually walked: depth=N).
                                    v4.2.0: the whole tree to a UTF-8 file is
                                    `--dump <file>` (global flag, v3.0.0; uia-tree
                                    is in its accepted set) - NOT --out, which
                                    powershell -File swallows at its own parameter
                                    layer (AmbiguousParameter on -OutVariable).
                                    --path <token> keeps only the ancestor chain
                                    + that subtree (siblings dropped), raises
                                    [maxDepth] when the token sits deeper and says
                                    so, and fails loudly when the token matches
                                    nothing - "one reply, whole, in one call".
                                    v2.4.0: lines gain path=/0/2/1 (child-index
                                    route from the root, --no-paths off) and, for
                                    interactive-type nodes, actions=[invoke,...]
                                    (invoke|toggle|select|expand|value|scroll|range).
                                    Pattern probing is allowlisted by default
                                    (each probe is a cross-process call);
                                    --actions-all probes every node, --no-actions
                                    turns probing off and keeps stdout byte-
                                    identical to the previous release. The cost
                                    self-reports on STDERR:
                                    actions-probed=K of M nodes (allowlist|all)
                                    elapsed=Xms. actions= appears only on probed
                                    nodes, so "not probed" and "probed but none"
                                    stay distinguishable
    uia-path <sel> @/0/2/1 [maxDepth]
                                    READ-ONLY: resolve a path taken from a
                                    uia-tree line and print that node's line
                                    (same fields) - the handle for controls
                                    that have no Name
    uia-find <sel> <nameSub> [typeRe]
                                    <nameSub> must not be empty: an empty substring
                                    matches EVERY element, so a hit would prove nothing
                                    v2.1.0: a first contact with 0 hits on a shallow tree
                                    is the COLD-START shape (the UIA connection is what
                                    lights a Chromium tree, and it lights after the walk
                                    that triggered it is over), so the reader re-contacts
                                    ONCE before 0 becomes a verdict. The echo carries
                                    walks= / walk-depth= / reprobe-floor= /
                                    cold-zero-reprobe= (the floor is measured and
                                    reported, never assumed; walk-depth says the bound
                                    the walk really ran - 0 means unlimited, printed
                                    as such). A
                                    re-contact that still finds nothing prints a NOTE
                                    saying UIA genuinely has no such Name AND pointing at
                                    the OCR road - zero is never evidence of absence.
    uia-click <sel> <nameSub>       InvokePattern, falls back to clicking its centre.
                                    @path form: uia-click <sel> @/0/2/1 "T|n|X,Y,WxH"
                                    walks the route, re-verifies ControlType/Name/rect
                                    against the expected token copied from the
                                    uia-tree line, and REFUSES with exit 1 on any
                                    mismatch or a path deeper than maxDepth - a
                                    stale path never becomes a silent click
    uia-focus <sel> <nameSub>       SetFocus. @path form like uia-click:
                                    uia-focus <sel> @/0/2/1 "T|n|X,Y,WxH"
    uia-settext <sel> <nameSub> <file>
                                    ValuePattern.SetValue from a UTF-8 file,
                                    readback-verified (no keyboard, no clipboard).
                                    @path form: uia-settext <sel> @/0/2/1 <file>
                                    "T|n|X,Y,WxH"
    uia-state <sel> <nameSub> [--text]
                                    READ-ONLY: one line per UIA pattern this
                                    element exposes right now - toggle / selection /
                                    expand / range (value,min,max,readonly) /
                                    value (length + writable) / text / scrollItem -
                                    and an explicit "no XPattern" when absent.
                                    Values and text are NOT printed unless --text
                                    is passed, and a password field is never read.
                                    Nothing is activated and nothing is logged.
    uia-do <action> <sel> <nameSub> [value]
                                    semantic action through ONE named pattern,
                                    then a read-back of the resulting state:
                                    toggle|toggle-on|toggle-off (TogglePattern),
                                    select|add-select|remove-select
                                    (SelectionItemPattern; add/remove are the
                                    multi-select calls, since Select on a second
                                    item replaces the selection), expand|collapse
                                    (ExpandCollapsePattern), scroll-into-view
                                    (ScrollItemPattern, verified by IsOffscreen
                                    going true -> false), range-set
                                    (RangeValuePattern, refused when readonly or
                                    outside min..max - no
                                    clamping). A disabled element, a missing
                                    pattern, a stale element or a failed
                                    read-back is an error that changed
                                    nothing; there is no fallback click.
                                    uia-do logs one audit line; uia-state does not.
    a11y-probe <sel> [bigDepth]     READ-ONLY: control counts at default vs big
                                    depth + interactive controls in the page
                                    area -> page-tree=exposed|collapsed, i.e.
                                    whether uia-* can drive this app's content
                                    or CDP/flag-relaunch/OCR is needed (the
                                    chrome group used to repeat this entry under
                                    its own heading - it points here now).
                                    bigDepth really limits the walk: the same
                                    selector at 3 vs 40 must count different
                                    nodes
    challenge-probe <sel> [--allow-attempt
                      --attempt-click x,y]
                                    READ-ONLY by default: whole-window OCR,
                                    match the verification-challenge corpus ->
                                    type/confidence/staleness + the human
                                    handoff block (type=/rect=/handle:/shot:).
                                    An unchanged challenge image across calls
                                    reads stale=yes (expired ticket: dismiss
                                    it, do NOT solve it). --allow-attempt
                                    permits exactly ONE caller-named click;
                                    if the challenge survives it, a fuse is
                                    recorded and later attempts on the same
                                    image are refused. There is NO solver by
                                    design - these challenges exist to stop
                                    scripted claiming, and breaking them
                                    escalates account risk-control.

  batch
    (2 or more fixed steps: batch them here - one process, not one per step)
    script <steps.json> [--dry-run] [--stop-on-error] [--shot-at n]
                                    run a JSON array of steps in one process:
                                    per-step "to" = hard foreground guard (a
                                    guard failure aborts everything), asserts as
                                    checkpoints, retry/intervalMs per step,
                                    guard-text/guard-region content guards.
                                    require-popup <sel> arms a popup survival
                                    guard (baseline pid+hwnd+class+rect, then
                                    every later step is re-checked BEFORE it
                                    runs; a vanished/buried/moved popup aborts
                                    the REST of the script with measured
                                    values); release-popup disarms, and a
                                    win-close that closed the guarded popup
                                    disarms with a notice.
                                    "must-be-foreground": true opts the guard
                                    into the foreground leg; DEFAULT OFF (owner
                                    ruling 2026-10-01: keep it off). Why: a
                                    popup that a sibling window of the same
                                    pid happens to cover is still the popup you
                                    are working on and still clickable, so a
                                    default-on leg would abort honest scripts
                                    on a state that is not a failure - the
                                    other three legs already catch "gone",
                                    "buried in z-order" and "moved by more
                                    than the tolerance". Turn it on only where
                                    the popup MUST keep the keyboard.
                                    v2.0.1 (P-3): press-down / drag-to / press-up
                                    are script steps too - hold the button while
                                    later steps look, then let go.
                                    Non-guard failures are reported and (by
                                    default) execution continues; exit 1 if any
                                    step failed. See README for the step schema.
    replay [<actions.log>] [--last n] [--grep s] [--go]
                                    re-run recorded act/text/clipboard commands;
                                    DRY RUN by default, --go executes. Unknown
                                    --flags throw (there is no --from). Steps
                                    whose payload was redacted at log time
                                    (<redacted:Nchars>) are REFUSED and counted as
                                    failures - v1.4.1 redaction means the log no
                                    longer holds the typed text, and replaying the
                                    placeholder would type it into the target.
                                    A log slice carrying a popup-guard abort
                                    marker is refused outright (half-executed
                                    state must not be replayed).
    shots-cleanup [--keep n] [--go] [--quarantine <dir>]
                                    bound the runtime screenshot folder (it grows
                                    without limit - 100MB/213 files in 3 days was
                                    measured). DRY RUN by default: lists what
                                    would go. --go MOVES the files into the
                                    machine's quarantine folder and appends
                                    MANIFEST.md with original path + SHA256 +
                                    size + times, so nothing is ever deleted and
                                    every move can be undone. A .map.txt sidecar
                                    always travels with its own image. Newest n
                                    images stay (default 100). The --go target, in
                                    order: --quarantine <dir>, then DTX_QUARANTINE
                                    from the process environment, then DTX_QUARANTINE
                                    from the User-scope registry, then Machine-scope,
                                    else the command refuses (exit 2) naming both
                                    remedies - no baked-in machine path (v2.5.2/v2.5.3).
                                    SINCE v2.6.0 THIS ALSO RUNS BY ITSELF: every
                                    capture (shot / zoom / imgclick / chrome-* /
                                    challenge-probe) trims the folder to the newest
                                    100 images right after writing its own file, so
                                    nobody has to remember this command. Same rules as
                                    --go - MOVE, never delete, one MANIFEST line per
                                    file with its SHA256, sidecars travel with their
                                    image. It says nothing when there is nothing over
                                    the bound, and it prints 'auto-trim: moved N ...'
                                    when it acts. It skips itself during selftest (a
                                    live run's own fixtures must not move) and when no
                                    quarantine is configured - then it prints why.
                                    Knobs: DTX_SHOT_KEEP=<n> changes the bound,
                                    DTX_SHOT_AUTOTRIM=0|off|false|no stops the automatic
                                    pass (the command still works by hand). Both are
                                    read from the process environment, so a host that
                                    was already running when you set them needs a
                                    restart - and the default is ON, so a setting that
                                    did not land keeps trimming rather than stopping.

    help [<cmd>|--<flag>]           this page with no argument; ONE command's entry as
                                    'help shot'; every line that mentions a flag as
                                    'help --grid'. An unknown name is refused WITH
                                    candidates, never a shrug (v1.5.7).

  global flags
    --needle <text>                 explicit needle for every command that
                                    searches text (find-text/read-text/
                                    assert-text/find-click/menu-pick, and the
                                    --to family). v1.5.2: an
                                    unknown --xxx flag in a needle command is a hard
                                    ERROR instead of being silently searched as text.
                                    This is ALSO the only way to search a literal
                                    that starts with -- (e.g. '--fit'): a lone --
                                    terminator is NOT supported - powershell.exe
                                    consumes it at its own parameter-binding layer
                                    before this script runs, so the error you would
                                    see comes from PowerShell, not from this tool.
                                    Inside script steps use the JSON field; no shell
                                    quoting is involved there.
    --json                          machine-readable output where supported
                                    (wins/info/rect-of/color-at/find-color/
                                    find-text/read-text/hash/wait-stable/
                                    ime-state/ocr-cap and the script summary)
    --ocr-lang <tag>                pin the OCR recognizer language; validated
                                    against the installed packs (an unavailable
                                    tag errors with the available list)
    --dump <path>                   v3.0.0 (B-4): write the command's stdout to a file
                                    and print a pointer instead (line count, bytes,
                                    the first 5 lines and the hidden-line count).
                                    Accepted only by the commands that can outgrow the
                                    caller's context: find find-text read-text
                                    uia-find uia-path uia-tree wins. Every other
                                    command is refused BEFORE it runs - a flag that is
                                    silently ignored is the D-1 defect this repo has
                                    been closing since v1.5.5. Refuses an existing path
                                    (it never overwrites) and a missing parent (it never
                                    creates directories). stderr is not captured, so
                                    cost self-reports still reach the terminal.
    --min-line-density <n>          v1.5.9 (P-4) knob; v2.9.0 gave the two read shapes
                                    DIFFERENT VOICES, so the default depends on the
                                    command you pass it to:
                                      read-text  - always prints readability=<n> lines
                                                   per 100k px2 in its header (that is
                                                   a measurement, it never shouts) and
                                                   WARNs only below 0.1;
                                      find-text / assert-text / the --expect family /
                                      challenge-probe - keep the 1.0 (region < 500k px2)
                                                   and 1.5 (>= 300k px2) bands, because
                                                   on those exits the warning IS part of
                                                   the negative conclusion.
                                    0 = off. Hint only: never changes an exit code.
                                    Passing this flag overrides the default above.
  <sel> = numeric pid | title substring | proc:<name> | class:<substr> | hwnd:<0xhex|decimal>
          | t:<digits> to force title matching for digit-only strings.
          hwnd: matches ONE top-level window by exact handle (from the hwnd=
          column of wins/info); a non-numeric value is refused, and a handle
          that no longer exists reports "no window matching" - it never falls
          back to a title that looks similar.
          Numeric <sel> prefers the pid's window currently in the foreground
          (pick=fg), else the largest (pick=largest). A MINIMIZED window of that
          pid is picked the same way but labelled pick=parked, and assert-window
          echoes iconic=True beside it - a parked rect reads (-31991,-32000),
          which no click can land on. When a title/proc/class
          selector matches SEVERAL windows, resolution refuses and prints every
          candidate - use pid / proc: / class: to disambiguate.
  --json anywhere = machine-readable output for wins/info/rect-of/color-at/
          find-color/find-text/read-text/hash/wait-stable/ime-state/script.
  selftest [--live] [--timing] [--index] [--only <pat>] = mechanical regression checks (source lint for the PS 5.1
          "@(Fn)" list-return trap, BOM/ASCII invariants, unit checks of every
          pure helper, and with --live a real OCR round-trip). Non-zero exit on
          any FAIL. Run it after touching helpers that "return ,$list".
  every executed act/text/clipboard/uia-settext command appends one audit line
          to shots\actions.log: paths, coordinates and targets verbatim; typed
          payloads (type/type-in/keys) and --guard-text/--guard-region needles
          are stored as <redacted:Nchars> - pass --log-payload to record them
          verbatim (audit v1.4.1). The log rotates at 512KB, keeping the 5
          newest actions_*.log archives. Screenshot defaults are timestamped
          (shot_<ts>.png, ...), pass an outPath to choose your own
  exit code 0 = ok, 1 = error
'@
}

. (Join-Path $PSScriptRoot 'lib/help.ps1') # <<< stitch: lib/help.ps1
function Invoke-DesktopCommand([string]$Cmd, [string[]]$Rest) {
  Test-IntArgs $Cmd $Rest | Out-Null
  switch ($Cmd) {

    'help' {
      Invoke-Handler-help 'help' $Rest
    }

    'selftest' { Invoke-SelfTest $Rest }

    'status-summary' {
      Invoke-Handler-status-summary 'status-summary' $Rest
    }

    'shot' {
      Invoke-Handler-shot 'shot' $Rest
    }

    'win' {
      Invoke-Handler-win 'win' $Rest
    }

    'rect' {
      Invoke-Handler-rect 'rect' $Rest
    }

    'wins' {
      Invoke-Handler-wins 'wins' $Rest
    }

    'info' {
      Invoke-Handler-info 'info' $Rest
    }

    'rect-of' {
      Invoke-Handler-rect-of 'rect-of' $Rest
    }

    'cursor' {
      Invoke-Handler-cursor 'cursor' $Rest
    }

    'dpi' {
      Invoke-Handler-dpi 'dpi' $Rest
    }

    'ime' {
      Invoke-Handler-ime 'ime' $Rest
    }

    'ime-state' {
      Invoke-Handler-ime-state 'ime-state' $Rest
    }

    'ocr-cap' {
      Invoke-Handler-ocr-cap 'ocr-cap' $Rest
    }

    'challenge-probe' {
      Invoke-Handler-challenge-probe 'challenge-probe' $Rest
    }

    'ime-en' {
      Invoke-Handler-ime-en 'ime-en' $Rest
    }

    'ime-cn' {
      Invoke-Handler-ime-cn 'ime-cn' $Rest
    }

    'zoom' {
      Invoke-Handler-zoom 'zoom' $Rest
    }

    'wait-win' {
      Invoke-Handler-wait-win 'wait-win' $Rest
    }

    'wait-gone' {
      Invoke-Handler-wait-gone 'wait-gone' $Rest
    }

    'find' {
      Invoke-Handler-find 'find' $Rest
    }

    'find-text' {
      Invoke-Handler-find-text 'find-text' $Rest
    }

    'read-text' {
      Invoke-Handler-read-text 'read-text' $Rest
    }

    'color-at' {
      Invoke-Handler-color-at 'color-at' $Rest
    }

    'find-color' {
      Invoke-Handler-find-color 'find-color' $Rest
    }

    'hash' {
      Invoke-Handler-hash 'hash' $Rest
    }

    'wait-stable' {
      Invoke-Handler-wait-stable 'wait-stable' $Rest
    }

    'assert-changed' {
      Invoke-Handler-assert-changed 'assert-changed' $Rest
    }

    'assert-window' {
      Invoke-Handler-assert-window 'assert-window' $Rest
    }

    'assert-text' {
      Invoke-Handler-assert-text 'assert-text' $Rest
    }

    'assert-color' {
      Invoke-Handler-assert-color 'assert-color' $Rest
    }

    'assert-hash' {
      Invoke-Handler-assert-hash 'assert-hash' $Rest
    }

    'assert-stable' {
      Invoke-Handler-assert-stable 'assert-stable' $Rest
    }

    'move' {
      Invoke-Handler-move 'move' $Rest
    }

    'hover' {
      Invoke-Handler-hover 'hover' $Rest
    }

    'click' {
      Invoke-Handler-click 'click' $Rest
    }

    'rclick' {
      Invoke-Handler-rclick 'rclick' $Rest
    }

    'dblclick' {
      Invoke-Handler-dblclick 'dblclick' $Rest
    }

    'wheel' {
      Invoke-Handler-wheel 'wheel' $Rest
    }

    'relclick' {
      Invoke-Handler-relclick 'relclick' $Rest
    }

    'drag' {
      Invoke-Handler-drag 'drag' $Rest
    }

    'press-down' {
      Invoke-Handler-press-down 'press-down' $Rest
    }

    'drag-to' {
      Invoke-Handler-drag-to 'drag-to' $Rest
    }

    'press-up' {
      Invoke-Handler-press-up 'press-up' $Rest
    }

    'win-move' {
      Invoke-Handler-win-move 'win-move' $Rest
    }

    'win-resize' {
      Invoke-Handler-win-resize 'win-resize' $Rest
    }

    'win-max' {
      Invoke-Handler-win-max 'win-max' $Rest
    }

    'win-min' {
      Invoke-Handler-win-min 'win-min' $Rest
    }

    'win-restore' {
      Invoke-Handler-win-restore 'win-restore' $Rest
    }

    'win-close' {
      Invoke-Handler-win-close 'win-close' $Rest
    }

    'dialog-cancel' {
      Invoke-Handler-dialog-cancel 'dialog-cancel' $Rest
    }

    'menu-pick' {
      Invoke-Handler-menu-pick 'menu-pick' $Rest
    }

    'find-click' {
      Invoke-Handler-find-click 'find-click' $Rest
    }

    'open-and-pick' {
      Invoke-Handler-open-and-pick 'open-and-pick' $Rest
    }

    # CU-OPS package A: observation (read file) and the two act-side commands. proc-kill
    # previews unless --go, and is deliberately absent from the replay whitelist.
    'proc-list' {
      Invoke-Handler-proc-list 'proc-list' $Rest
    }

    'proc-info' {
      Invoke-Handler-proc-info 'proc-info' $Rest
    }

    'proc-wait' {
      Invoke-Handler-proc-wait 'proc-wait' $Rest
    }

    'proc-start' {
      Invoke-Handler-proc-start 'proc-start' $Rest
    }

    'proc-kill' {
      Invoke-Handler-proc-kill 'proc-kill' $Rest
    }

    'imgclick' {
      Invoke-Handler-imgclick 'imgclick' $Rest
    }

    'unmap' {
      Invoke-Handler-unmap 'unmap' $Rest
    }

    'chrome-tabs' {
      Invoke-Handler-chrome-tabs 'chrome-tabs' $Rest
    }

    'chrome-read' {
      Invoke-Handler-chrome-read 'chrome-read' $Rest
    }

    'chrome-find' {
      Invoke-Handler-chrome-find 'chrome-find' $Rest
    }

    'chrome-click' {
      $a15SkipTail = $false
      Invoke-Handler-chrome-click 'chrome-click' $Rest ([ref]$a15SkipTail)
      if ($a15SkipTail) { return }
    }

    'chrome-menu-read' {
      Invoke-Handler-chrome-menu-read 'chrome-menu-read' $Rest
    }

    'chrome-debug-off' {
      Invoke-Handler-chrome-debug-off 'chrome-debug-off' $Rest
    }

    'chrome-a11y' {
      Invoke-Handler-chrome-a11y 'chrome-a11y' $Rest
    }

    'focus' {
      Invoke-Handler-focus 'focus' $Rest
    }

    'type' {
      Invoke-Handler-type 'type' $Rest
    }

    'type-in' {
      Invoke-Handler-type-in 'type-in' $Rest
    }

    'keys' {
      Invoke-Handler-keys 'keys' $Rest
    }

    # CU-OPS package C: native key gestures. `keys` above keeps its SendKeys grammar
    # untouched; these three are a separate, explicitly native surface.
    'key' {
      Invoke-Handler-key 'key' $Rest
    }

    'key-state' {
      Invoke-Handler-key-state 'key-state' $Rest
    }

    'key-release' {
      Invoke-Handler-key-release 'key-release' $Rest
    }

    'uia-state' {
      Invoke-Handler-uia-state 'uia-state' $Rest
    }

    'uia-do' {
      Invoke-Handler-uia-do 'uia-do' $Rest
    }

    # CU-OPS packages D/F/H: read-only additions. tpl-find locates and never clicks,
    # clip-info reports clipboard metadata without printing content, wait-cond is one
    # bounded wait with matched/timed-out/unreadable kept apart, and capabilities derives
    # the command surface from this dispatcher's registry.
    'tpl-find' {
      Invoke-Handler-tpl-find 'tpl-find' $Rest
    }

    'clip-info' {
      Invoke-Handler-clip-info 'clip-info' $Rest
    }

    'wait-cond' {
      Invoke-Handler-wait-cond 'wait-cond' $Rest
    }

    'capabilities' {
      Invoke-Handler-capabilities 'capabilities' $Rest
    }

    'paste' {
      Invoke-Handler-paste 'paste' $Rest
    }

    'copy-file' {
      Invoke-Handler-copy-file 'copy-file' $Rest
    }

    'paste-file' {
      Invoke-Handler-paste-file 'paste-file' $Rest
    }

    'uia-tree' {
      Invoke-Handler-uia-tree 'uia-tree' $Rest
    }

    'uia-path' {
      Invoke-Handler-uia-path 'uia-path' $Rest
    }

    'uia-find' {
      Invoke-Handler-uia-find 'uia-find' $Rest
    }

    'uia-click' {
      $a15SkipTail = $false
      Invoke-Handler-uia-click 'uia-click' $Rest ([ref]$a15SkipTail)
      if ($a15SkipTail) { return }
    }

    'uia-focus' {
      $a15SkipTail = $false
      Invoke-Handler-uia-focus 'uia-focus' $Rest ([ref]$a15SkipTail)
      if ($a15SkipTail) { return }
    }

    'uia-settext' {
      $a15SkipTail = $false
      Invoke-Handler-uia-settext 'uia-settext' $Rest ([ref]$a15SkipTail)
      if ($a15SkipTail) { return }
    }

    'a11y-probe' {
      Invoke-Handler-a11y-probe 'a11y-probe' $Rest
    }

    'script' { Invoke-ScriptBatch $Rest $Cmd }

    'replay' { Invoke-ReplayLog $Rest }

    'shots-cleanup' {
      Invoke-Handler-shots-cleanup 'shots-cleanup' $Rest
    }

    default { throw "unknown command: $Cmd (run 'desktop.ps1 help')" }
  }
  # v2.6.0: bound the capture folder after EVERY command, not just the ones that go
  # through Save-RectEx - the first version of this hook sat in Save-RectEx and a real
  # `zoom` proved it missed: zoom builds its own bitmap and saves it directly. Putting it
  # here means no current or future command can produce a file the trim never sees, and
  # there is exactly one call site to keep honest (a lint pins it).
  $trimNote = Trim-ShotDir $OutDir 'after-command' -CmdName $Cmd
  if ($trimNote) {
    # v4.3.3 (G-08, owner ruling 2026-10-16): on the --json road the success stream carries the JSON
    # envelope and nothing else. This sentence is a diagnostic about the capture folder - it is not a
    # field of any command's envelope - so there it goes to the error stream. Without the --json flag
    # the human reading is unchanged: the note still sits right after the output it describes. The move
    # itself, the manifest and the audit line are untouched; only WHICH STREAM the sentence uses.
    if ($script:Json) {
      [Console]::Error.WriteLine([string]$trimNote.Note)
      foreach ($ft in @($trimNote.Failures)) { [Console]::Error.WriteLine([string]$ft) }
    } else {
      "$($trimNote.Note)"; foreach ($ft in @($trimNote.Failures)) { "$ft" }
    }
  }
  # v1.5.7 (D-7) safety net: 22 commands resolve a window and only 9 used to print the
  # note channel, so `focus <pid>` landing on a promo popup printed nothing about it -
  # the exact thing D-7 reported. Every case that already calls Emit-ResolveNote clears
  # the state, so this fires ONLY for the commands that forgot; the note then lands after
  # that command's own echo, which is late but visible, and new commands cannot be silent.
  Emit-ResolveNote
}

# Batch runner, extracted verbatim from the old 'script' case (audit
# 2026-09-29 #11: the two largest inline cases became named handlers so the
# dispatch switch stays a dispatch). No direct Log-Action here - steps log
# through their own commands, so audit semantics are unchanged.
function Invoke-ScriptBatch([string[]]$Rest, [string]$Cmd) {
      # script <steps.json> [--dry-run] [--stop-on-error] [--shot-at <n>] [--json]
      # Runs a JSON array of steps in ONE process launch, with a foreground
      # guard between steps and assert checkpoints - the replacement for
      # "action -> read echo -> screenshot -> next action" call cycles.
      # Guard semantics (the safety valve):
      #   - a step's "to" field activates + verifies that window first; failure
      #     ABORTS the whole script immediately, whatever the flags say;
      #   - guard-text/guard-region content checks abort the same way;
      #   - other step failures are recorded and (by default) execution
      #     CONTINUES so one echo shows where every step landed; pass
      #     --stop-on-error to fail fast instead. Exit 1 if anything failed.
      # Step modifiers: "to" (hard foreground guard), "guard-text" /
      # "guard-region" (content guard, OCR), "retry" n + "intervalMs" (re-run
      # the step on failure), "desc" (free text echoed in the step line).
      # Actions:
      #   click|rclick|dblclick|move [x,y]     drag [x1,y1,x2,y2]
      #   relclick [sel,dx,dy]                 wheel n | {amount,at}
      #   focus sel                            type "text" | keys "spec"
      #   paste "file" | paste-file "file"     sleep <ms>
      #   shot "name" | {region:[x,y,w,h], out:"name"}
      #   wait-win [sel,sec] | wait-gone [sel,sec]
      #   wait-stable {sel|region,timeout}     menu-pick [sel,"text"]
      #   win-max|win-min|win-restore|win-close sel
      #   win-move [sel,x,y] | win-resize [sel,w,h]
      #   assert-window "sel"  assert-text {sel|region,needle}
      #   assert-color {at:[x,y],hex,tolerance}  assert-hash {region,op,hash}
      #   assert-stable {sel|region,timeout}
      $file = $null; $dry = $false; $stopOnError = $false; $shotAt = -1
      $tok = @($Rest)
      for ($ti = 0; $ti -lt $tok.Count; $ti++) {
        $t = "$($tok[$ti])"
        if ($t -eq '--dry-run' -or $t -eq '--dry') { $dry = $true }
        elseif ($t -eq '--stop-on-error') { $stopOnError = $true }
        elseif ($t -match '^--shot-at=(\d+)$') { $shotAt = [int]$Matches[1] }
        elseif ($t -eq '--shot-at') {
          # v1.5.2 (audit R-07): the space form is what README, help and this
          # command's own error message all document - accepting only --shot-at=n
          # meant the advice in the error text could not be followed. Both work now.
          $ti++
          if ($ti -ge $tok.Count) { throw 'script: --shot-at needs a step number' }
          if ("$($tok[$ti])" -notmatch '^\d+$') { throw "script: --shot-at needs a number, got: $($tok[$ti])" }
          $shotAt = [int]$tok[$ti]
        }
        elseif ($t -like '--*') {
          # A mistyped safety flag must never degrade into "run it for real":
          # `--dry` used to fall through and be treated as nothing, so the
          # supposed dry run executed every step.
          throw "script: unknown flag '$t' (valid: --dry-run | --stop-on-error | --shot-at <n>)"
        }
        elseif ($null -eq $file) { $file = $t }
      }
      if (-not $file) { throw 'usage: script <steps.json> [--dry-run] [--stop-on-error] [--shot-at <n>]' }
      if (-not (Test-Path $file)) { throw "file not found: $file" }
      # Assign BEFORE wrapping: ConvertFrom-Json emits a JSON array as ONE
      # Object[] on the pipeline, so @(expr | ConvertFrom-Json) yields
      # Object[1]{Object[]} - count 1, and every step then looks like an array
      # (its "action names" come out as Count/Length/Rank/...). Same family of
      # trap as the @()-around-comma-return lint; pinned by selftest.
      $rawSteps = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
      $steps = @($rawSteps)
      if ($steps.Count -eq 0) { throw 'script: steps file contains no steps' }
      $known = @('click','rclick','dblclick','move','hover','drag','press-down','drag-to','press-up','relclick','wheel','focus','type','keys','paste','paste-file','sleep','shot','wait-win','wait-gone','wait-stable','menu-pick','find-click','open-and-pick','win-move','win-resize','win-max','win-min','win-restore','win-close','dialog-cancel','assert-window','assert-text','assert-color','assert-hash','assert-stable','require-popup','release-popup')
      foreach ($s in $steps) {
        $keys = @($s.PSObject.Properties.Name | Where-Object { $_ -in $known })
        if ($keys.Count -eq 0) {
          throw "script: step has no known action (known: $($known -join ' ')); got: $($s.PSObject.Properties.Name -join ' ')"
        }
      }
      "script: $($steps.Count) step(s) from $file$(if ($dry) { ' (DRY RUN - nothing executed)' })"
      if ($dry) {
        $i = 0
        foreach ($s in $steps) {
          $i++
          $act = @($s.PSObject.Properties.Name | Where-Object { $_ -in $known })[0]
          $mods = @(); if (Get-OptValue $s 'to') { $mods += "to=$(Get-OptValue $s 'to')" }; if (Get-OptValue $s 'guard-text') { $mods += 'guard-text' }; if (Get-OptValue $s 'guard-region') { $mods += 'guard-region' }; if (Get-OptValue $s 'retry') { $mods += "retry=$(Get-OptValue $s 'retry')" }; if (Get-OptValue $s 'expectText') { $mods += "expect=$(Get-OptValue $s 'expectText')" }; if (Get-OptValue $s 'expectGone') { $mods += "expect-gone=$(Get-OptValue $s 'expectGone')" }
          $val = $s.$act
          $vs = if ($val -is [string]) { "'$val'" } else { ($val | ConvertTo-Json -Compress -Depth 3) }
          "#$i $act $vs$(if ($mods) { '  [' + ($mods -join ' ') + ']' })"
        }
        # v1.5.6 (A-5): the click family prints a DELIVERY receipt, so a batch of clicks
        # with no expectation proves only that input was sent. Say it once, at the end,
        # and name the steps - a per-step warning would be noise nobody reads.
        $noExp = @()
        $si = 0
        foreach ($s in $steps) {
          $si++
          $sa = @($s.PSObject.Properties.Name | Where-Object { $_ -in $known })[0]
          if ($sa -in @('click', 'rclick', 'dblclick', 'drag', 'drag-to', 'wheel', 'find-click', 'menu-pick', 'relclick') -and -not (Get-OptValue $s 'expectText') -and -not (Get-OptValue $s 'expectGone')) { $noExp += "$si" }
        }
        if (@($noExp).Count -gt 0) {
          Write-Output "NOTICE: $(@($noExp).Count) action step(s) have no expect/expect-gone: #$($noExp -join ' #') - they will report 'ok' if the input was DELIVERED, not if the interface MOVED. Add expectText/expectGone (CLI: --expect-change for a pixel-delta check)."
        }
        exit 0
      }
      $failed = 0
      $idx = 0
      # v1.9.0 (J-02 C): the popup survival guard. require-popup records the popup's
      # pid+hwnd+class+visible rect as the baseline; every later step is re-checked
      # BEFORE it runs, and any failure aborts the REST of the script (exit 1, measured
      # values echoed, never a silent skip). release-popup and a win-close that really
      # closed the guarded hwnd are the only legal ways to disarm it.
      $popupGuard = $null
      foreach ($s in $steps) {
        $idx++
        $act = @($s.PSObject.Properties.Name | Where-Object { $_ -in $known })[0]
        $val = $s.$act
        $desc = if (Get-OptValue $s 'desc') { " ($(Get-OptValue $s 'desc'))" } else { '' }
        try {
          if ($act -eq 'require-popup') {
            if ($null -ne $popupGuard) { throw "require-popup: a popup guard is already armed (step $($popupGuard.ArmedAtStep)) - release-popup first, one guarded popup at a time" }
            $pgw = Resolve-Target ([string]$val) ([bool](Get-OptValue $s 'force')) $false
            Emit-ResolveNote
            $pgRect = Get-WindowVisibleRect $pgw.Handle
            if ($null -eq $pgRect) { throw "require-popup: the resolved window has no visible rect (pid=$($pgw.Pid) hwnd=$($pgw.Handle))" }
            $pgTol = 3
            if (Get-OptValue $s 'tolerance') {
              $pgTol = [int](Get-OptValue $s 'tolerance')
              if ($pgTol -lt 0) { throw "require-popup: tolerance must be >= 0, got: $(Get-OptValue $s 'tolerance')" }
            }
            $pgOwner = [IntPtr][DT]::GetWindowLong($pgw.Handle, -8)   # GWL_HWNDPARENT: what the popup floats over
            # v2.0.1 merge: the merged differ takes a "before" set. Snapshot the owner's
            # z-order once, at arming. The PRESENCE verdict does not read this snapshot,
            # so an empty one can neither arm nor disarm a guard - it only feeds the
            # forward direction, which no abort reason consumes yet.
            $pgAbove0 = @()
            if ($pgOwner -ne [IntPtr]::Zero) {
              $pgAbove0 = @(Get-SamePidWindowsAbove ([pscustomobject]@{ Handle = $pgOwner; Pid = $pgw.Pid }))
            }
            $popupGuard = @{ Pid = $pgw.Pid; Hwnd = $pgw.Handle; Class = "$($pgw.Class)"; X = $pgRect.X; Y = $pgRect.Y; W = $pgRect.W; H = $pgRect.H; OwnerHwnd = $pgOwner; Above0 = $pgAbove0; Tolerance = $pgTol; MustBeFg = [bool](Get-OptValue $s 'must-be-foreground'); ArmedAtStep = $idx }
            Log-Action @($file) "popup guard armed at step $idx (pid=$($pgw.Pid) hwnd=0x$($pgw.Handle.ToString('X')) class=$($pgw.Class))" $Cmd
            "popup guard: armed at step $idx (pid=$($pgw.Pid) hwnd=0x$($pgw.Handle.ToString('X')) class=$($pgw.Class) rect=($($pgRect.X),$($pgRect.Y),$($pgRect.W)x$($pgRect.H)) tolerance=$pgTol must-be-foreground=$($popupGuard.MustBeFg))"
          }
          elseif ($act -eq 'release-popup') {
            if ($null -eq $popupGuard) { throw 'release-popup: no popup guard is armed - nothing to release' }
            "popup guard: released at step $idx (pid=$($popupGuard.Pid) hwnd=0x$($popupGuard.Hwnd.ToString('X')))"
            Log-Action @($file) "popup guard released at step $idx" $Cmd
            $popupGuard = $null
          }
          # survival re-check: on the arming step itself (baseline verified on the spot,
          # C-1) and before EVERY later step
          if ($null -ne $popupGuard) {
            $pgIsW = [DT]::IsWindow($popupGuard.Hwnd)
            $pgAbove = @()
            if ($null -ne $popupGuard.OwnerHwnd -and $popupGuard.OwnerHwnd -ne [IntPtr]::Zero) {
              $pgAbove = @(Get-SamePidWindowsAbove ([pscustomobject]@{ Handle = $popupGuard.OwnerHwnd; Pid = $popupGuard.Pid }))
            }
            $pgRect2 = $null
            if ($pgIsW) { $pgRect2 = Get-WindowVisibleRect $popupGuard.Hwnd }
            $pgChk = Test-PopupGuardAlive $popupGuard $pgIsW $pgAbove $pgRect2 ([DT]::GetForegroundWindow())
            if (-not $pgChk.Alive) {
              $pgNow = "IsWindow=$pgIsW present=$($pgChk.Present) above=$($pgChk.Above) fg=$($pgChk.FgOk)"
              $pgRectTxt = '-'
              if ($pgRect2) { $pgRectTxt = "($($pgRect2.X),$($pgRect2.Y),$($pgRect2.W)x$($pgRect2.H))" }
              Log-Action @($file) ("POPUP-GUARD-ABORTED at step $idx of $($steps.Count): " + $pgChk.Reason) $Cmd
              throw ("POPUP-GUARD-ABORT: popup guard: $($pgChk.Reason) before step $idx of $($steps.Count)`n  baseline: pid=$($popupGuard.Pid) hwnd=0x$($popupGuard.Hwnd.ToString('X')) class=$($popupGuard.Class) rect=($($popupGuard.X),$($popupGuard.Y),$($popupGuard.W)x$($popupGuard.H))`n  now     : $pgNow rect=$pgRectTxt`n  delta   : $($pgChk.Drift)")
            }
          }
          if ($act -notin @('require-popup', 'release-popup')) {
            # hard foreground guard - aborts everything on failure
            if (Get-OptValue $s 'to') {
              $gt = Resolve-Target (Get-OptValue $s 'to') ([bool](Get-OptValue $s 'force')) ([bool](Get-OptValue $s 'alwaysActivate'))
              Emit-ResolveNote
              if ([DT]::GetForegroundWindow() -ne $gt.Handle) {
                throw "GUARD-ABORT: step #$idx to='$(Get-OptValue $s 'to')' did not become foreground (fg: $(Get-ForegroundInfo))"
              }
            }
            if ((Get-OptValue $s 'guard-text') -or (Get-OptValue $s 'guard-region')) {
              $tgt = if (Get-OptValue $s 'to') { $gt } else { Resolve-Target '' $false $false ([string](Get-OptValue $s 'expectHandle')) }
              Emit-ResolveNote
              Invoke-ContentGuard $tgt (Get-OptValue $s 'guard-text') (Get-OptValue $s 'guard-region')
            }
            # resolve the win-close target BEFORE the step runs: after it the guarded
            # popup may already be gone and a re-resolve would find nothing
            $pgWc = $null
            if ($act -eq 'win-close' -and $null -ne $popupGuard) {
              $pgWc = Resolve-Window ([string]@($val)[0])
            }
            $attempts = if (Get-OptValue $s 'retry') { [int](Get-OptValue $s 'retry') } else { 1 }
            $interval = if (Get-OptValue $s 'intervalMs') { [int](Get-OptValue $s 'intervalMs') } else { 800 }
            if ($attempts -lt 1) { $attempts = 1 }
            for ($a = 1; $a -le $attempts; $a++) {
              try {
                Invoke-ScriptStep $act $val $idx $s
                break
              } catch {
                if ($a -ge $attempts) { throw }
                Write-Output "#$idx attempt $a failed: $($_.Exception.Message) - retrying in ${interval}ms"
                Start-Sleep -Milliseconds $interval
              }
            }
            # C-3: a win-close that really closed the guarded popup is a LEGAL dismissal,
            # not a guard failure - disarm and say so, or the next re-check would abort
            # on the script's own doing. WM_CLOSE is asynchronous, so give the close a
            # moment; if the handle refuses to die the guard stays armed and honest.
            if ($null -ne $pgWc -and $null -ne $popupGuard -and ($pgWc.Handle -eq $popupGuard.Hwnd)) {
              $pgDead = $false
              $swPgWc = [System.Diagnostics.Stopwatch]::StartNew()
              while ($swPgWc.ElapsedMilliseconds -lt 1500) {
                if (-not [DT]::IsWindow($pgWc.Handle)) { $pgDead = $true; break }
                Start-Sleep -Milliseconds 100
              }
              if ($pgDead) {
                "popup guard: released at step $idx (win-close closed the guarded popup)"
                Log-Action @($file) "popup guard released at step $idx (win-close closed the guarded popup)" $Cmd
                $popupGuard = $null
              }
            }
          }
          "#$idx $act ok$desc"
        } catch {
          if ("$($_.Exception.Message)" -like 'POPUP-GUARD-ABORT*') {
            Write-Output "#$idx $act POPUP-GUARD FAIL"
            Write-Output ("$($_.Exception.Message)" -replace '^POPUP-GUARD-ABORT: ', '')
            Write-Output "script aborted: popup guard failed (nothing after this step ran)"
            exit 1
          }
          if ("$($_.Exception.Message)" -like 'GUARD-ABORT*') {
            Write-Output "#$idx $act GUARD FAIL: $($_.Exception.Message -replace '^GUARD-ABORT: ','')"
            Write-Output "script aborted: foreground guard failed (nothing after this step ran)"
            exit 1
          }
          $failed++
          Write-Output "#$idx $act FAIL: $($_.Exception.Message)$desc"
          if ($stopOnError) {
            Write-Output "script aborted by --stop-on-error after $failed failure(s)"
            exit 1
          }
        }
        if ($shotAt -eq $idx) {
          $o = [System.Windows.Forms.SystemInformation]::VirtualScreen
          Save-RectEx $o.X $o.Y $o.Width $o.Height (Join-Path $OutDir "script_step$idx.png") 0 -1 @() | Write-Output
        }
      }
      if ($failed -gt 0) { "script: $($steps.Count) steps, $failed FAILED"; exit 1 }
      "script: $($steps.Count) steps, all ok"
}
# v4.4.0 (A-15): the plain handlers carved out of the dispatcher, kept directly below it. Each body is
#    the case text verbatim - no flag, no re-indent, no edit - and the case in the switch is the
#    three-line stub that calls it. This is safe for these 72 and only for these 72 because each of
#    them has zero clause-level return and zero clause-level break/continue (checked above from the
#    AST, per case), so "falls off the end of the body" and "falls out of the switch" are the same
#    destination: the dispatcher tail. The four that differ are the flagged set the ruling names.

# v4.4.0 (A-15): the handlers carved out of the dispatcher so far, kept directly below it. Bodies are
#    the case text verbatim except for one thing the G-17 ruling allows: a flag set immediately before
#    a return that returns from the handler. The dispatcher stub reads that flag and returns at once,
#    which is exactly what the inline body did today - the tail (Trim-ShotDir 'after-command' and
#    Emit-ResolveNote) must not start running on a path that never reached it. Getting the naming
#    right is not cosmetic: a PascalCase map added a case-folding step nothing checks, so the handler
#    name is the raw command label behind one prefix and lint (A-15b) proves the pair both ways.


# Replay runner, extracted verbatim from the old 'replay' case (audit
# 2026-09-29 #11). Re-invokes desktop.ps1 per recorded command, so every child
# logs its own audit line with the redaction rules of its version.
# v1.5.2 WP-2 (audit R-02, HIGH): 'replay' used to IGNORE every flag it did not
# know, while README documented a '--from <ts>' that has never existed anywhere
# in the source. `replay --from 2026-01-01 --go` therefore quietly fell through
# to the WHOLE actions.log - measured live: 1176 recorded desktop actions queued
# for execution instead of the intended slice. Unknown --flags now throw, the
# same principle the script loader has enforced since v1.3.0. Kept as a pure
# function because Invoke-ReplayLog exits by design and cannot be unit-tested
# in-process (an accidental non-throw would end the selftest run).
function Split-ReplayFlags([string[]]$words) {
  $t = @($words)
  $logPath = $ActionLog; $last = 0; $grep = ''; $go = $false
  if ($t.Count -ge 1 -and "$($t[0])" -and -not ("$($t[0])").StartsWith('--')) { $logPath = "$($t[0])" }
  for ($i = 0; $i -lt $t.Count; $i++) {
    $cur = "$($t[$i])"
    if ($cur -eq '--last') {
      $i++
      if ($i -ge $t.Count) { throw 'replay: --last needs a count' }
      $last = [int]$t[$i]
    } elseif ($cur -eq '--grep') {
      $i++
      if ($i -ge $t.Count) { throw 'replay: --grep needs a substring' }
      $grep = "$($t[$i])"
    } elseif ($cur -eq '--go') {
      $go = $true
    } elseif ($cur -like '--*') {
      throw "replay: unknown flag '$cur' (valid: <actions.log> | --last <n> | --grep <substr> | --go - there is no --from)"
    }
  }
  return @{ LogPath = $logPath; Last = $last; Grep = $grep; Go = $go }
}

# v1.5.2 WP-2 (audit R-03, HIGH): since v1.4.1 Log-Action records typed payloads
# and guard/expect needles as '<redacted:Nchars>'. The placeholder IS what the
# log holds, so replaying such a line types the literal '<redacted:12chars>' into
# the target window (measured live: it landed in a textbox and echoed ok).
# Relaxing redaction to restore replay is forbidden (task order 1.4), so the step
# is REFUSED with its reason - never silently dropped, never sent.
function Test-ReplayStepRedacted([string[]]$argTokens) {
  $all = @($argTokens | ForEach-Object { "$_" })
  $hits = @($all | Where-Object { $_ -like '*<redacted:*' })
  return @{ Refused = ($hits.Count -gt 0); Placeholders = $hits }
}

# v1.9.0 (C-4): a script run aborted by the popup guard leaves an explicit marker in
# actions.log. The steps recorded BEFORE that abort ran in a world where the guarded
# popup still existed - replaying them clicks into a world where it may not (same shape
# as the redacted-placeholder refusal: half-executed state must not be replayed).
# Pure scanner so the RULE is unit-testable; Invoke-ReplayLog turns hits into a refusal
# of the whole selected slice, with no --force backdoor by design.
function Test-ReplayPopupAbort($lines) {
  $hits = New-Object System.Collections.ArrayList
  foreach ($ln in @($lines)) {
    if ("$ln" -like '*| script |*POPUP-GUARD-ABORTED*') { [void]$hits.Add("$ln") }
  }
  return @($hits)
}

function Invoke-ReplayLog([string[]]$Rest) {
      # replay [<actions.log>] [--last n] [--grep substr] [--go]
      # Re-runs act/text/clipboard commands recorded in actions.log. Default is
      # DRY RUN (prints what would run); --go actually executes. Only lines
      # logged by v1.3.0+ tokenize reliably (args with spaces are quoted).
      $flags = Split-ReplayFlags $Rest
      $logPath = $flags.LogPath; $last = $flags.Last; $grep = $flags.Grep; $go = $flags.Go
      if (-not (Test-Path $logPath)) { throw "log not found: $logPath" }
      $lines = @(Get-Content $logPath -Encoding UTF8 | Where-Object { $_ -match ' \| \S+ \| ' })
      if ($grep) { $lines = @($lines | Where-Object { $_ -like "*$grep*" }) }
      if ($last -gt 0) { $lines = @($lines | Select-Object -Last $last) }
      # v1.9.0 (C-4): refuse the whole selected slice when it carries a popup-guard
      # abort marker - before the dry-run listing, so even an eyeball-only replay is
      # refused. Re-run the original script explicitly instead.
      $pgAbortLines = @(Test-ReplayPopupAbort $lines)
      if (@($pgAbortLines).Count -gt 0) {
        Write-Output ('refusing to replay a script that was aborted by the popup guard ' + [char]0x2014 + ' re-run it explicitly')
        foreach ($al in $pgAbortLines) { Write-Output ('  marker: ' + $al) }
        exit 1
      }
      $replayable = @('move','click','rclick','dblclick','wheel','relclick','focus','type','type-in','keys','paste','copy-file','paste-file','drag','win-move','win-resize','win-max','win-min','win-restore','win-close','menu-pick','open-and-pick')
      $jobs = New-Object System.Collections.ArrayList
      $refused = New-Object System.Collections.ArrayList
      foreach ($ln in $lines) {
        $parts = $ln -split ' \| ', 4
        if ($parts.Count -lt 3) { continue }
        $cmd = $parts[1]
        if ($cmd -notin $replayable) { continue }
        $argTokens = Split-LogArgs $parts[2]
        $red = Test-ReplayStepRedacted $argTokens
        if ($red.Refused) {
          [void]$refused.Add(@{ Cmd = $cmd; Args = $argTokens; Why = ($red.Placeholders -join ' ') })
          continue
        }
        [void]$jobs.Add(@{ Cmd = $cmd; Args = $argTokens })
      }
      if ($jobs.Count -eq 0 -and $refused.Count -eq 0) { "replay: no replayable commands found in $logPath"; exit 0 }
      if (-not $go) {
        $k = 0
        foreach ($j in $jobs) { $k++; "#$k WOULD: $($j.Cmd) $($j.Args -join ' ')" }
        foreach ($r in $refused) { $k++; "#$k REFUSED (payload was redacted at log time, cannot replay): $($r.Cmd) $($r.Args -join ' ')" }
        "replay: $($jobs.Count) command(s) would run, $($refused.Count) refused as redacted - pass --go to execute (after eyeballing the list)"
        exit 0
      }
      $k = 0; $bad = 0
      foreach ($r in $refused) {
        $k++; $bad++
        Write-Output "#$k REFUSED: $($r.Cmd) recorded as '$($r.Why)' - the payload was redacted at log time, replaying it would type the placeholder into the target (re-run the ORIGINAL step with --log-payload if a faithful replay is genuinely required)"
      }
      foreach ($j in $jobs) {
        $k++
        Write-Output "#$k RUN: $($j.Cmd) $($j.Args -join ' ')"
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath @($j.Cmd) @($j.Args) | Write-Output
        if ($LASTEXITCODE -ne 0) { $bad++; Write-Output "#$k FAIL (exit $LASTEXITCODE)" }
      }
      if ($bad -gt 0) { "replay: $k command(s), $bad FAILED"; exit 1 }
      "replay: $k command(s), all ok"
}

# Executes one script step. 'sleep' and 'shot' are implemented here; everything
# else is delegated to the real command so behaviour can never drift apart.
# v1.5.0 WP-2: steps may carry expectText/expectGone/expectRegion/timeoutSec/
# intervalMs - serialized into --expect/--expect-gone/--expect-region/... for
# the expect-capable commands, so an expectation failure is a normal step FAIL
# (recorded, execution continues, final exit 1) per the script gate contract.
# v1.5.2 WP-1: that serialization moved into Get-StepTokens (pure, unit-testable) -
# the shipped form silently turned the flags into payload text (audit R-01).
function Invoke-ScriptStep([string]$name, $val, [int]$idx, $step = $null) {
  switch ($name) {
    'sleep' {
      Start-Sleep -Milliseconds ([int]$val)
      "slept $val ms"
    }
    'shot' {
      $o = [System.Windows.Forms.SystemInformation]::VirtualScreen
      if ($val -is [string]) {
        Save-RectEx $o.X $o.Y $o.Width $o.Height $val 0 -1 @() | Write-Output
      } else {
        Save-RectEx ([int]$val.region[0]) ([int]$val.region[1]) ([int]$val.region[2]) ([int]$val.region[3]) $val.out 0 -1 @() | Write-Output
      }
    }
    default {
      $tokens = Get-StepTokens $name $val $step
      # A step is NOT a top-level invocation. press-down only blocks waiting for its
      # own deadline when it is run from the CLI; inside a script it returns at once,
      # because the steps that follow are the whole reason the button is held.
      $script:PressTopLevel = $false
      try { Invoke-DesktopCommand $name $tokens } finally { $script:PressTopLevel = $true }
    }
  }
}

# Assembles one step into the target command's argument tokens: the positional
# serialization of the step value, plus the expect-family flags the step asked
# for. Kept separate from Invoke-ScriptStep so the single-token case is a unit
# test and not a desktop test.
# v1.5.2 WP-1 (audit R-01, HIGH): PS 5.1 unwraps a function's 1-element array
# return into a String. When ConvertTo-StepArgs handed back a bare String, the
# old `$tokens + @('--expect', ...)` here was STRING CONCATENATION, so a step
# like {"type":["ABC"],"expectText":"ABC"} typed 'ABC--expect ABC--timeout 6'
# into the target window and the step echoed ok (exit 0). Two defences, both
# load-bearing: every ConvertTo-StepArgs return is comma-wrapped (,@(...)), and
# @($converted) below re-asserts array-ness at the assembly site. Do not remove
# either one, and never wrap the CALL in @()/$() - the source lint forbids it.
function Get-StepTokens([string]$name, $val, $step) {
  $converted = ConvertTo-StepArgs $name $val
  $tokens = @($converted)
      $expectCapable = @('click', 'rclick', 'dblclick', 'find-click', 'menu-pick', 'keys', 'type', 'paste', 'paste-file', 'open-and-pick')
  if ($null -ne $step -and $name -in $expectCapable) {
    if (Get-OptValue $step 'expectText') { $tokens = $tokens + @('--expect', "$(Get-OptValue $step 'expectText')") }
    if (Get-OptValue $step 'expectGone') { $tokens = $tokens + @('--expect-gone', "$(Get-OptValue $step 'expectGone')") }
    # v3.0.0 (B-3): a step may assert an ANY-OF list (or an ALL-GONE list). The field takes a
    # JSON array or a comma string; both become the one token the CLI flag expects, so the
    # step path and the command-line path share a single grammar and a single parser.
    if ((Get-OptValue $step 'expectAny')) { $tokens = $tokens + @('--expect-any', (@((Get-OptValue $step 'expectAny')) -join ',')) }
    if (Get-OptValue $step 'expectAnyGone') { $tokens = $tokens + @('--expect-any-gone', (@(Get-OptValue $step 'expectAnyGone') -join ',')) }
    # v3.0.0 (B-2): a step may carry the same identity pin the CLI flag gives. It goes
    # through the token path on purpose - one grammar, one parser, no step-only shortcut.
    if (Get-OptValue $step 'expectHandle') { $tokens = $tokens + @('--expect-handle', "$(Get-OptValue $step 'expectHandle')") }
    if (Get-OptValue $step 'expectRegion') { $tokens = $tokens + @('--expect-region', "$(Get-OptValue $step 'expectRegion')") }
    if (Get-OptValue $step 'timeoutSec') { $tokens = $tokens + @('--timeout', "$(Get-OptValue $step 'timeoutSec')") }
    if (Get-OptValue $step 'intervalMs') { $tokens = $tokens + @('--interval', "$([int](Get-OptValue $step 'intervalMs'))") }
  }
  return ,$tokens
}

# Serializes a step value into the target command's argument tokens. Region
# arrays go in flat - Resolve-Region accepts "<x> <y> <w> <h>" everywhere.
function ConvertTo-StepArgs([string]$name, $val) {
  # Each structured action accepts BOTH forms:
  #   object     {"assert-text": {"sel": "notepad", "needle": "File"}}
  #   positional {"assert-text": ["notepad", "File"]}
  # Accepting only the object form made an array fail as "empty needle" /
  # "timeout 0", which reads like a bug in the assertion rather than in the step.
  $asArr = @($val -isnot [string] -and $val -is [System.Collections.IEnumerable] -and $val -isnot [System.Collections.IDictionary])
  switch ($name) {
    'wheel' {
      if ($val -is [string] -or $val -is [int] -or $val -is [long] -or $val -is [double]) { return ,@("$val") }
      $t = @("$([int]$val.amount)")
      if ($val.at) { $t = $t + @('--at', "$($val.at)") }
      return ,@($t)
    }
    'assert-text' {
      if ($asArr) {
        # region array [x,y,w,h,needle] is 5 tokens; [sel, needle] is 2. The old
        # "-eq 6" gate never matched the real region shape, so arrays fell into
        # the sel branch and died as "expected <sel> or ..." (audit 2026-09-29 #3).
        if ($val.Count -ge 5) { return ,@("$([int]$val[0])", "$([int]$val[1])", "$([int]$val[2])", "$([int]$val[3])", ($val[4..($val.Count - 1)] -join ' ')) }
        if ($val.Count -eq 2) { return ,@("$($val[0])", ($val[1..($val.Count - 1)] -join ' ')) }
        throw 'script: assert-text needs [sel, needle] or [x,y,w,h,needle] or {sel,needle} / {region,needle}'
      }
      if ($val.region) { return ,@("$([int]$val.region[0])", "$([int]$val.region[1])", "$([int]$val.region[2])", "$([int]$val.region[3])", "$($val.needle)") }
      if (-not $val.sel -or -not $val.needle) { throw 'script: assert-text needs {sel, needle} or {region, needle}' }
      return ,@("$($val.sel)", "$($val.needle)")
    }
    'assert-color' {
      if ($asArr) {
        if ($val.Count -lt 3) { throw 'script: assert-color needs [x, y, "#RRGGBB"] (tolerance optional as 4th)' }
        $t = @("$([int]$val[0])", "$([int]$val[1])", "$($val[2])")
        if ($val.Count -ge 4) { $t = $t + @('--tolerance', "$([int]$val[3])") }
        return ,@($t)
      }
      $t = @("$([int]$val.at[0])", "$([int]$val.at[1])", "$($val.hex)")
      if ($val.tolerance) { $t = $t + @('--tolerance', "$([int]$val.tolerance)") }
      return ,@($t)
    }
    'hover' {
      # [x, y] or [x, y, dwell] -> "x y --dwell ms" (a bare third token would be
      # silently dropped by the positional parser, so map it explicitly)
      if ($asArr -and $val.Count -ge 3) { return ,@("$([int]$val[0])", "$([int]$val[1])", '--dwell', "$([int]$val[2])") }
      return ,@("$($val[0])", "$($val[1])")
    }
    'press-down' {
      # v2.0.1 (P-3): [x, y] | [x, y, maxHoldMs] | {x, y, maxHold} -> the same mapping
      # 'hover' needs: a bare third positional token would be parsed and then dropped.
      if ($asArr) {
        if ($val.Count -lt 2) { throw 'script: press-down needs [x, y] or [x, y, max-hold-ms] or {x, y, maxHold}' }
        if ($val.Count -ge 3) { return ,@("$([int]$val[0])", "$([int]$val[1])", '--max-hold', "$([int]$val[2])") }
        return ,@("$([int]$val[0])", "$([int]$val[1])")
      }
      $pt = @()
      if ($null -ne $val.x -and $null -ne $val.y) { $pt = @("$([int]$val.x)", "$([int]$val.y)") }
      elseif ($asArr -or $val.Count -lt 2) { throw 'script: press-down needs [x, y] or [x, y, max-hold-ms] or {x, y, maxHold}' }
      if ($val.maxHold) { $pt = $pt + @('--max-hold', "$([int]$val.maxHold)") }
      return ,@($pt)
    }
    'drag-to' {
      # [x, y] | [x, y, steps] | {x, y, steps}
      if ($asArr) {
        if ($val.Count -lt 2) { throw 'script: drag-to needs [x, y] or [x, y, steps] or {x, y, steps}' }
        if ($val.Count -ge 3) { return ,@("$([int]$val[0])", "$([int]$val[1])", '--steps', "$([int]$val[2])") }
        return ,@("$([int]$val[0])", "$([int]$val[1])")
      }
      $dt = @()
      if ($null -ne $val.x -and $null -ne $val.y) { $dt = @("$([int]$val.x)", "$([int]$val.y)") }
      elseif ($asArr -or $val.Count -lt 2) { throw 'script: drag-to needs [x, y] or [x, y, steps] or {x, y, steps}' }
      if ($val.steps) { $dt = $dt + @('--steps', "$([int]$val.steps)") }
      return ,@($dt)
    }
    'press-up' {
      # [x, y] | {x, y} - no private flag, but the count still has to be checked or a
      # {"press-up": [900]} degrades into "press-up 900" and the usage throw names the
      # wrong problem.
      if ($asArr) {
        if ($val.Count -lt 2) { throw 'script: press-up needs [x, y] or {x, y}' }
        return ,@("$([int]$val[0])", "$([int]$val[1])")
      }
      if ($null -ne $val.x -and $null -ne $val.y) { return ,@("$([int]$val.x)", "$([int]$val.y)") }
      throw 'script: press-up needs [x, y] or {x, y}'
    }
    'find-click' {
      # {"sel": "x", "needle": "y", "index": 0} | {"region": [..], "needle": "y"}
      # | ["sel", "needle"] | ["x","y","w","h","needle"] (index optional everywhere)
      $idx = @()
      if ($val.index) { $idx = @('--index', "$([int]$val.index)") }
      if ($asArr) {
        if ($val.Count -ge 5) { return ,(@("$([int]$val[0])", "$([int]$val[1])", "$([int]$val[2])", "$([int]$val[3])", ($val[4..($val.Count - 1)] -join ' ')) + $idx) }
        if ($val.Count -ge 2) { return ,(@("$($val[0])", ($val[1..($val.Count - 1)] -join ' ')) + $idx) }
        throw 'script: find-click needs [sel, needle] or [x,y,w,h,needle] or {sel|region, needle[, index]}'
      }
      if ($val.region) { return ,(@("$([int]$val.region[0])", "$([int]$val.region[1])", "$([int]$val.region[2])", "$([int]$val.region[3])", "$($val.needle)") + $idx) }
      if (-not $val.sel -or -not $val.needle) { throw 'script: find-click needs {sel|region, needle}' }
      return ,(@("$($val.sel)", "$($val.needle)") + $idx)
    }
    'assert-hash' {
      if ($asArr) {
        # [x,y,w,h,op,hash] is 6 tokens; [sel, op, hash] is 3. The old "-eq 7"
        # gate never matched, so the region array degraded to a bogus 3-token
        # sel form and then hit the command's old 6-token gate (audit 2026-09-29 #2).
        if ($val.Count -ge 6) { return ,@("$([int]$val[0])", "$([int]$val[1])", "$([int]$val[2])", "$([int]$val[3])", "$($val[4])", "$($val[5])") }
        if ($val.Count -eq 3) { return ,@("$($val[0])", "$($val[1])", "$($val[2])") }
        throw 'script: assert-hash needs [sel, op, hash] or [x,y,w,h,op,hash] or {sel,op,hash} / {region,op,hash}'
      }
      if ($val.region) { return ,@("$([int]$val.region[0])", "$([int]$val.region[1])", "$([int]$val.region[2])", "$([int]$val.region[3])", "$($val.op)", "$($val.hash)") }
      if (-not $val.sel) { throw 'script: assert-hash needs {sel, op, hash} or {region, op, hash}' }
      return ,@("$($val.sel)", "$($val.op)", "$($val.hash)")
    }
    { $_ -in 'wait-stable', 'assert-stable' } {
      if ($val -is [string]) { return ,@($val) }
      if ($asArr) {
        if ($val.Count -eq 5) { return ,@("$([int]$val[0])", "$([int]$val[1])", "$([int]$val[2])", "$([int]$val[3])", "$($val[4])") }
        if ($val.Count -lt 2) { throw "script: $name needs [sel, timeout] or [x,y,w,h,timeout]" }
        return ,@("$($val[0])", "$($val[1])")
      }
      if ($val.region) { return ,@("$([int]$val.region[0])", "$([int]$val.region[1])", "$([int]$val.region[2])", "$([int]$val.region[3])", "$($val.timeout)") }
      if (-not $val.sel) { throw "script: $name needs {sel, timeout} or {region, timeout}" }
      return ,@("$($val.sel)", "$([int]$val.timeout)")
    }
    default {
      if ($val -is [string]) { return ,@($val) }
      $out = New-Object System.Collections.ArrayList
      foreach ($v in @($val)) { [void]$out.Add("$v") }
      return ,@($out)
    }
  }
}

# Tokenizes an actions.log args column (Quote-LogArg format: single quotes with
# '' escapes for embedded quotes) back into argument tokens.
function Split-LogArgs([string]$s) {
  $toks = New-Object System.Collections.ArrayList
  $cur = New-Object System.Text.StringBuilder
  $inq = $false
  $i = 0
  while ($i -lt $s.Length) {
    $ch = $s[$i]
    if ($inq) {
      if ($ch -eq "'") {
        if (($i + 1) -lt $s.Length -and $s[$i + 1] -eq "'") { [void]$cur.Append("'"); $i++ }
        else { $inq = $false }
      } else { [void]$cur.Append($ch) }
    } else {
      if ($ch -eq "'") { $inq = $true }
      elseif ($ch -eq ' ') {
        if ($cur.Length -gt 0) { [void]$toks.Add($cur.ToString()); [void]$cur.Clear() }
      } else { [void]$cur.Append($ch) }
    }
    $i++
  }
  if ($cur.Length -gt 0) { [void]$toks.Add($cur.ToString()) }
  return @($toks)
}

try {
  # CU-CALL (v4.5.0): start before argument checks and before the entry watchdog.
  # State failures are diagnostics only; they never block or change the command result.
  $script:CallLease = $null
  $script:InvocationResult = 'exception'
  $script:InvocationExitCode = 1
  $script:InvocationErrorCategory = ''
  try { $script:CallLease = Start-DtxCallTracking $Cmd $Rest }
  catch { [Console]::Error.WriteLine('WARNING: desktop tool call-state=unknown reason=state-unavailable; no idle claim is made.') }

  # Global --json: machine-readable output for commands that produce structured
  # data. Stripped before dispatch so it never collides with positional args.
  # v3.0.0 (S-2): it is now also GATED. Until now --json was stripped for EVERY command and
  # honored by about ten of them, so `cursor --json` printed plain text and exited 0 - a
  # caller parsing stdout would have read the text as if it were the JSON it asked for. That
  # is the same defect this repo fixed for --scale tiled in file mode (v2.8.0: "accepted but
  # does nothing"), and the same one D-1 is about for private flags.
  if (@($Rest) -contains '--json') {
    $script:Json = $true
    $Rest = @($Rest | Where-Object { $_ -ne '--json' })
    if (-not (Test-JsonCapableCommand $Cmd)) {
      throw "--json is not supported by '$Cmd' - it is accepted by: $(@(Get-JsonCapableCommandSet) -join ' ') (refused before the command ran, so nothing was measured, read or sent)"
    }
  } else {
    $script:Json = $false
  }

  # v3.0.0 (B-2/B-4 pairing note): --expect-handle is NOT stripped here on purpose - it is a
  # Split-Target shared flag, because the pin has to reach the resolver through the same
  # path the other guards use. Only flags whose meaning is "how to render the whole run"
  # (--json, --ocr-lang, --dump) belong at this boundary.
  #
  # v3.0.0 (B-4): --dump <path>. Accepted, gated and consumed HERE (before anything runs),
  # so an unsupported command refuses without having touched the desktop, and every
  # supported command gets the same capture without five private copies of the print loop.
  $script:DumpPath = ''
  if (@($Rest) -contains '--dump') {
    $tmpD = New-Object System.Collections.ArrayList
    $skipD = $false
    foreach ($t in $Rest) {
      if ($skipD) { $script:DumpPath = "$t"; $skipD = $false; continue }
      if ($t -eq '--dump') { $skipD = $true; continue }
      [void]$tmpD.Add($t)
    }
    if ($skipD) { throw '--dump needs a file path after it' }
    $Rest = @($tmpD)
    if (-not $script:DumpPath.Trim()) { throw '--dump needs a non-empty file path' }
    if (-not (Test-DumpCommand $Cmd)) {
      throw "--dump is not supported by '$Cmd' - it is accepted by: $(@(Get-DumpCommandSet) -join ' ') (refused before the command ran, so nothing was read or written)"
    }
  }

  # Global --ocr-lang <tag> (v1.5.0 WP-4): pin the OCR recognizer language when
  # several packs are installed. Stripped before dispatch so it never collides
  # with positional args; validated lazily in Get-OcrEngine against the
  # installed packs (an unavailable tag errors with the list, never a silent
  # switch to another language). Without the flag the pick order is unchanged.
  if (@($Rest) -contains '--ocr-lang') {
    $tmp = New-Object System.Collections.ArrayList
    $skipNext = $false
    foreach ($t in $Rest) {
      if ($skipNext) { $script:OcrLang = $t; $skipNext = $false; continue }
      if ($t -eq '--ocr-lang') { $skipNext = $true; continue }
      [void]$tmp.Add($t)
    }
    if ($skipNext) { throw '--ocr-lang needs a language tag (e.g. zh-Hans-CN / en-US)' }
    $Rest = @($tmp)
  }

  # v4.2.2 (F2, entry normalization; machine owner authorized 2026-10-10, option "normalize at
  # entry"): repair a duplicated-case process environment BEFORE anything can spawn a child. The
  # failure it removes is total, not cosmetic: PS 5.1's Start-Process copies the block into a
  # case-insensitive dictionary and throws "Item has already been added" on a twin, which killed
  # the whole offline gate above its summary line (measured 2026-10-10; first spawn is the
  # OCR-file round trip). Windows resolves env lookups case-insensitively, so dropping the later
  # spelling of a name loses no value - probe: after the twin was gone http_proxy still resolved
  # and Start-Process returned exit 0. A clean environment (the normal case) prints neither
  # message below: the finder returns nothing and nothing is emitted. The note goes to STDERR on
  # purpose - stdout is the command's output contract, and `--json`/`--dump` are pinned key sets
  # and line sets that a repair note must not enter.
  $script:EnvDedupRemoved = @()
  $script:EnvDedupError = ''
  try {
    $envRawNames = [DT]::RawEnvNames()
    $envDupes = Get-DuplicateCaseEnvNames $envRawNames
    foreach ($envDn in @($envDupes)) { [Environment]::SetEnvironmentVariable($envDn, $null, 'Process') }
    $script:EnvDedupRemoved = @($envDupes)
  } catch { $script:EnvDedupError = $_.Exception.Message }
  if (@($script:EnvDedupRemoved).Count -gt 0) {
    [Console]::Error.WriteLine('NOTE: removed ' + @($script:EnvDedupRemoved).Count + ' duplicate-case environment name(s) so child processes can be spawned: ' + (@($script:EnvDedupRemoved) -join ', ') + ' (the surviving spelling keeps the value)')
  }
  if ($script:EnvDedupError -ne '') {
    [Console]::Error.WriteLine('NOTE: environment duplicate-case normalization unavailable: ' + $script:EnvDedupError)
  }

  # v2.0.1 (P-3) watchdog 2: a left-down button is MACHINE-WIDE state, so every
  # invocation recovers it at its entry, before doing anything of its own. This is
  # process entry, NOT per-command dispatch: a watchdog inside Invoke-DesktopCommand
  # would release the press between the steps of the script that just made it.
  # The two commands that act ON a press state (press-up / drag-to) are exempted by
  # the gate, so they can still see and report what they are given.
  $pressWarn = Invoke-PressWatchdog $Cmd
  if ($pressWarn) {
    # S-90 (owner ruling via codex 21:57 +0800, relayed 2026-10-16 23:01): this sentence is a diagnostic
    # about machine-wide button state, not a field of any command envelope. On the JSON road the success
    # stream carries the envelope and nothing else, so there it goes to the error stream; without the
    # flag the human reading is untouched. The release, the audit line and the watchdog itself are not
    # modified - only WHICH STREAM the sentence uses, the same convention as the auto-trim sentence
    # (G-08) and the environment-dedup NOTE in this very block.
    if ($script:Json) {
      [Console]::Error.WriteLine([string]$pressWarn)
    } else {
      Write-Output $pressWarn
    }
  }

  # v3.0.0 (B-6): the text outlets get the same label the JSON envelopes carry as
  # `contentTrust`. Printed AFTER the command, so a reader who pipes the bulk somewhere still
  # sees it, and skipped entirely under --json (that key set is a pinned contract, and the
  # machine consumer reads the key instead). Under --dump the label goes INTO the file,
  # because the file is the thing that will be re-read later without its context.
  $needTrustNote = (Test-UntrustedTextCommand $Cmd) -and (-not $script:Json)
  # v3.1.0 (X-01): the action family has ONE json outlet, and it is HERE, not inside the cases.
  # Reason for the placement: an action command emits its verdicts from eight different helpers
  # (hit-window, content guard, landing guard, foreground guard, expectation anchor, occlusion
  # gate, paste receipt, post-send popup). Teaching every case to build an object is how the
  # read family got three copies of one key set and two live checks sat red unseen for two
  # rounds (v3.0.0 B-6). Capturing at the boundary means the envelope CANNOT disagree with the
  # text: `lines` is literally the text that would have been printed.
  # A refused action still takes the catch path below (`ERROR: ...` + exit 1) - the entry
  # contract is untouched, and selftest pins that the envelope never swallows a refusal.
  $actJson = $script:Json -and (Test-ActionJsonCommand $Cmd)
  if ($script:DumpPath) {
    # Captured, not piped: the whole point of --dump is that the bulk never reaches the
    # caller's context. stderr (cost self-reports, WARN lines the command writes there) is
    # NOT captured and still goes to the terminal as it always did.
    $produced = @(& { Invoke-DesktopCommand $Cmd $Rest })
    if ($actJson) { $produced = @(Format-ActionJsonEnvelope $Cmd $produced) }
    elseif ($needTrustNote) { $produced = @($produced) + (Get-UntrustedContentNote) }
    Emit-DumpOutput $produced $script:DumpPath $Cmd
  } else {
    if ($actJson) {
      Write-Output (Format-ActionJsonEnvelope $Cmd @(& { Invoke-DesktopCommand $Cmd $Rest }))
    } else {
      Invoke-DesktopCommand $Cmd $Rest
      if ($needTrustNote) { Write-Output (Get-UntrustedContentNote) }
    }
  }
  $script:InvocationResult = 'completed'
  $script:InvocationExitCode = 0
  exit 0
} catch {
  $script:InvocationResult = 'error'
  $script:InvocationExitCode = 1
  try { $script:InvocationErrorCategory = [string]$_.CategoryInfo.Category } catch { $script:InvocationErrorCategory = 'unknown' }
  Write-Output "ERROR: $($_.Exception.Message)"
  exit 1
} finally {
  # v2.0.1 (P-3) last-resort watchdog: whichever way this process leaves (normal end,
  # --stop-on-error, a guard abort, an uncaught throw), a button IT is still holding is
  # released on the way out rather than left for the owner to drag. A press left by an
  # earlier process is caught by the entry watchdog above, not here.
  try {
  if (Get-LeftButtonDown) {
    # The JSON success stream stays parseable; the ordinary road keeps its original two lines.
    if ($script:Json) {
      [Console]::Error.WriteLine('WARNING: exiting with the left button still DOWN - releasing it now (P-3 watchdog)')
    } else {
      Write-Output 'WARNING: exiting with the left button still DOWN - releasing it now (P-3 watchdog)'
    }
    $exitReleaseReceipt = Release-Press $script:PressId 'process-exit' @() $Cmd
    if ($script:Json) {
      [Console]::Error.WriteLine([string]$exitReleaseReceipt)
    } else {
      Write-Output $exitReleaseReceipt
    }
  }
  } finally {
    try { Complete-DtxCallTracking $script:CallLease $script:InvocationResult $script:InvocationExitCode $script:InvocationErrorCategory }
    catch { [Console]::Error.WriteLine('WARNING: desktop tool call-history=unknown; command result is unchanged.') }
  }
}

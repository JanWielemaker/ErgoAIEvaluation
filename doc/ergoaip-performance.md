# Running ErgoAI-performance programs on ergoAIp

This note explains how to run the ErgoAI performance programs
(`ErgoEngine/ErgoAI-performance`) on ergoAIp (`ergoAIstudio2/ergoAIp`),
ErgoAI on SWI-Prolog.  They serve as workloads for performance analysis and
for tabling visualization.  What matters is that a program *runs to the
end*.  Wrong answers are acceptable; early aborts are not.

## The driver script

`scripts/ergoaip_perf.pl` runs each program in a fresh `swipl` process and
reports its verdict, its time and its inference count:

```
swipl scripts/ergoaip_perf.pl [options] [path ...]
```

A path is a `.flr`/`.ergo` file or a directory.  The default path is
`ErgoAI-performance/cyc150`.  Helper KBs, which other tests load, are
skipped.

| Option | Meaning |
|---|---|
| `--timeout=Secs` | wall-clock limit per program (default 600) |
| `--stack-limit=Sz` | Prolog stack limit per program (default `16g`) |
| `--table-space=Sz` | table space per program (default `8g`) |
| `--out=File` | also write the results as TSV, with the phase times as columns |
| `--in-process` | run every program in the script's own process |
| `--verbose` | show the engine's stderr |

A program that has a golden file (`<name>_old`) is run the way ErgoAI's
`test_one_file.sh` runs it: load the file, run `%test`, and compare the
sorted `temp` output with the golden file.  It uses ergoAIp's own
`src/golden.pl`.  Any other program is only loaded, which also runs its
`?-` queries.

For a golden program the run time is split into three phases:

- **convert:** ergo2p's translation of the top-level file;
- **load:** compilation, plus the file's own load-time `?-` queries.  For
  a `cyc150` program these load (and convert) the shared core KB.
- **solve:** `%test`.

Each result line ends with `load … s  solve … s`.  The TSV adds
`convert_ms`, `load_ms`, `solve_ms` and `solve_inferences`, and the
summary gives the totals.  A file without a golden file is a single load
phase.  The phases do not add up to the run time: what remains is
`golden.pl` releasing tables and comparing transcripts.  `--timeout`
also raises `golden.pl`'s own limits, `ERGOAIP_TIME_LIMIT` for `%test`
and `ERGOAIP_LOAD_TIME_LIMIT` for the load, which default to 60 s and
20 s.  The reported times include compilation, which ergoAIp does not
cache.

ergo2p's conversion from classic syntax *is* cached
(`ergoAIp/src/ergo2p/conv_cache.pl`), in `~/.cache/ergoaip/ergo2p` by
default.  An entry is reused while the converter's own sources and every
file the conversion read (the source and its `#include`s) are unchanged.
For a `cyc150` test, which converts the shared 1.8 MB core KB, this cuts a
run from 4.6 s to 1.7 s once the core has been converted once.  Set
`ERGOAIP_CONV_CACHE=off` to time the conversion as well, and
`ERGOAIP_CACHE_DIR=Dir` to move the cache.

The script sets `ERGOAIP_LIB_PATH` to `ErgoEngine/ErgoAI/{pkgs,ergo_lib}`
so that the packages ErgoAI ships can be found, such as the argumentation
theories.

## Results (2026-10-23, SWI-Prolog 10.1.19, ergoAIp unmodified)

| Program | Result | Time | Peak RSS | Exercises |
|---|---|---|---|---|
| `cyc150/kbq-cpttest-whatisduplicationstatusofchromosomeofcellinsphase-0` | passes | 44 s, 310M inferences | ~11 GB | tabling and argumentation theory (ogcle) |
| other `cyc150` programs (139) | complete; most miss 2 answers | ~5 s each | | mostly loading the shared 1.8 MB core KB |
| `cyc150/kbq-cpttest-cytokinesisisthedivisionofonecellintotwo-0` | not run (`convert_incomplete`) | | | |
| `compiletests/biologyKB` (6 MB) | loads | 321 s | 3.8 GB | compiler only, no queries |
| `compiletests/bio_carl` (14 MB) | loads | 199 s | 9.4 GB | compiler only |
| `compiletests/clarklog2` (10 MB) | loads | 59 s | 7.9 GB | compiler only |
| `compiletests/clarklog` (23 MB) | loads | 121 s | 18.5 GB | compiler only |
| `wine_ontology/wine2`, `UDF_tests/*` | load | < 1 s | | too small to be useful |

`CYC_tests` and `PaulH_tests` contain only helper files, so they have
nothing to run.

### The rewritten cyc150 corpus (with the full rule set)

The table above uses the original corpus, on which ergoAIp drops 77 of
the core rules.  The ErgoEngine branch `ergo301-performance` keeps all of
them.  On ergoAIp from `ergoAIstudio2` f5d6960 onward, every one of the
143 parseable programs runs to the end:

| | |
|---|---|
| passes | 44 |
| miss the same 2 golden lines | 99 |
| median time | 15 s, about 110M inferences |
| slowest program | 95 s |
| `whatisduplicationstatus` | passes in 13.5 s, 3.3 GB (load 1.7 s, solve 8.3 s) |

The branch also fixes the `:\` typo, so all 144 programs run;
`cytokinesisisthedivisionofonecellintotwo-0` misses the usual 2 lines.
This makes the whole suite usable as a tabling workload.  The submodule
is checked out at that branch, so the default run uses it:

```
swipl scripts/ergoaip_perf.pl
```

`cyc150-issues.md` explains what the rewrite and the ergoAIp fixes
address.

For tabling work, the best candidate is `whatisduplicationstatus`.  It is
the only large program that does real query work:

```
swipl scripts/ergoaip_perf.pl \
  ErgoEngine/ErgoAI-performance/cyc150/kbq-cpttest-whatisduplicationstatusofchromosomeofcellinsphase-0.flr
```

The `compiletests` KBs are good for profiling the ergo2p converter and the
compiler.  `bio_carl` defines `%test5`, which nothing calls.  Calling it
after loading would make `bio_carl` a large tabling workload as well.

## Solving all cyc150 cases against one loaded KB

`scripts/ergoaip_perf.pl` loads the core KB again for every program.
Users care about query time, so `scripts/ergoaip_cases.pl` instead loads
the core once and solves each case against it:

```
swipl --stack-limit=16g scripts/ergoaip_cases.pl [--threads=N] [--max=N] [--out=File] [dir]
```

**How it works:**

- Every cyc150 program is the same 18-line header followed by its own
  case: hypothesis facts, a few rules, `%pretest` and `%test`.  The
  argumentation theory, the `\overrides` rules and the `[+…]` loads of
  the core KB are all in the header.
- The driver loads the header once into module `kb`.
- It then runs each case as
  `snapshot((add the case to kb, run %pretest))`, so the case's facts and
  rules are discarded afterwards and no other case sees them.
- Tables are thread-private, so every case starts from empty tables, and
  with `--threads=N` cases run concurrently: the driver sets `cpu_count`
  for `concurrent_maplist/3`.
- A case passes when `%pretest` prints the `SUCCESS` line its golden file
  expects.
- The per-case report gives the time to **add** the case (convert,
  compile, install) and to **solve** it, with the solve's inferences.

**Results** (2026-10-23, ergoAIp from `ergoAIstudio2` be76d28 onward):

| | 1 thread | 8 threads |
|---|---|---|
| verdicts | 44 pass, 100 no answer | the same, case for case |
| core KB load (once) | 1.7 s | 1.7 s |
| add a case | about 0.03 s | |
| median solve | 9.4 s | 29 s |
| slowest solve | 61 s | 152 s |
| sum of solves | 2,196 s | 6,318 s |
| wall time | 3,360 s | 1,102 s |
| peak memory | 13.4 GB | 52.8 GB |

The verdicts match running each program in its own process.

**Memory, not cores, limits `--threads`.**  Each case builds up to several
GB of tables.  The 8-thread run exhausted a 62 GB workstation, which is
why its solves are three times slower, so its times are not usable.  Use
about 2–3 threads per 60 GB, or lower `--table-space` per thread.

**Overhead per case.**  In the single-threaded run about 8 s per case
falls outside the add and solve phases.  It is spent in
`abolish_all_tables` and the snapshot rollback after each case, and has
not been looked into yet.

**One ergoAIp fix was needed.**  A load inside a snapshot that is rolled
back leaves its predicate *declarations*, but not their clauses.
`ensure_called_pred/2` took such an empty declaration for a defined
predicate, so on the next case `cycIsa/2` had no clauses and every call to
it failed.  This is fixed in `ergoAIstudio2` be76d28.

## Why programs aborted early

With SWI-Prolog's default limits, every early abort came from resources,
not from bugs:

- **Stack overflow while loading the `compiletests` KBs.**
  `lexer_bridge:ergo_tokenize/2` tokenizes the *whole* file into one list
  before parsing.  For a 6–23 MB source, that list exceeds the default
  1 GB stack.  The backtrace shows `collect_tokens/2` about 100,000 levels
  deep, but those are call-level numbers, not live frames: last-call
  optimisation works fine there.  Converting the file one statement at a
  time would also fix the problem, and would reduce the peak memory.
- **`resource_error(private_table_space)`** in `whatisduplicationstatus`.
  The default table space is 1 GB.  With 8 GB the program passes.
- **`convert_incomplete`** in `cytokinesis`.  Line 1 of the source reads
  `:\ use_argumentation_theory{ogcle}`, a typo for `:-`.  ergoAIp refuses
  a file that has any parse failure.

The script's defaults (`--stack-limit=16g`, `--table-space=8g`) cover all
of these except the typo, which the `ergo301-performance` branch fixes.

## Correctness notes (not needed for completion)

Most `cyc150` programs miss two golden answers.  The corpus is written in
an old Flora-2/SILK dialect, and part of it does not parse in ErgoAI 3.01
or ergoAIp: bare `not G`, and `:- iriprefix p = "..."` without braces.
In nested `[+file]` loads, ergoAIp silently drops the statements it cannot
parse; 77 of the 332 statements in `core-rules.flr` are lost this way.
`isa(...)` used as an ordinary term also collides with ergoAIp's encoding
of `:`.

**The ergoAIp `whatisduplicationstatus` pass above depends on those
dropped rules.**  With the full rule set, evaluation does not terminate on
either engine.  `cyc150-issues.md` has the details and the other known
problems with this corpus.

An experimental patch got further: it added an `arg0/3` shim, fixed
`=..` with `hilog(F)` heads, and made late open-head bridges.  It has been
set aside, because it makes more rules fire, and on rewritten copies of the
corpus that led to table-space exhaustion.

## Comparison with XSB (ErgoAI 3.01)

Measured on the same machine with ErgoAI 3.01 (`ErgoEngine/ErgoAI`) on
XSB git 52953d05c.  Runs use `runergo` the same way `test_one_file.sh`
does.

| Program | XSB result | XSB time (wall / CPU) | XSB peak RSS | ergoAIp |
|---|---|---|---|---|
| `compiletests/biologyKB` | loads | 102 s / 98 s | 5.8 GB | 321 s, 3.8 GB |
| `compiletests/bio_carl` | loads | 94 s / 89 s | 6.7 GB | 199 s, 9.4 GB |
| `compiletests/clarklog2` | loads | 70 s / 66 s | 3.7 GB | 59 s, 7.9 GB |
| `compiletests/clarklog` | **timeout** (> 3600 s) | | | 121 s, 18.5 GB |
| `cyc150`, first run (compiles the core KB) | complete, miss 2 answers | 6 s / 5.1 s | ~0.9 GB | ~5 s each |
| `cyc150`, later runs (core KB cached) | complete, miss 2 answers | 1 s / 0.7 s | ~80 MB | ~5 s each |
| `cyc150/...cytokinesisisthedivisionofonecellintotwo-0` | syntax error (`:\` typo) | | | not run |

`clarklog` gets through the Ergo compiler in about 3 minutes.  The
compiler writes a 285 MB `clarklog.pl`.  XSB's own compilation of that file
into `.xwam` then makes no visible progress for the rest of the hour.

**The `cyc150` results are not comparable.** ErgoAI 3.01 does not compile
the original corpus.  For XSB it was run on a copy with the old SILK
dialect rewritten to 3.01 syntax, for example `and`/`or`/`not`/`neg`/`is`,
`iriprefix` without braces, `%mustDefine`, and the `\"urn:..."` IRIs.  On
that copy XSB derived nothing: `%pretest` failed, and every test missed the
same 2 answers in about 1 s.  This includes `whatisduplicationstatus`,
which does real work on ergoAIp and passes there.  On the rewritten copy,
ergoAIp exhausts its 8 GB table space in `cellwithcellplate-4`.  So
neither engine reproduces the goldens on a 3.01-clean corpus.

The two `cyc150` rows in the table were measured **before** two later
fixes to the rewrite.  The first fixes the reason XSB derived nothing,
a broken `isGround` builtin; the second translates a renamed XSB flag.
With both fixes the core rules fire, and `whatisduplicationstatus` no
longer terminates on XSB within 30 minutes.  The rows are therefore
stale; see `cyc150-issues.md`, issues 2–4.

The rewritten corpus is the ErgoEngine branch `ergo301-performance`.
On that branch ErgoAI-performance's own harness works again.  It runs
`runergo` with the ErgoAI-testsuite command sequence, and
`test_one_file.sh` prints load and solve time, CPU and wall, for each
program:

```
cd ErgoEngine/ErgoAI-performance
./testall.sh $PWD/../ErgoAI
```

To build ErgoAI against XSB, run `./makeergo nodocs <path-to>/bin/xsb` in
`ErgoEngine/ErgoAI`.  This needs a writable XSB tree, because it installs
`cc/*.so` into XSB's `config/.../lib`.  With GCC 15 or later, add
`-std=gnu17`, for example through a `gcc` wrapper on `PATH`, because
`cc/prolog2hilog.c` uses pre-C23 prototypes.

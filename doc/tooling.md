# Tooling: how to run things

This repository evaluates ErgoAI on SWI-Prolog.  This note lists the
tools and how to run them.  The results are in
[`ergoaip-performance.md`](ergoaip-performance.md) and
[`cyc150-issues.md`](cyc150-issues.md).

## Layout

| Path | What |
|---|---|
| `ergoAIstudio2/ergoAIp` | ergoAIp, ErgoAI on SWI-Prolog (submodule, branch `cache`) |
| `ErgoEngine` | ErgoAI itself, with `ErgoAI-performance` and `ErgoAI-testsuite` (submodule, branch `ergo301-performance`) |
| `scripts/` | the drivers described below |
| `doc/` | results and findings |

Everything below runs with SWI-Prolog 10.1.19 or later, as `swipl`.
`ergo301-performance` is the ErgoEngine branch with the cyc150 corpus
rewritten to ErgoAI 3.01 syntax, plus the knowledge additions of
`cyc150-issues.md`.

**Environment.**  The drivers set these themselves, and never override
a value you set:

- `ERGOAIP_LIB_PATH` is where ergoAIp finds the packages ErgoAI ships,
  such as `prettyprint` and the argumentation theories.  It defaults to
  `ErgoEngine/ErgoAI/pkgs:ErgoEngine/ErgoAI/ergo_lib`.
- `ERGOAIP_TIME_LIMIT` and `ERGOAIP_LOAD_TIME_LIMIT` are golden.pl's
  limits for `%test` and for the load.  `ergoaip_perf.pl` raises both to
  its `--timeout`.
- `ERGOAIP_CONV_CACHE=off` disables ergo2p's conversion cache, and
  `ERGOAIP_CACHE_DIR` moves it (default `~/.cache/ergoaip/ergo2p`).

**Limits.**  The cyc150 and compiletests programs need far more than
SWI-Prolog's default 1 GB: use a 16 GB stack and an 8 GB table space.
The two `subeventsofsphase` cases need a 40 GB table space and peak above
68 GB.

## Interactive use

### The Ergo listener

```
swipl -q ergoAIstudio2/ergoAIp/src/ergoaip_repl.pl -- file.flr ...
```

The listener loads the files into module `main`, then reads classic Ergo
queries, for example `ergo> ?X:person.` or `insert{…}.`.  Leave it with
`\end.`, `halt.` or Ctrl-D.

To explore a performance program, start the listener in the program's
directory, so its relative loads resolve, and raise the limits:

```
cd ErgoEngine/ErgoAI-performance/cyc150
swipl --stack_limit=16g --table_space=8g \
      ../../../ergoAIstudio2/ergoAIp/src/ergoaip_repl.pl -- kbq-cpttest-whataremitoticspindlesmadeof-0.flr
ergo> %pretest.
SUCCESS  : $CPTTest-WhatAreMitoticSpindlesMadeOf 0
```

### A Prolog toplevel after a run

`ergoaip_perf.pl -i` enters the Prolog toplevel when it is done, for
example to profile or to inspect tables.  With `--in_process` the engine
and the last KB are still loaded, and so are its tables: tables are
abolished before each program, not after it.  The KB lives in a generated
module, `perf_kb1` and so on (`gm1` and so on for a program with a golden
file).

```
swipl scripts/ergoaip_perf.pl -i --in_process ErgoEngine/ErgoAI-performance/UDF_tests/fib_like_test.flr
```

## `scripts/ergoaip_perf.pl`: time programs

```
swipl scripts/ergoaip_perf.pl [option ...] [file-or-directory ...]
```

Runs each program in a fresh `swipl` process and reports its verdict,
time, inferences and peak memory.  A directory stands for its `.flr` and
`.ergo` files, without recursion and without the helper KBs that the
tests load themselves.  Without a path, it runs `cyc150`.
`swipl scripts/ergoaip_perf.pl --help` lists the options:

| Option | Meaning |
|---|---|
| `--timeout=SECS` | wall-clock limit per program (default 600) |
| `--stack_limit=SIZE` | Prolog stack limit per program (default `16g`) |
| `--table_space=SIZE` | table space per program (default `8g`) |
| `--out=FILE` | also write the results as TSV, a row as soon as each program is done |
| `--resume` | with `--out`: keep an existing TSV, skip the programs it has a row for and append the others |
| `--in_process` | run every program in this process (faster to start, but KB state can leak between programs) |
| `-i`, `--interactive` | enter the Prolog toplevel when done |
| `-v`, `--verbose` | show the children's stderr |

A SIZE takes a `k`, `m` or `g` suffix.  The options can also be written
with dashes, as in `--table-space=40g`.

**Golden comparison.**  A program with a golden file (`<name>_old`) is
run the way ErgoAI's `test_one_file.sh` runs it: load, run `%test`, and
compare the sorted `temp` output with the golden file.  This uses
ergoAIp's `src/golden.pl`.  Any other program is only loaded, which also
runs its `?-` queries.  Its verdict is `loaded(N)`, where N is the
number of queries.

**Output.**  One line per program, then a summary.  Both are printed at
message level `information`, so they still appear with `swipl -q`.  The
verdicts:

| Verdict | Meaning |
|---|---|
| `pass` | the output matches the golden file |
| `diff(M,E)`, `listorder(M)` | M lines are missing and E are extra, or the lines are in a different order |
| `loaded(N)` | no golden file; the program loaded and its N queries ran |
| `load_error`, `run_error` | an exception |
| `out_of_memory` | a resource error, mostly an exhausted table space |
| `timeout` | `--timeout` was reached; the child was killed |
| `crashed(Status)` | the child died, e.g. `crashed(killed(9))` after an OOM kill |

**TSV columns:** `file`, `mode` (golden or load), `verdict`, `boot_ms`
(loading ergoAIp), `run_ms` (the rest of the child), `convert_ms`,
`load_ms`, `solve_ms` (the `%test` phase), `inferences`,
`solve_inferences` and `peak_rss_mb` (VmHWM).

Examples:

```
swipl scripts/ergoaip_perf.pl                                   # all of cyc150
swipl scripts/ergoaip_perf.pl --table-space=40g \
      ErgoEngine/ErgoAI-performance/cyc150/kbq-cpttest-subeventsofsphase-1
swipl scripts/ergoaip_perf.pl --timeout=3600 --out=compile.tsv \
      ErgoEngine/ErgoAI-performance/compiletests
```

## `scripts/ergoaip_perf_all.sh`: the full evaluation

```
nohup scripts/ergoaip_perf_all.sh &
```

Runs all 158 ErgoAI-performance programs through `ergoaip_perf.pl`.  It
uses a 1800 s timeout and a 40 GB table space, and writes:

- `~/.cache/ergoaip-perf/results.tsv`, a row per program;
- `~/.cache/ergoaip-perf/full.log`, the progress lines, ending with
  `DONE`.

The run takes about 2.5 hours.

- **Memory.**  The run is in a systemd scope, `ergoaip-perf-<pid>`,
  capped at 90 GB without swap.  Set `ERGOAIP_PERF_MEM` to change the
  cap.  `OOMPolicy=continue` makes an OOM kill only the child that ran
  out.  Its program is recorded as `crashed(killed(9))` and the run goes
  on.
- **Restart.**  The run uses `--resume`, so starting the script again
  continues where it stopped.  Delete `results.tsv` to start afresh.
  `ERGOAIP_PERF_DIR` moves the output directory.
- **Stop.**  Use `systemctl --user stop 'ergoaip-perf-*.scope'`.  Do not
  use `pkill swipl`, which also kills unrelated Prolog processes, such as
  an IDE or an agent's shell.

## `scripts/perf_report.py`: the report

```
python3 scripts/perf_report.py results.tsv [--title T] [--note N ...] > report.md
```

Turns a TSV from `ergoaip_perf.pl` into a Markdown report.  The report
has a summary by result class, a table per directory (pass count, median
and maximum solve time, total run time, median and maximum peak memory),
and a row per program.

The result classes are:

- `pass`;
- `loaded`: no golden file;
- `failed`: a mismatch or an exception;
- `out-of-memory`: a resource error or a crash;
- `timeout`.

`--note` adds a paragraph under the title, for example the setup and the
commits measured.

## `scripts/ergoaip_cases.pl`: cyc150 against one loaded KB

```
swipl --stack-limit=16g scripts/ergoaip_cases.pl [--threads=N] [--table-space=SIZE] \
      [--max=N] [--out=FILE] [cyc150-dir]
```

`ergoaip_perf.pl` loads the core KB again for every cyc150 program.
This driver loads it once, then solves each case in its own snapshot, so
it measures query time.  With `--threads=N`, cases run concurrently.
Memory limits the thread count, not the number of cores: each case can
build several GB of tables, so use about 2–3 threads per 60 GB.  The
details are in `ergoaip-performance.md`, section "Solving all cyc150
cases against one loaded KB".

## ergoAIp's own tests

These run in `ergoAIstudio2/ergoAIp`; see its `README.md`.

| Command | What |
|---|---|
| `./run_tests.sh` | the unit regression suites; exit status 0 if all pass |
| `./gold.sh [subtree]` | the golden scoreboard over ErgoAI-testsuite, in parallel shards (`NSH`, default 8) |
| `./run_suite.sh [testsuite-dir]` | the conversion, execution and golden scoreboards |
| `./diffs.sh` | one report per failing golden file, in `build/diffs/` |

Both default to the testsuite in `build/ErgoEngine/ErgoAI-testsuite`,
which `run_suite.sh` clones on first use.  To use this repository's copy
instead, set `TS=../../ErgoEngine/ErgoAI-testsuite` for `gold.sh`, or
pass that path to `run_suite.sh`.

## ErgoAI on XSB

To build ErgoAI 3.01 against XSB, run this in `ErgoEngine/ErgoAI`:

```
./makeergo nodocs <path-to>/bin/xsb
```

This needs a writable XSB tree.  With GCC 15 or later, add `-std=gnu17`,
for example through a `gcc` wrapper on `PATH`.  The performance suite's
own harness, on branch `ergo301-performance`, then prints load and solve
times per program:

```
cd ErgoEngine/ErgoAI-performance
./testall.sh $PWD/../ErgoAI
```

On XSB the cyc150 cases do not terminate.  The cause is in
`cyc150-issues.md`, issue 4.

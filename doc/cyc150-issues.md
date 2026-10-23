# Known issues with the cyc150 programs

The `cyc150` programs in `ErgoEngine/ErgoAI-performance` are 144 queries
against one shared knowledge base, `core_files/latest-tiny-kb.flr`, plus
a set of core rules.  They were written for an old Flora-2/SILK system.
Neither ErgoAI 3.01 on XSB nor ergoAIp runs them the way the golden files
expect.  This note records what is known so far, mostly from working on
`kbq-cpttest-whatisduplicationstatusofchromosomeofcellinsphase-0`.  For
how to run the programs and their timings, see `ergoaip-performance.md`.

## Summary

| # | Issue | Status |
|---|---|---|
| 1 | The corpus uses SILK syntax that ErgoAI 3.01 rejects | fixed on the ErgoEngine branch `ergo301-performance` |
| 2 | `isGround` is always false on ErgoAI 3.01, so the core rules never fire | fixed on the branch |
| 3 | The KB depends on an XSB flag that no longer exists | translated on the branch, does not help on its own |
| 4 | With the core rules firing, evaluation does not terminate | **ergoAIp: fixed**; **XSB: open** |
| 5 | ergoAIp silently drops part of the original core rules | moot on the branch |
| 6 | `cytokinesisisthedivisionofonecellintotwo-0` has a syntax error | fixed on the branch |
| 7 | ergoAIp lacked some XSB/HiLog primitives the core uses | fixed in ergoAIp |

**Current state on ergoAIp** (ErgoEngine branch `ergo301-performance`;
ergoAIp at `ergoAIstudio2` commit f5d6960):

- all 144 programs run to the end;
- 44 pass and 100 miss the same 2 golden lines;
- the median run is 15 s and the slowest 95 s;
- `whatisduplicationstatus` passes in 13.5 s at 3.3 GB.

**Current state on XSB:** `whatisduplicationstatus` still does not
finish within 30 minutes (issue 4).

## 1. The corpus is written in SILK, not ErgoAI 3.01

ErgoAI 3.01 does not compile the original files.  The ErgoEngine branch
`ergo301-performance` (commit c749610 on top of `main-github`) has the
corpus rewritten in place.  The submodule in this repository is checked
out at that branch.  The rewrite was done by a script that lived in
`scripts/modernize.sh` before this repository's commit that removed it.
The branch commit lists every change.  The main ones:

- **SILK connectives:** `and` → `,`,
  `or` → `;`, `not G`/`naf G` → `\naf G`, `neg G` → `\neg G`,
  `is` → `\is`.
- **Directives and options:**
  - `:- iriprefix p = "..."` gets braces;
  - `setsemantics{tabling(incremental)}` is commented out;
  - `equality(none)` becomes `equality=none`;
  - the invalid `optimize` options `class_expressions, main` are
    commented out.
- **Misspelled or removed names:**
  - the `silk` prefix is added where it was undefined;
  - `%mustDefine` becomes `mustDefine`;
  - `%writeln(...)@\io` becomes `writeln(...)@\io`;
  - `\baseType`/`\isTypeOf` become `\basetype`/`isTypeOf`.
- **Literals:**
  - `\"urn:..."` and `_"urn:..."` become `"urn:..."^^\iri`;
  - variable tags `@{?, X}` become `@{X}`.

## 2. `isGround` is always false on ErgoAI 3.01 (fixed)

`aux_files/silk-predicates_at_builtin.flr` defines

```
%silkb#isGround(?X) :- ground(?X).
```

Every other line of that file escapes its Prolog call with `@\prolog`;
this one does not.  In ErgoAI 3.01 a bare `ground/1` is an ordinary,
undefined Ergo predicate, so `isGround` is always false.  About 60 core
rules are guarded by it, so on XSB:

- no microtheory becomes visible;
- `isa('HYP-…', ?X)` is false;
- `%pretest` fails;
- every cyc150 test "finishes" in about 1 s and misses the same 2 golden
  answers;
- even the core's own sanity query in
  `core_files/rmt-removal-lookup-pos-1.flr` answers `No`.

ergoAIp treats a bare `ground/1` as a builtin
(`ergoaip_compiler.pl`, `builtin(ground/1)`), so the bug does not show
there.  The branch rewrites the line to `ground(?X)@\prolog`.

## 3. The KB relies on a renamed XSB flag

`aux_files/silk-predicates.flr` runs

```
?- set_prolog_flag(max_table_subgoal_depth, 100)@\prolog.
```

Old XSB used this flag to abstract tabled subgoals deeper than 100.  The
KB needs that to terminate (see issue 4).  The flag no longer exists:

- **Current XSB** calls it `max_table_subgoal_size` and needs a separate
  action flag.  The branch translates the line to

  ```
  ?- set_prolog_flag(max_table_subgoal_size, 100)@\prolog,
     set_prolog_flag(max_table_subgoal_size_action, abstract)@\prolog.
  ```

- **SWI-Prolog** silently creates an unused flag
  `max_table_subgoal_depth`, so ergoAIp never had the bound.  SWI does
  support `max_table_subgoal_size` with action `abstract`; that has not
  been tried yet.

The translation does not make the program terminate (issue 4).

## 4. Evaluation does not terminate (fixed on ergoAIp, open on XSB)

With issue 2 fixed, the core rules fire, and evaluation runs away.

**Cause on ergoAIp: Cyc's `isa/2` collides with ErgoAIp's encoding of
`:`.**  ergo2p turns the F-logic `a : b` into the term `isa(a, b)`, and a
user-written `isa(a, b)` is the very same term.  The compiler therefore
treats the corpus's `isa(...)` arguments as membership molecules and
pulls them out of their argument.  The source rule

```
forwardSentence(isa(?TERM, UnknownScalarInterval)) :-
    removalSentence(hypotheticalTerm(?TERM)),
    removalSentence(isa(?TERM, ScalarInterval)).
```

is installed as `forwardSentence(A) :- removalSentence(hypotheticalTerm(A)),
…`.  Each application of that rule wraps one more `hypotheticalTerm`
around its argument.  The branch renames `isa(` to `cycIsa(`
throughout the copy.  The rename is harmless on XSB, but it does not help
there: XSB's runaway has a different, still unknown, cause.

The original diagnosis follows.

**On XSB** (rewritten corpus, `whatisduplicationstatus`):

| Subgoal bound | Result |
|---|---|
| none | still inside the `rmt-removal-lookup-pos-1` sanity query after 30 min |
| 100, abstract | the same: timeout after 30 min |
| 10, abstract | abstraction kicks in, but abstracted goals reach a `\naf` in the argumentation theory unbound: `Floundering goal in tnot/1` on `rebuts(…hlPred(impPred)…)`; timeout after 10 min |

**On ergoAIp** (same rewritten corpus), the load finishes in about 2 s.
The sanity query fails quickly instead of looping.  `%test` ends in a
`run_error` after 354 s.  A histogram of the tables after 90 s of `%test`:

- 182,573 tables in total;
- 66,489 each of the argumentation theory's `holds/2` and `rcand/3`;
- about 2,100 variants each of `removalSentence`, `lookupSentence`,
  `assertedSentence`, `forwardSentence`, `sbhlSentence`,
  `imp#destructureFormula`, `imp#isAtomicSentence`, … over
  `natFunction(…)` and `hypotheticalTerm(…)`;
- 27,639 such `natFunction`/`hypotheticalTerm` variants in all.

Their arguments are an ever-deeper nesting,
`hypotheticalTerm(hypotheticalTerm(…))`; the largest was 21,279 cells
after 90 s.  That unbounded term growth is the non-termination.  The
argumentation theory then multiplies it, with one `holds/2` table per
literal.

**Was unknown (now found for ergoAIp, see above):** which rule builds the nested terms.  The candidates are
the rules that construct formulas from unbound parts, in
`core_files/core-rules.flr`:

- `operatorFormulas/2` and `imp#destructureFormula/3`
  (`?TERM =.. [hilog(?R)|?ARGS]`);
- `gpLookupSentence/1`;
- `transformationSentence/1`;
- `removalSentence(natFunction(?NART, ?F))`.

Finding the producer would tell whether this is an artefact of the
modernized corpus or behaviour the original SILK system cut off with its
depth bound.

**Probing tips:**

- `setruntime{timeout(repeating(N, showgoals{}))}` crashes XSB 52953d05c.
  It first tries to start Java, then hits a memory violation in
  `get_sdg_subgoal_info/1`.
- A Prolog handler, `timeout(repeating(N, probe(?)@\prolog))`, works but
  only sees the top-level goal.
- On ergoAIp, take the table histogram from inside the running
  evaluation, with `alarm/4` and `current_table(M:Goal, _)` per module.
  A `call_with_time_limit/2` timeout discards the incomplete tables first,
  so it shows nothing.

## 5. ergoAIp drops part of the original core rules

On the **original** corpus, ergoAIp passes `whatisduplicationstatus` in
44 s.  That is not evidence that it runs the KB correctly.  In nested
`[+file]` loads, ergoAIp silently drops statements it cannot parse; 77 of
the 332 statements in `core_files/core-rules.flr` are lost this way, mostly
those that use the SILK connectives.  Without them the rules that run away
in issue 4 cannot fire.  Other ergoAIp mismatches on the original corpus:

- `isa(...)` used as an ordinary term collides with ergoAIp's encoding of
  `:`;
- most tests miss the same 2 golden answers.

On the modernized corpus, ergoAIp exhausts its 8 GB table space in
`cellwithcellplate-4`, and `whatisduplicationstatus` fails as described
in issue 4.

## 6. Syntax error in one test

Line 1 of `kbq-cpttest-cytokinesisisthedivisionofonecellintotwo-0.flr`
reads `:\ use_argumentation_theory{ogcle}`, a typo for `:-`.  Both
engines reject the original file: ergoAIp with `convert_incomplete`, XSB
with a syntax error.  The branch corrects it.  On ergoAIp the program
then runs to the end, missing the usual 2 golden lines (load 4.7 s, solve
10.6 s).

## 7. ergoAIp lacked some primitives the core uses (fixed)

Once the `isa` collision was out of the way, the core rules needed four
fixes in ergoAIp (`ergoAIstudio2` commit f5d6960):

- **`arg0/3` under `@\prolog`.**  This is XSB's HiLog `arg/3`: index 1 is
  the functor, index K+1 the K-th argument.  The core reads a formula's
  relation with it.
- **`=..` on a HiLog term.**  Decomposition gives `[hilog(F)|Args]`, as the
  manual specifies.  Construction needs a proper list and fails
  otherwise.
- **Compound HiLog functors.**  `TypeCapableFn(behaviorCapable)(?X, …)`
  must be built as `flapply(F, Args…)`; calling Prolog's `=..` raised a
  type error, which aborted four programs.
- **Late open-head bridges.**  A rule with an open functor, like
  `?P(?A1, ?A2) :- …`, must also cover predicates that appear only after
  the rule was installed.

ergoAIp's unit suites and its golden smoke set are unchanged by these
fixes.

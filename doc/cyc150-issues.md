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
| 4 | With the core rules firing, evaluation does not terminate | **ergoAIp: fixed**; **XSB: cause found, not fixed** |
| 5 | ergoAIp silently drops part of the original core rules | moot on the branch |
| 6 | `cytokinesisisthedivisionofonecellintotwo-0` has a syntax error | fixed on the branch |
| 7 | ergoAIp lacked some XSB/HiLog primitives the core uses | fixed in ergoAIp |
| 8 | `\naf isGround(?X)` guards are delayed until ?X is bound | fixed on the branch (`\+`), plus an ergoAIp fix |
| 9 | Every symbol counts as a `CharacterString` | fixed on the branch |
| 10 | Nested open HiLog applications never meet stored sentences | fixed in ergoAIp |
| 11 | Two cases exhaust an 8 GB table space | pass with 40 GB in the case driver; `%test` needs more |
| 12 | Open HiLog applications in rule-head arguments never match | fixed in ergoAIp |
| 13 | 12 cases need knowledge the KB does not contain | 10 fixed on the branch; 2 left (equality substitution) |

**Current state on ergoAIp** (ErgoEngine branch `ergo301-performance`
e550962; ergoAIp at `ergoAIstudio2` b07b4ae):

- all 144 cases run;
- **140 pass** with `scripts/ergoaip_cases.pl` (the core loaded once,
  each case solved in a snapshot, 40 GB table space), including the two
  `subeventsofsphase` cases (issue 11);
- the full per-process run, `ergoaip-perf-report.md`, also has **140
  pass**.  There the two `subeventsofsphase` cases exhaust the 40 GB
  table space instead, and `amitotictissuehasnocellsinthecellcycle-0`
  passes;
- the two `mpfdeactivatingenzyme` cases miss 2 answers: they need
  equality substitution (issue 13);
- run on its own, a typical case solves in about 34 s at a 14 GB peak.

44 cases passed before issues 8–10 were fixed, 102 before issue 12, and
131 before the knowledge additions of issue 13.

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

### The cause on XSB: the argumentation theory over meta-level sentences

XSB's runaway is not term growth.  With `max_table_subgoal_size` at 30
and the action `error`, nothing trips in 10 minutes.  Instead it is
breadth that never completes.  These measurements leave
`rmt-removal-lookup-pos-1` out of the core loads and keep its
`queryMt(EverythingPSC)` fact, so the core loads and `%pretest` runs.
XSB's `statistics/0`, printed every 40 s from a timer, shows:

| Time | Distinct subgoals | Incomplete tables | Answers inserted | Memory |
|---|---|---|---|---|
| 40 s | 50,591 | 46,962 (in 6 SCCs) | 2,892 | 0.42 GB |
| 80 s | 62,944 | 59,315 | 2,892 | 0.46 GB |
| 120 s | 70,957 | 67,328 | 2,892 | 0.69 GB |

New subgoals keep appearing, a few hundred per second, but no new
answers.  Almost every table stays incomplete, in a handful of huge
recursive components that never complete.

A dump of the first 2,000 incomplete subgoals (method below) shows what
they are:

- About 40% are tables of the argumentation theory `ogcle`:
  `candidate`, `rebuts`, `beater` and `tabled_naf_call`.  Every core rule
  is tagged (`@{"urn:uuid:…"}`), hence defeasible, so every derived
  literal is checked through the theory.
- The literals are mostly **meta-level sentences about the KB's own
  predicates**: `hlPred(P)`, `impPred(P)`, `backchainForbidden(P)`,
  `transformationPredicate(P)`, `removalPredicate(P)` and their `not(…)`
  forms.  `P` ranges over the core's implementation predicates
  (`imp#destructureFormula`, `imp#isAtomic`, `imp#decidableAsent`, …).
- `imp#destructureFormula` (the `?TERM =.. [hilog(?R)|?ARGS]` helper)
  alone accounts for 681 entries.

The source is the open-functor rules of `core-rules.flr`, such as
`?P(?A1, ?A2, ?A3) :- imp#transformationPredicate(?P),
transformationSentence(?P(…))`.  In ErgoAI every literal is a HiLog
application, so these heads also match calls to the core's helper
predicates: every `destructureFormula` call becomes a possible conclusion
of the generic rules.  That conclusion is checked through the
argumentation theory, which calls `destructureFormula` again.  The KB
means to keep implementation predicates out, with its `impPred(…)` facts
and `\naf hlPred(?P)` guards, but those guards go through the
argumentation theory too.

ergoAIp evaluates the same rules in about 9 s, so its argumentation layer
does much less work here.  Whether it gives up something XSB has to do is
open.  Until that is known, XSB and ergoAIp timings on cyc150 do not
measure the same computation.

**Inspecting XSB's tables during this evaluation crashes XSB** (memory
violation, XSB 52953d05c) once there are more than about 30,000 incomplete
subgoals.  All three routes crash: `showgoals{}`, `get_calls/3` from a
timer handler, and `get_sdg_info/1` from a tripwire handler.  At 2,000
subgoals the tripwire route works, and that produced the dump above:

```
?- set_prolog_flag(max_incomplete_subgoals, 2000)@\prolog,
   set_prolog_flag(max_incomplete_subgoals_action, custom)@\prolog.
```

with, in a consulted `.P` file:

```
:- assert((max_incomplete_subgoals_user_handler :- my_dump)).
my_dump :- get_sdg_info(L), ( member(E, L), writeq(E), nl, fail ; true ), abort.
```

`max_incomplete_subgoals_user_handler/0` is already dynamic in `usermod`,
so it must be `assert`ed; a file that defines it as a static predicate is
refused.

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

## 8. `\naf isGround(?X)` is delayed (fixed)

The SILK original writes `not %silkb#isGround(?X)` to mean "?X is still
unbound *here*", a test of the current binding state.  It uses this to
choose between rule variants by which arguments are bound, as in
`core-rules.flr` line 273:

```
removalSentence(genls(?SPEC, ?GENL)) :- %silkb#isGround(?SPEC)@builtin,
    \naf %silkb#isGround(?GENL)@builtin, sbhlSentence(genls(?SPEC, ?GENL)).
```

The SILK-to-3.01 rewrite turned that into `\naf`.  Ergo delays a `\naf`
until its variables are bound; at that point `isGround` is true and the
guard fails.  The 36 guards of this form disabled every rule variant meant
for an unbound argument.  ErgoAI's immediate negation is `\+`, so the
branch now writes `\+ %silkb#isGround(?X)@builtin`.

That also needed an ergoAIp fix: ergoAIp compiled `\+` exactly like
`\naf`, delayed.  ErgoAI compiles it as Prolog's negation (`PRPLGNAF`).
On the oracle, `p(1). r(?X) :- \+ p(?X), ?X = 2.` answers No while the
`\naf` version answers `?X = 2`; ergoAIp now does the same.

## 9. Every symbol counts as a `CharacterString` (fixed)

`aux_files/silk-predicates_at_builtin.flr` defined
`%silkb#isString(?X) :- atom(?X)@\plg.`  In ErgoAI every symbol is an
atom, so the core derived `cycIsa(Bacterium, CharacterString)`.  It also
derived `List` and `Individual`, but not `Collection`.  `genls` requires
`Collection` arguments (`argIsa`), so the core's well-formedness check
(`imp#wffRejectedSentence`) rejected `genls(Bacterium, ProkaryoticCell)`.
The derived `not(genls(…))` sentence then defeated every positive `genls`
conclusion.  The file already carried the right test, commented out:
`\string[isTypeOf(?X)]@\basetype`.  The branch uses that one.

The branch also makes `imp#numberCodes` and `imp#atomCodes` fail instead
of throwing.  The generic open-functor rules call them with arbitrary
arguments (`number_codes(?N, implies)`), which raised a type error and
aborted the case.

## 10. Nested open HiLog applications (fixed in ergoAIp)

`core-rules.flr` writes rules such as

```
\neg ?P(?ARG1, ?ARG2) :- imp#removalPredicate(?P),
    removalSentence(not(?P(?ARG1, ?ARG2))).
```

In ErgoAI `?P(?A, ?B)` with `?P = genls` *is* the term `genls(?A, ?B)`.
ergoAIp compiles an application with a variable functor to
`flapply(?P, ?A, ?B)`.  It already rebuilt one that is a direct argument
of a literal, once `?P` is bound, but not one nested inside another term.
`not(flapply(genls, …))` then matched no stored sentence, the KB's
closed-world rules for `not(…)` held, and the negative conclusion defeated
the positive one.  ergoAIp now rebuilds nested applications too, in the
arguments of ordinary KB literals only.

**How these were found.**  Load a failing case and run raw Prolog goals
against the compiled module with ergoAIp's `tests/dbg.pl`:

- `ergo_gclp:rcand(kb, R, L)` finds the candidate rules for a literal;
- `ergo_gclp:rdefeats(kb, R2, L2, R, L)` finds what defeats them;
- running each candidate's `'$cand'/2` body names the failing step.

The `imp` prefix is not declared in ad-hoc queries, so append probe rules
to a copy of the case file instead.

## 11. Two cases exhaust the table space (resolved by a larger limit)

`subeventsofsphase-1` and `opensubquerykbctestfn-cpttest-subeventsofsphase-0`
need more than an 8 GB table space.  Before the knowledge additions of
issue 13 (ErgoEngine b9a8792), both passed with
`scripts/ergoaip_perf.pl --table-space=40g`, each in about 300 s wall
(180 s solve, 1.6 G inferences) at a 68 GB peak.

With the additions (e550962) they do more work.  The case driver,
which solves `%pretest` once, still passes both with a 40 GB table
space.  In the per-process run, however, both exhaust the 40 GB at an
84 GB peak, after about 220 s solve and 2.0 G inferences.  That run uses
`%test`, which runs `%pretest` twice, with `mustDefine` on and then off.
Whether a larger table space suffices has not been tried: the machine
has 109 GB.

## 12. Open HiLog applications in rule heads (fixed in ergoAIp)

The head-side twin of issue 10.  The core's transitive-via-argument rules
are written

```
tvaSentence(?P(?NEW1, ?ARG2, ?ARG3)) :- imp#tvaPredicate(?P), …
```

ergoAIp stored that head argument as `flapply(?P, …)`.  A call naming the
concrete `phasesAlternateInCycleType(…)` could never unify with it, so no
`transitiveViaArg`/`transitiveViaArgInverse` inference ever happened.  Now
the head argument becomes a variable, and the application is bound to it in
front of the body.  This applies to strict and defeasible rules, and not
inside reifications.  It took the case driver from 102 to 129 passing
cases, but the total solve time roughly tripled, because those inferences
now run.

## 13. Twelve cases need knowledge the KB lacks (10 fixed on the branch)

All twelve ask a `\neg` query.  Each case file records Cyc's proof as
`proof(N, K)` facts.  Steps 0–999 are the lemmas of the derivation and
steps from 2000 on are support sentences.  A probe that asks each step,
`pstep(?K) :- proof(?_N, ?K)`, appended to a copy of the case, shows which
step cannot be derived.  (A step written `not(S)` can never be asked this
way; see the third point below.)

What was missing, and what the branch (ErgoEngine `ergo301-performance`,
the commit after b9a8792) adds:

- **`negationPreds`/`negationInverse('partwiseDisjoint-TypeType',
  properSubEventTypes)`**, a support in nine of the proofs.  The cases
  state `negationPreds('partwiseDisjoint-TypeType', 'shareParts-TypeType')`
  as background, and the core derives a `negationPreds` sentence from a
  `genlPreds` link (core-rules lines 117–126).  The link was missing.
  `latest-tiny-kb.flr` now states:
  - `genlPreds(properSubEventTypes, 'shareParts-TypeType')`;
  - `'shareParts-TypeType'` is symmetric, which gives the inverse form;
  - `'partwiseDisjoint-TypeType'` is symmetric, as sibling cases state but
    `meiosisandfertilizationdontalternateinwhichcycle-0` does not;
  - `superEventTypes` is reflexive (`superEventTypes(AsexualLifeCycle,
    AsexualLifeCycle)` is a support of two proofs).
- **A negative `genls` from disjointness**, needed by the three
  `whichligandtypehasareceptorinthecytoplasm` cases.  It mirrors the
  core's existing `not(cycIsa)` rule:
  `sbhlSentence(not(genls(?S, ?G)))` holds when `?S` is under some `?A`,
  `?A` is disjoint with `?B`, and `?B` is `?G` or above it.
- **`not(S)` in the cases' own rule bodies is now `\neg (S)`** (69 files).
  In ErgoAI `not(S)` in a body is the ordinary predicate `not/1` (checked
  on XSB), and this KB declares `not` an `hlPred`, so such a literal never
  held.  The core derives negative literals through its `\neg ?P(…)`
  rules.  Neither change helps on its own; with both, ten of the twelve
  cases pass, and no other case changes.

**Left for the Ergo developers: `mpfdeactivatingenzymemostlikelydoeswhat-1`
and `-2`.**  Their proofs substitute equal terms.  Support 2004 is
`equals(EukaryoticCellCycle, SingleIterationThroughCycleTypeFn(
TheEukaryoticCellCycle))`, which ergoAIp derives.  The step needs
`'partwiseDisjoint-TypeType'(CDKDegradation, EukaryoticCellCycle)`, carried
over from the stated
`'partwiseDisjoint-TypeType'(CDKDegradation,
SingleIterationThroughCycleTypeFn(TheEukaryoticCellCycle))`.  The core
has no equality reasoning at all: `equals` and `rewriteOf` are only
declared `hlPred`.  Adding substitution of equals is a design decision for
the KB, not a missing fact.

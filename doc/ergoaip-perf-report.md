# ergoAIp on ErgoAI-performance: full report

All 158 test programs of `ErgoEngine/ErgoAI-performance`, measured 2026-10-27 on SWI-Prolog 10.1.19 (swipl-devel 0612809c6), ErgoEngine e550962 (branch `ergo301-performance`), ergoAIstudio2 49eacd8 (branch `cache`).  Produced by `scripts/ergoaip_perf.pl` and `scripts/perf_report.py`; [tooling.md](tooling.md) explains how to run them.

**Setup.**  One fresh `swipl` process per program, run one after the other on an otherwise idle machine: 1800 s timeout, 16 GB stack, 40 GB table space, in a systemd scope capped at 90 GB without swap.  The ergo2p conversion cache was warm.  The ergoAIstudio2 update changed the converter, which invalidates the cache, so the seven load-only programs that were converted cold in the full run (the four `compiletests`, `CYC_tests/test0/load{,2}` and `PaulH_tests/test1/load3`) were re-run afterwards; the table has the re-runs.

## Changes since the previous run (2026-10-24/25)

- **SWI-Prolog trie memory.**  Three swipl-devel commits: a completed trie is compiled directly into its clause after a sizing pass, without a growing temporary buffer and a copy (1dac533c2); the answer nodes of compiled incremental tables are discarded and rebuilt from the clause only when needed (14ba39be3); and answers deleted by incremental reevaluation are pruned (10205aec9).  ergoAIp declares all its tables incremental, so these apply to every table.
- **ergoAIstudio2** b07b4ae → 49eacd8: undefined KB predicates are stubbed through `user:exception/3`, calls to the `\opposes` stores are recorded as dependencies, and loading is free of warnings.
- **Results.**  The two `subeventsofsphase` cases, out of memory before, now pass: 180 s at a 54 GB peak instead of exhausting the table space at 84 GB.  Over the other 142 cyc150 cases, solve time drops by a median of 14% (11–24%) and peak memory by 31% (31–35%); the median case solves in 28.7 s (was 33.7 s) at a 9.8 GB peak (was 14.3 GB).  Load times and the load-only programs are unchanged.
- **Run time is not comparable.**  The previous run abolished the tables *after* each program and counted that in *run*, about 25 s for a large cyc150 case; `ergoaip_perf.pl` now abolishes them before a program (91f75fe).  Compare *load*, *solve* and *peak* instead.

**Notes.**

- `compiletests`, `CYC_tests/test0`, `PaulH_tests/test1`, `UDF_tests` and `wine_ontology` have no golden output.  *loaded* means that the program loaded and its queries ran without error.
- The two `mpfdeactivatingenzyme` cases miss 2 answers.  They need equality substitution; see `cyc150-issues.md`.

## Summary

| Result | Files |
|---|---|
| pass | 142 |
| loaded | 14 |
| solved | 0 |
| failed | 2 |
| out-of-memory | 0 |
| timeout | 0 |
| **total** | **158** |

| Directory | Files | Pass | Median solve s | Max solve s | Sum of run times s | Median peak MB | Max peak MB |
|---|---|---|---|---|---|---|---|
| CYC_tests/test0 | 3 | 0 | 0.0 | 0.0 | 3.5 | 107 | 126 |
| PaulH_tests/test1 | 4 | 0 | 0.0 | 0.0 | 7.6 | 57 | 1513 |
| UDF_tests | 2 | 0 | 0.0 | 0.0 | 0.1 | 27 | 27 |
| compiletests | 4 | 0 | 0.0 | 0.0 | 532.3 | 1028 | 1582 |
| cyc150 | 144 | 142 | 28.7 | 180.3 | 4751.6 | 9789 | 53896 |
| wine_ontology | 1 | 0 | 0.0 | 0.0 | 0.3 | 69 | 69 |

## All test files

Times are wall clock in seconds; *run* is the whole child process after engine boot (convert + load + solve + comparison).  *Peak* is the process's peak resident set size (VmHWM).

| File | Result | Verdict | Load s | Solve s | Run s | Solve inferences | Peak MB |
|---|---|---|---|---|---|---|---|
| CYC_tests/test0/load.flr | loaded | `loaded(3)` | 1.8 | 0.0 | 1.8 | 0 | 107 |
| CYC_tests/test0/load2.flr | loaded | `loaded(4)` | 1.7 | 0.0 | 1.7 | 0 | 126 |
| CYC_tests/test0/load_production.flr | loaded | `loaded(3)` | 0.0 | 0.0 | 0.0 | 0 | 27 |
| PaulH_tests/test1/load.flr | loaded | `loaded(2)` | 0.7 | 0.0 | 0.7 | 0 | 69 |
| PaulH_tests/test1/load2.flr | loaded | `loaded(2)` | 6.1 | 0.0 | 6.1 | 0 | 1513 |
| PaulH_tests/test1/load3.flr | loaded | `loaded(13)` | 0.4 | 0.0 | 0.4 | 0 | 45 |
| PaulH_tests/test1/load_production.flr | loaded | `loaded(2)` | 0.3 | 0.0 | 0.3 | 0 | 45 |
| UDF_tests/fib_like_test.flr | loaded | `loaded(1)` | 0.0 | 0.0 | 0.0 | 0 | 27 |
| UDF_tests/fib_like_test2.flr | loaded | `loaded(1)` | 0.0 | 0.0 | 0.0 | 0 | 27 |
| compiletests/bio_carl.flr | loaded | `loaded(1)` | 176.5 | 0.0 | 176.5 | 0 | 831 |
| compiletests/biologyKB.flr | loaded | `loaded(1)` | 274.7 | 0.0 | 274.7 | 0 | 678 |
| compiletests/clarklog.flr | loaded | `loaded(0)` | 52.7 | 0.0 | 52.7 | 0 | 1582 |
| compiletests/clarklog2.flr | loaded | `loaded(0)` | 28.4 | 0.0 | 28.4 | 0 | 1225 |
| cyc150/kbq-cptevaluationtest-howtoendcellresponsetosignalwithphosphorylationcascade-0.flr | pass | `pass` | 1.7 | 30.0 | 31.8 | 297,201,279 | 10169 |
| cyc150/kbq-cpttest-acellinsphaseisactivelydoingwhat-0.flr | pass | `pass` | 1.8 | 33.1 | 34.9 | 320,584,414 | 10838 |
| cyc150/kbq-cpttest-acellinthecellcycleisactivelydoingwhat-0.flr | pass | `pass` | 1.8 | 29.7 | 31.5 | 293,099,471 | 10002 |
| cyc150/kbq-cpttest-allofthefollowingoccurduringmeiosisiexcept-2.flr | pass | `pass` | 1.7 | 28.4 | 30.1 | 286,940,337 | 9716 |
| cyc150/kbq-cpttest-allofthefollowingoccurduringmeiosisiexcept-3.flr | pass | `pass` | 1.7 | 28.6 | 30.3 | 286,036,312 | 9803 |
| cyc150/kbq-cpttest-amitotictissuehasnocellsbetweensphaseandg2phase-0.flr | pass | `pass` | 1.7 | 29.3 | 31.0 | 290,995,839 | 10007 |
| cyc150/kbq-cpttest-amitotictissuehasnocellsinthecellcycle-0.flr | pass | `pass` | 1.7 | 28.1 | 29.9 | 282,336,288 | 9764 |
| cyc150/kbq-cpttest-anaphaseinvolvesachangeinnumberofchromosomes-0.flr | pass | `pass` | 1.7 | 32.2 | 34.0 | 313,715,882 | 10782 |
| cyc150/kbq-cpttest-aneventthatinterfereswithspindleformationisonethatinterfereswiththemcheckpoint-0.flr | pass | `pass` | 1.7 | 28.5 | 30.2 | 289,791,561 | 9811 |
| cyc150/kbq-cpttest-arebacteriaprokaryotes-2-0.flr | pass | `pass` | 1.7 | 28.2 | 30.0 | 286,148,746 | 9684 |
| cyc150/kbq-cpttest-arethediploidandmonoploidnumbersthesameinhumans-0.flr | pass | `pass` | 1.7 | 28.7 | 30.4 | 293,021,151 | 9756 |
| cyc150/kbq-cpttest-cancercellsdontexhibitdensitydependentinhibition-0.flr | pass | `pass` | 1.7 | 28.5 | 30.3 | 288,004,059 | 9773 |
| cyc150/kbq-cpttest-canparameciamovethemselves-0.flr | pass | `pass` | 1.7 | 28.3 | 30.1 | 283,849,690 | 9810 |
| cyc150/kbq-cpttest-canspermcellsmovethemselves-0.flr | pass | `pass` | 1.7 | 28.6 | 30.3 | 289,418,749 | 9778 |
| cyc150/kbq-cpttest-causationamongscenesincellsignalingsubscript-pathwaytype-0.flr | pass | `pass` | 1.7 | 30.1 | 31.9 | 297,647,382 | 9827 |
| cyc150/kbq-cpttest-cellwithcellplateiswhat-0.flr | pass | `pass` | 1.7 | 28.8 | 30.6 | 287,875,908 | 9943 |
| cyc150/kbq-cpttest-cellwithcellplateiswhat-1.flr | pass | `pass` | 1.7 | 29.3 | 31.0 | 287,875,908 | 9945 |
| cyc150/kbq-cpttest-cellwithcellplateiswhat-4.flr | pass | `pass` | 1.7 | 28.8 | 30.5 | 286,793,347 | 9939 |
| cyc150/kbq-cpttest-centromeresjoinsisterchromatids-0.flr | pass | `pass` | 1.7 | 28.3 | 30.0 | 286,606,423 | 9952 |
| cyc150/kbq-cpttest-changesinmpfactivitycorrelatewithwhat-0.flr | pass | `pass` | 1.8 | 28.8 | 30.6 | 290,182,214 | 9797 |
| cyc150/kbq-cpttest-changesinmpfactivitycorrelatewithwhat-3.flr | pass | `pass` | 1.8 | 31.4 | 33.2 | 304,503,644 | 10456 |
| cyc150/kbq-cpttest-chromosomesarechromatin-0.flr | pass | `pass` | 1.7 | 28.6 | 30.3 | 289,437,349 | 9730 |
| cyc150/kbq-cpttest-chromosomesarechromatin-1.flr | pass | `pass` | 1.7 | 28.3 | 30.0 | 289,437,349 | 9731 |
| cyc150/kbq-cpttest-chromosomesarechromatin-2.flr | pass | `pass` | 1.7 | 28.4 | 30.1 | 289,437,349 | 9729 |
| cyc150/kbq-cpttest-chromosomesarechromatin-4.flr | pass | `pass` | 1.7 | 29.2 | 30.9 | 294,215,995 | 9794 |
| cyc150/kbq-cpttest-crossingoveroccursduringwhat-0.flr | pass | `pass` | 1.7 | 28.1 | 29.8 | 280,382,212 | 9721 |
| cyc150/kbq-cpttest-cytokinesisisthedivisionofonecellintotwo-0.flr | pass | `pass` | 1.8 | 29.7 | 31.6 | 298,433,782 | 10118 |
| cyc150/kbq-cpttest-cytokinesisistheseparationofthecytoplasm-0.flr | pass | `pass` | 1.7 | 30.8 | 32.6 | 303,495,021 | 10118 |
| cyc150/kbq-cpttest-cytokinesisistheseparationofthecytoplasmintotwo-0.flr | pass | `pass` | 1.7 | 31.2 | 32.9 | 308,753,663 | 10477 |
| cyc150/kbq-cpttest-cytokinesisstartsafteranaphaseendsincellcycle-0.flr | pass | `pass` | 1.7 | 28.8 | 30.5 | 289,553,539 | 9836 |
| cyc150/kbq-cpttest-cytokinesisstartsafteranaphaseendsinmphase-0.flr | pass | `pass` | 1.7 | 28.8 | 30.6 | 287,824,266 | 9811 |
| cyc150/kbq-cpttest-daughtercellsofcellcyclearenotfusedinfertilization-0.flr | pass | `pass` | 1.7 | 28.1 | 29.8 | 285,013,562 | 9685 |
| cyc150/kbq-cpttest-daughtercellsofcellcyclearenotfusedinfertilization-02-0.flr | pass | `pass` | 1.7 | 28.0 | 29.8 | 285,013,562 | 9687 |
| cyc150/kbq-cpttest-diploidnumberfordogs-0.flr | pass | `pass` | 1.7 | 28.6 | 30.3 | 289,947,889 | 9833 |
| cyc150/kbq-cpttest-diploidnumberfordogs-2.flr | pass | `pass` | 1.7 | 28.5 | 30.2 | 289,959,262 | 9833 |
| cyc150/kbq-cpttest-duplicatedchromosomeconsistsof2chromatids-hyp-1.flr | pass | `pass` | 1.7 | 29.1 | 30.8 | 294,503,565 | 9815 |
| cyc150/kbq-cpttest-duringanaphaseiiwhathappens-0.flr | pass | `pass` | 1.7 | 30.0 | 31.7 | 301,726,902 | 10045 |
| cyc150/kbq-cpttest-duringwhatdochromosomesreplicate-3.flr | pass | `pass` | 1.7 | 28.3 | 30.1 | 282,269,012 | 9732 |
| cyc150/kbq-cpttest-duringwhatdoesaduplicatedchromosomeplayarole-0.flr | pass | `pass` | 1.7 | 28.2 | 29.9 | 285,625,035 | 9701 |
| cyc150/kbq-cpttest-duringwhatdoesaduplicatedchromosomeplayarole-1.flr | pass | `pass` | 1.7 | 28.2 | 30.0 | 285,646,131 | 9706 |
| cyc150/kbq-cpttest-duringwhatdoesaspindleforminahaploidcell-1.flr | pass | `pass` | 1.7 | 31.3 | 33.0 | 315,065,921 | 10032 |
| cyc150/kbq-cpttest-duringwhichofthefollowingdoesdnareplicate-0.flr | pass | `pass` | 1.8 | 29.0 | 30.8 | 290,140,455 | 9739 |
| cyc150/kbq-cpttest-eukaryoticcellcycleiterationsdontcontaincdkcreationevents-0.flr | pass | `pass` | 1.7 | 28.0 | 29.8 | 281,856,373 | 9747 |
| cyc150/kbq-cpttest-eukaryoticcellcycleiterationsdontcontaincdkdestructionevents-0.flr | pass | `pass` | 1.7 | 28.3 | 30.0 | 281,856,373 | 9751 |
| cyc150/kbq-cpttest-firstsignofprophase-1-0.flr | pass | `pass` | 1.7 | 30.6 | 32.4 | 304,839,179 | 10208 |
| cyc150/kbq-cpttest-fouroutputgametesisnottrueofoogenesis-0.flr | pass | `pass` | 1.7 | 29.4 | 31.1 | 298,050,517 | 9954 |
| cyc150/kbq-cpttest-fouroutputgametesisnottrueofoogenesis-2.flr | pass | `pass` | 1.7 | 29.6 | 31.3 | 297,689,089 | 9953 |
| cyc150/kbq-cpttest-fouroutputgametesisnottrueofoogenesis-3.flr | pass | `pass` | 1.7 | 28.8 | 30.5 | 291,921,139 | 9897 |
| cyc150/kbq-cpttest-g1followsmphaseincellcycle-0.flr | pass | `pass` | 1.7 | 28.5 | 30.3 | 284,794,352 | 9791 |
| cyc150/kbq-cpttest-homologouschromosomesmovetowardoppositepolesduringwhat-1.flr | pass | `pass` | 1.7 | 30.0 | 31.7 | 296,629,316 | 10033 |
| cyc150/kbq-cpttest-howmanychromatidsinaduplicatedchromosome-0.flr | pass | `pass` | 1.7 | 28.8 | 30.5 | 292,289,565 | 9753 |
| cyc150/kbq-cpttest-howmanychromatidsinaduplicatedchromosome-1.flr | pass | `pass` | 1.7 | 28.9 | 30.6 | 292,295,609 | 9752 |
| cyc150/kbq-cpttest-howmanykinetochoremicrotubuleattachmentsduringprophasei-0.flr | pass | `pass` | 1.7 | 28.5 | 30.2 | 289,264,569 | 9772 |
| cyc150/kbq-cpttest-howmanykinetochoremicrotubuleattachmentsduringprophasei-1.flr | pass | `pass` | 1.7 | 28.5 | 30.3 | 289,262,488 | 9772 |
| cyc150/kbq-cpttest-ifmeiosistakes100hourshowlongdoesitsprophaseitake-0.flr | pass | `pass` | 1.7 | 28.0 | 29.7 | 282,062,119 | 9776 |
| cyc150/kbq-cpttest-ifsteroidhormonescanenteracellviadiffusiontheytheycantbindtomembranereceptors-0.flr | pass | `pass` | 1.7 | 28.4 | 30.1 | 288,678,481 | 9701 |
| cyc150/kbq-cpttest-inacellwithfourcentromereshowmanychromosomesarethere-0.flr | pass | `pass` | 1.7 | 28.5 | 30.2 | 289,291,954 | 9794 |
| cyc150/kbq-cpttest-inacellwithfourcentromereshowmanychromosomesarethere-1.flr | pass | `pass` | 1.7 | 28.4 | 30.2 | 289,301,147 | 9791 |
| cyc150/kbq-cpttest-intracellularreceptorsareonlypresentintargetcells-0.flr | pass | `pass` | 1.7 | 28.1 | 29.9 | 282,041,442 | 9765 |
| cyc150/kbq-cpttest-ischromosomeofcellintelophaseunduplicated-0.flr | pass | `pass` | 1.7 | 28.3 | 30.1 | 287,073,114 | 9750 |
| cyc150/kbq-cpttest-meiosisandfertilizationdontalternateinwhichcycle-0.flr | pass | `pass` | 1.7 | 28.4 | 30.1 | 288,500,567 | 9759 |
| cyc150/kbq-cpttest-meiosisandfertilizationdontalternateinwhichcycle-1.flr | pass | `pass` | 1.8 | 28.7 | 30.5 | 287,791,777 | 9766 |
| cyc150/kbq-cpttest-meiosisandfertilizationdontalternateinwhichcycle-2.flr | pass | `pass` | 1.7 | 28.3 | 30.0 | 287,205,484 | 9750 |
| cyc150/kbq-cpttest-meiosisandfertilizationdontalternateinwhichcycle-3.flr | pass | `pass` | 1.7 | 28.2 | 29.9 | 287,205,484 | 9753 |
| cyc150/kbq-cpttest-meiosisandfertilizationdontalternateinwhichcycle-4.flr | pass | `pass` | 1.7 | 28.3 | 30.0 | 287,205,484 | 9751 |
| cyc150/kbq-cpttest-meiosisandfertilizationdontalternateinwhichcycle-5.flr | pass | `pass` | 1.7 | 28.2 | 29.9 | 283,283,550 | 9778 |
| cyc150/kbq-cpttest-microtubuledevelopmentinterferenceeffects-1.flr | pass | `pass` | 1.8 | 29.2 | 31.1 | 291,213,879 | 9755 |
| cyc150/kbq-cpttest-mitosispreserveschromosomenumber-0.flr | pass | `pass` | 1.7 | 29.8 | 31.5 | 299,724,923 | 9934 |
| cyc150/kbq-cpttest-mitoticspindlesaretubulin-0.flr | pass | `pass` | 1.7 | 29.2 | 30.9 | 297,214,510 | 9702 |
| cyc150/kbq-cpttest-mitoticspindlesaretubulin-1.flr | pass | `pass` | 1.7 | 29.2 | 30.9 | 297,223,215 | 9702 |
| cyc150/kbq-cpttest-mpfactivitydropofinmphasedoesdropoffinmphase-01-0.flr | pass | `pass` | 1.7 | 28.4 | 30.2 | 286,048,028 | 9801 |
| cyc150/kbq-cpttest-mpfdeactivatingenzymedoesnotdegradebothcdc2andcyclin-0.flr | pass | `pass` | 1.8 | 28.5 | 30.4 | 283,527,850 | 9809 |
| cyc150/kbq-cpttest-mpfdeactivatingenzymedoesnotdegradecdc2-0.flr | pass | `pass` | 1.7 | 28.5 | 30.3 | 283,791,320 | 9812 |
| cyc150/kbq-cpttest-mpfdeactivatingenzymedoesnotstimulatecdc2-0.flr | pass | `pass` | 1.7 | 28.3 | 30.1 | 283,791,320 | 9810 |
| cyc150/kbq-cpttest-mpfdeactivatingenzymedoesnotstimulatecyclin-0.flr | pass | `pass` | 1.7 | 29.4 | 31.1 | 292,543,686 | 10143 |
| cyc150/kbq-cpttest-mpfdeactivatingenzymemostlikelydoeswhat-0.flr | pass | `pass` | 1.7 | 28.3 | 30.1 | 284,406,217 | 9842 |
| cyc150/kbq-cpttest-mpfdeactivatingenzymemostlikelydoeswhat-1.flr | failed | `diff(2,0)` | 1.7 | 29.8 | 31.5 | 296,033,303 | 10190 |
| cyc150/kbq-cpttest-mpfdeactivatingenzymemostlikelydoeswhat-2.flr | failed | `diff(2,0)` | 1.7 | 29.8 | 31.6 | 296,279,804 | 10190 |
| cyc150/kbq-cpttest-mpfdeactivatingenzymemostlikelydoeswhat-3.flr | pass | `pass` | 1.7 | 29.5 | 31.2 | 293,511,383 | 10178 |
| cyc150/kbq-cpttest-mphasefollowsg2incellcycle-0.flr | pass | `pass` | 1.7 | 28.3 | 30.0 | 284,060,886 | 9787 |
| cyc150/kbq-cpttest-mphasefollowsinterphaseincellcycle-0.flr | pass | `pass` | 1.8 | 28.3 | 30.2 | 280,624,159 | 9739 |
| cyc150/kbq-cpttest-numberofchromatidsincellwith4duplicatedchromosomes-1.flr | pass | `pass` | 1.7 | 29.0 | 30.8 | 291,063,164 | 9797 |
| cyc150/kbq-cpttest-phosphorylationcascadescauseamplifiedcellularresponsebecausetheyincreasetheamountofactivatedenzymes-01-0.flr | pass | `pass` | 1.7 | 28.7 | 30.4 | 289,129,972 | 9698 |
| cyc150/kbq-cpttest-posprooffortestquestionq6-0.flr | pass | `pass` | 1.7 | 30.1 | 31.8 | 297,201,279 | 10168 |
| cyc150/kbq-cpttest-prokaryoticcellcyclepreserveschromosomenumber-0.flr | pass | `pass` | 1.7 | 29.1 | 30.8 | 296,488,263 | 9902 |
| cyc150/kbq-cpttest-proteinphosphorylationisinvolvedinallexcept-2.flr | pass | `pass` | 1.7 | 28.2 | 29.9 | 285,083,609 | 9680 |
| cyc150/kbq-cpttest-proteinphosphorylationisinvolvedinallexcept-3.flr | pass | `pass` | 1.8 | 28.2 | 30.0 | 284,516,944 | 9658 |
| cyc150/kbq-cpttest-steroidhormonescanenteracellbysimplediffusionsowhatfollows-0.flr | pass | `pass` | 1.7 | 28.7 | 30.4 | 288,678,481 | 9704 |
| cyc150/kbq-cpttest-steroidhormonescanenteracellbysimplediffusionsowhatfollows-1.flr | pass | `pass` | 1.7 | 28.3 | 30.0 | 287,269,575 | 9717 |
| cyc150/kbq-cpttest-subeventsofsphase-1.flr | pass | `pass` | 1.7 | 177.3 | 179.1 | 1,825,879,463 | 53895 |
| cyc150/kbq-cpttest-synapsisoccursduringwhat-1.flr | pass | `pass` | 1.7 | 28.1 | 29.9 | 280,715,789 | 9732 |
| cyc150/kbq-cpttest-whataremitoticspindlesmadeof-0.flr | pass | `pass` | 1.8 | 30.4 | 32.2 | 304,306,666 | 9722 |
| cyc150/kbq-cpttest-whatdoesnotoccurduringmitosis-1.flr | pass | `pass` | 1.7 | 28.8 | 30.5 | 287,640,223 | 9743 |
| cyc150/kbq-cpttest-whatdoesnotoccurindividingbacteria-0.flr | pass | `pass` | 1.7 | 28.7 | 30.5 | 289,233,576 | 9756 |
| cyc150/kbq-cpttest-whatdoesnotoverlapwithcytokinesis-version3-0.flr | pass | `pass` | 1.7 | 28.3 | 30.0 | 284,268,124 | 9800 |
| cyc150/kbq-cpttest-whatdoesnotoverlapwithcytokinesis-version3-1.flr | pass | `pass` | 1.7 | 28.6 | 30.3 | 289,698,204 | 9771 |
| cyc150/kbq-cpttest-whatdoesnotoverlapwithcytokinesis-version3-3.flr | pass | `pass` | 1.7 | 28.7 | 30.4 | 286,222,602 | 9828 |
| cyc150/kbq-cpttest-whatisalocus-2.flr | pass | `pass` | 1.7 | 32.5 | 34.2 | 321,739,729 | 11132 |
| cyc150/kbq-cpttest-whatisduplicationstatusofchromosomeofcellinsphase-0.flr | pass | `pass` | 1.7 | 28.8 | 30.5 | 288,182,440 | 9778 |
| cyc150/kbq-cpttest-whatisthediameterofacilium-0.flr | pass | `pass` | 1.7 | 28.6 | 30.3 | 285,402,553 | 9693 |
| cyc150/kbq-cpttest-whatistheregionthatconnectsreplicateddnamolecules-1.flr | pass | `pass` | 1.7 | 28.6 | 30.4 | 282,560,266 | 9771 |
| cyc150/kbq-cpttest-whatistheregionthatconnectsreplicateddnamolecules-2.flr | pass | `pass` | 1.7 | 29.5 | 31.3 | 282,560,266 | 9771 |
| cyc150/kbq-cpttest-whatistheregionthatconnectsreplicateddnamolecules-4.flr | pass | `pass` | 1.7 | 28.5 | 30.3 | 282,560,266 | 9771 |
| cyc150/kbq-cpttest-whatisthesecondmessengerinepinephrinetoglucosereleasesignaling-0.flr | pass | `pass` | 1.7 | 30.2 | 32.0 | 296,008,544 | 10115 |
| cyc150/kbq-cpttest-whatisthesecondmessengerinepinephrinetoglucosereleasesignaling-1.flr | pass | `pass` | 1.7 | 30.3 | 32.0 | 296,017,808 | 10116 |
| cyc150/kbq-cpttest-whatkindofcellisagamete-0.flr | pass | `pass` | 1.7 | 28.5 | 30.2 | 286,964,041 | 9714 |
| cyc150/kbq-cpttest-whatkindofthingisahaploidcell-4.flr | pass | `pass` | 1.7 | 28.6 | 30.3 | 286,633,862 | 9701 |
| cyc150/kbq-cpttest-whatkindsofmoleculearecandidateligandsforcytoplasmicreceptors-1.flr | pass | `pass` | 1.8 | 32.7 | 34.8 | 320,839,776 | 10977 |
| cyc150/kbq-cpttest-whatkindsofmoleculearecandidateligandsforcytoplasmicreceptors-3.flr | pass | `pass` | 1.8 | 32.6 | 34.7 | 320,839,809 | 10976 |
| cyc150/kbq-cpttest-whatkindsofmoleculearecandidateligandsforcytoplasmicreceptors-4.flr | pass | `pass` | 1.7 | 29.3 | 31.1 | 297,268,612 | 9984 |
| cyc150/kbq-cpttest-whatoverlapswithcytokinesis-0.flr | pass | `pass` | 1.7 | 28.5 | 30.2 | 289,698,204 | 9772 |
| cyc150/kbq-cpttest-whatphaseofmitosisistheoppositeofprometaphasewrtnuclearenvelope-2.flr | pass | `pass` | 1.7 | 28.1 | 29.9 | 279,834,440 | 9684 |
| cyc150/kbq-cpttest-whatphaseofmitosisistheoppositeofprometaphasewrtnuclearenvelope-3.flr | pass | `pass` | 1.7 | 28.4 | 30.1 | 279,834,440 | 9686 |
| cyc150/kbq-cpttest-whatphasesalternateintheeukaryoticcellcycle-0.flr | pass | `pass` | 1.7 | 28.7 | 30.5 | 290,192,835 | 9799 |
| cyc150/kbq-cpttest-whatphasesalternateintheeukaryoticcellcycle-1.flr | pass | `pass` | 1.7 | 28.5 | 30.3 | 286,924,330 | 9740 |
| cyc150/kbq-cpttest-whatphasesalternateintheeukaryoticcellcycle-2.flr | pass | `pass` | 1.7 | 30.2 | 31.9 | 293,240,815 | 10081 |
| cyc150/kbq-cpttest-whatsnottrueofthecellcycle-0.flr | pass | `pass` | 1.7 | 30.1 | 31.9 | 302,506,207 | 9757 |
| cyc150/kbq-cpttest-whatsnottrueofthecellcycle-1.flr | pass | `pass` | 1.7 | 28.6 | 30.3 | 287,715,368 | 9755 |
| cyc150/kbq-cpttest-whatsnottrueofthecellcycle-2.flr | pass | `pass` | 1.7 | 28.3 | 30.0 | 285,013,562 | 9686 |
| cyc150/kbq-cpttest-whichligandtypehasareceptorinthecytoplasm-0.flr | pass | `pass` | 1.7 | 29.0 | 30.7 | 289,005,605 | 9747 |
| cyc150/kbq-cpttest-whichligandtypehasareceptorinthecytoplasm-1.flr | pass | `pass` | 1.8 | 28.9 | 30.8 | 287,570,023 | 9706 |
| cyc150/kbq-cpttest-whichligandtypehasareceptorinthecytoplasm-2.flr | pass | `pass` | 1.9 | 28.6 | 30.6 | 287,570,023 | 9709 |
| cyc150/kbq-cpttest-whichligandtypehasareceptorinthecytoplasm-3.flr | pass | `pass` | 1.7 | 28.9 | 30.7 | 287,570,023 | 9707 |
| cyc150/kbq-cpttest-whichligandtypehasareceptorinthecytoplasm-5.flr | pass | `pass` | 1.8 | 35.0 | 36.9 | 341,232,993 | 11776 |
| cyc150/kbq-cpttest-whichofthefollowingisincentrosome-0.flr | pass | `pass` | 1.7 | 30.8 | 32.6 | 307,084,780 | 9844 |
| cyc150/kbq-cpttest-whichofthefollowingisincentrosome-1.flr | pass | `pass` | 1.7 | 30.0 | 31.7 | 299,494,378 | 9846 |
| cyc150/kbq-cpttest-whichofthefollowingistrueofreceptormolecules-0.flr | pass | `pass` | 1.8 | 30.3 | 32.1 | 299,778,379 | 9810 |
| cyc150/kbq-cpttest-whichofthefollowingwouldresultinaresponseatthecellularlevel-0.flr | pass | `pass` | 1.8 | 29.4 | 31.2 | 294,697,126 | 9881 |
| cyc150/kbq-cpttest-whichofthefollowingwouldresultintheamplificationofachemicalsignal-0.flr | pass | `pass` | 1.7 | 29.0 | 30.7 | 290,147,100 | 9777 |
| cyc150/kbq-cpttest-whichreduceschromosomenumberbyhalf-0.flr | pass | `pass` | 1.7 | 29.8 | 31.5 | 304,003,856 | 10132 |
| cyc150/kbq-cpttest-whichtwocanserveassecondmessengers-1.flr | pass | `pass` | 1.7 | 28.3 | 30.0 | 287,561,905 | 9692 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-diploidnumberfordogs-0.flr | pass | `pass` | 1.7 | 28.8 | 30.5 | 289,959,262 | 9831 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-duplicatedchromosomeconsistsof2chromatids-hyp-0.flr | pass | `pass` | 1.7 | 29.1 | 30.9 | 294,503,565 | 9816 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-duringwhatdoesaduplicatedchromosomeplayarole-0.flr | pass | `pass` | 1.7 | 28.4 | 30.2 | 285,646,131 | 9703 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-firstsignofprophase-1-0.flr | pass | `pass` | 1.8 | 31.0 | 32.8 | 304,839,179 | 10208 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-howmanychromatidsinaduplicatedchromosome-0.flr | pass | `pass` | 1.8 | 29.1 | 31.0 | 292,295,609 | 9753 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-ifcellcycleinputhas32chromosomeswhatdodaughtercellshave-0.flr | pass | `pass` | 1.7 | 29.5 | 31.2 | 292,207,845 | 9917 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-meiosisandfertilizationdontalternateinwhichcycle-0.flr | pass | `pass` | 1.7 | 28.5 | 30.2 | 283,283,550 | 9775 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-microtubuledevelopmentinterferenceeffects-0.flr | pass | `pass` | 1.8 | 29.4 | 31.3 | 291,992,615 | 9783 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-numberofchromatidsincellwith4duplicatedchromosomes-0.flr | pass | `pass` | 1.7 | 29.2 | 30.9 | 291,063,164 | 9795 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-subeventsofsphase-0.flr | pass | `pass` | 1.8 | 180.3 | 182.1 | 1,825,879,463 | 53896 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-whatphasesalternateintheeukaryoticcellcycle-0.flr | pass | `pass` | 1.7 | 28.6 | 30.3 | 290,192,835 | 9795 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-whichligandtypehasareceptorinthecytoplasm-0.flr | pass | `pass` | 1.8 | 34.8 | 36.7 | 341,232,993 | 11774 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-whichofthefollowingisincentrosome-0.flr | pass | `pass` | 1.8 | 29.6 | 31.4 | 298,053,529 | 9737 |
| wine_ontology/wine2.flr | loaded | `loaded(0)` | 0.3 | 0.0 | 0.3 | 0 | 69 |


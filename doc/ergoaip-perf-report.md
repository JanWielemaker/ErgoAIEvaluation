# ergoAIp on ErgoAI-performance: full report

All 158 test programs of `ErgoEngine/ErgoAI-performance`, measured 2026-10-24/25 on SWI-Prolog 10.1.19, ErgoEngine e550962 (branch `ergo301-performance`), ergoAIstudio2 b07b4ae (branch `cache`).  Produced by `scripts/ergoaip_perf.pl` and `scripts/perf_report.py`; [tooling.md](tooling.md) explains how to run them.

**Setup.**  One fresh `swipl` process per program, run one after the other: 1800 s timeout, 16 GB stack, 40 GB table space, in a systemd scope capped at 80–90 GB without swap.  The ergo2p conversion cache was warm.  Programs 102–114 and 122–128 of the run overlapped with short test runs using up to 15 GB, so their times may be slightly high.

**Notes.**

- `compiletests`, `CYC_tests/test0`, `PaulH_tests/test1`, `UDF_tests` and `wine_ontology` have no golden output.  *loaded* means that the program loaded and its queries ran without error.
- The two `subeventsofsphase` cases exhaust the 40 GB table space at an 84 GB peak.  Their `%test` runs `%pretest` twice, with `mustDefine` on and off.  `ergoaip_cases.pl`, which solves `%pretest` once, passes both with the same table space; see `cyc150-issues.md`, issue 11.
- The two `mpfdeactivatingenzyme` cases miss 2 answers.  They need equality substitution; see `cyc150-issues.md`.
- `amitotictissuehasnocellsinthecellcycle-0` gave `convert_incomplete` in the run: ergo2p could not write its output at that moment.  It passed when re-run on its own, and the table has the re-run.

## Summary

| Result | Files |
|---|---|
| pass | 140 |
| loaded | 14 |
| failed | 2 |
| out-of-memory | 2 |
| timeout | 0 |
| **total** | **158** |

| Directory | Files | Pass | Median solve s | Max solve s | Sum of run times s | Median peak MB | Max peak MB |
|---|---|---|---|---|---|---|---|
| CYC_tests/test0 | 3 | 0 | 0.0 | 0.0 | 3.6 | 107 | 126 |
| PaulH_tests/test1 | 4 | 0 | 0.0 | 0.0 | 7.1 | 44 | 1495 |
| UDF_tests | 2 | 0 | 0.0 | 0.0 | 0.0 | 26 | 26 |
| compiletests | 4 | 0 | 0.0 | 0.0 | 532.6 | 1031 | 1582 |
| cyc150 | 144 | 140 | 33.7 | 220.6 | 9095.5 | 14263 | 84489 |
| wine_ontology | 1 | 0 | 0.0 | 0.0 | 0.4 | 68 | 68 |

## All test files

Times are wall clock in seconds; *run* is the whole child process after engine boot (convert + load + solve + comparison).  *Peak* is the process's peak resident set size (VmHWM).

| File | Result | Verdict | Load s | Solve s | Run s | Solve inferences | Peak MB |
|---|---|---|---|---|---|---|---|
| CYC_tests/test0/load.flr | loaded | `loaded(3)` | 1.8 | 0.0 | 1.8 | 0 | 107 |
| CYC_tests/test0/load2.flr | loaded | `loaded(4)` | 1.8 | 0.0 | 1.8 | 0 | 126 |
| CYC_tests/test0/load_production.flr | loaded | `loaded(3)` | 0.0 | 0.0 | 0.0 | 0 | 27 |
| PaulH_tests/test1/load.flr | loaded | `loaded(2)` | 0.5 | 0.0 | 0.5 | 0 | 44 |
| PaulH_tests/test1/load2.flr | loaded | `loaded(2)` | 5.8 | 0.0 | 5.8 | 0 | 1495 |
| PaulH_tests/test1/load3.flr | loaded | `loaded(13)` | 0.5 | 0.0 | 0.5 | 0 | 45 |
| PaulH_tests/test1/load_production.flr | loaded | `loaded(2)` | 0.3 | 0.0 | 0.3 | 0 | 44 |
| UDF_tests/fib_like_test.flr | loaded | `loaded(1)` | 0.0 | 0.0 | 0.0 | 0 | 26 |
| UDF_tests/fib_like_test2.flr | loaded | `loaded(1)` | 0.0 | 0.0 | 0.0 | 0 | 26 |
| compiletests/bio_carl.flr | loaded | `loaded(1)` | 175.4 | 0.0 | 175.4 | 0 | 837 |
| compiletests/biologyKB.flr | loaded | `loaded(1)` | 276.2 | 0.0 | 276.2 | 0 | 679 |
| compiletests/clarklog.flr | loaded | `loaded(0)` | 53.0 | 0.0 | 53.0 | 0 | 1582 |
| compiletests/clarklog2.flr | loaded | `loaded(0)` | 28.0 | 0.0 | 28.0 | 0 | 1225 |
| cyc150/kbq-cptevaluationtest-howtoendcellresponsetosignalwithphosphorylationcascade-0.flr | pass | `pass` | 1.7 | 35.6 | 59.4 | 299,125,270 | 14751 |
| cyc150/kbq-cpttest-acellinsphaseisactivelydoingwhat-0.flr | pass | `pass` | 1.7 | 40.1 | 65.3 | 322,628,898 | 15666 |
| cyc150/kbq-cpttest-acellinthecellcycleisactivelydoingwhat-0.flr | pass | `pass` | 1.7 | 34.9 | 58.5 | 295,014,171 | 14547 |
| cyc150/kbq-cpttest-allofthefollowingoccurduringmeiosisiexcept-2.flr | pass | `pass` | 1.7 | 33.7 | 56.7 | 288,786,820 | 14162 |
| cyc150/kbq-cpttest-allofthefollowingoccurduringmeiosisiexcept-3.flr | pass | `pass` | 1.9 | 35.5 | 59.1 | 287,918,561 | 14284 |
| cyc150/kbq-cpttest-amitotictissuehasnocellsbetweensphaseandg2phase-0.flr | pass | `pass` | 1.7 | 34.4 | 57.8 | 292,894,640 | 14548 |
| cyc150/kbq-cpttest-amitotictissuehasnocellsinthecellcycle-0.flr | pass | `pass` | 1.7 | 33.4 | 56.5 | 284,193,174 | 14231 |
| cyc150/kbq-cpttest-anaphaseinvolvesachangeinnumberofchromosomes-0.flr | pass | `pass` | 1.7 | 42.2 | 67.4 | 315,712,643 | 15539 |
| cyc150/kbq-cpttest-aneventthatinterfereswithspindleformationisonethatinterfereswiththemcheckpoint-0.flr | pass | `pass` | 2.2 | 34.3 | 57.8 | 291,655,507 | 14297 |
| cyc150/kbq-cpttest-arebacteriaprokaryotes-2-0.flr | pass | `pass` | 1.7 | 33.1 | 55.7 | 287,990,534 | 14110 |
| cyc150/kbq-cpttest-arethediploidandmonoploidnumbersthesameinhumans-0.flr | pass | `pass` | 1.7 | 34.1 | 57.4 | 294,907,978 | 14220 |
| cyc150/kbq-cpttest-cancercellsdontexhibitdensitydependentinhibition-0.flr | pass | `pass` | 1.7 | 33.7 | 56.5 | 289,856,549 | 14241 |
| cyc150/kbq-cpttest-canparameciamovethemselves-0.flr | pass | `pass` | 1.7 | 33.1 | 55.9 | 285,717,000 | 14298 |
| cyc150/kbq-cpttest-canspermcellsmovethemselves-0.flr | pass | `pass` | 1.7 | 33.2 | 56.0 | 291,280,033 | 14253 |
| cyc150/kbq-cpttest-causationamongscenesincellsignalingsubscript-pathwaytype-0.flr | pass | `pass` | 1.8 | 34.8 | 58.8 | 299,616,322 | 14319 |
| cyc150/kbq-cpttest-cellwithcellplateiswhat-0.flr | pass | `pass` | 1.7 | 33.5 | 56.4 | 289,769,246 | 14495 |
| cyc150/kbq-cpttest-cellwithcellplateiswhat-1.flr | pass | `pass` | 1.7 | 33.5 | 56.6 | 289,769,246 | 14495 |
| cyc150/kbq-cpttest-cellwithcellplateiswhat-4.flr | pass | `pass` | 1.7 | 33.5 | 56.2 | 288,679,161 | 14486 |
| cyc150/kbq-cpttest-centromeresjoinsisterchromatids-0.flr | pass | `pass` | 1.8 | 33.4 | 56.0 | 288,493,695 | 14503 |
| cyc150/kbq-cpttest-changesinmpfactivitycorrelatewithwhat-0.flr | pass | `pass` | 1.7 | 33.6 | 56.5 | 292,049,533 | 14279 |
| cyc150/kbq-cpttest-changesinmpfactivitycorrelatewithwhat-3.flr | pass | `pass` | 1.7 | 36.3 | 60.2 | 306,462,692 | 15154 |
| cyc150/kbq-cpttest-chromosomesarechromatin-0.flr | pass | `pass` | 1.7 | 33.2 | 55.9 | 291,299,943 | 14182 |
| cyc150/kbq-cpttest-chromosomesarechromatin-1.flr | pass | `pass` | 1.7 | 33.1 | 55.8 | 291,299,943 | 14183 |
| cyc150/kbq-cpttest-chromosomesarechromatin-2.flr | pass | `pass` | 1.7 | 33.2 | 55.9 | 291,299,943 | 14181 |
| cyc150/kbq-cpttest-chromosomesarechromatin-4.flr | pass | `pass` | 1.8 | 34.6 | 58.5 | 296,160,251 | 14273 |
| cyc150/kbq-cpttest-crossingoveroccursduringwhat-0.flr | pass | `pass` | 1.7 | 32.9 | 55.4 | 282,226,949 | 14169 |
| cyc150/kbq-cpttest-cytokinesisisthedivisionofonecellintotwo-0.flr | pass | `pass` | 1.7 | 35.0 | 58.8 | 300,386,127 | 14715 |
| cyc150/kbq-cpttest-cytokinesisistheseparationofthecytoplasm-0.flr | pass | `pass` | 1.7 | 35.5 | 59.9 | 305,487,682 | 14714 |
| cyc150/kbq-cpttest-cytokinesisistheseparationofthecytoplasmintotwo-0.flr | pass | `pass` | 1.7 | 36.3 | 60.6 | 310,746,371 | 15161 |
| cyc150/kbq-cpttest-cytokinesisstartsafteranaphaseendsincellcycle-0.flr | pass | `pass` | 1.7 | 33.7 | 57.1 | 291,458,990 | 14331 |
| cyc150/kbq-cpttest-cytokinesisstartsafteranaphaseendsinmphase-0.flr | pass | `pass` | 1.7 | 33.5 | 56.7 | 289,718,330 | 14294 |
| cyc150/kbq-cpttest-daughtercellsofcellcyclearenotfusedinfertilization-0.flr | pass | `pass` | 1.7 | 32.8 | 55.3 | 286,847,058 | 14117 |
| cyc150/kbq-cpttest-daughtercellsofcellcyclearenotfusedinfertilization-02-0.flr | pass | `pass` | 1.7 | 32.9 | 55.4 | 286,847,058 | 14117 |
| cyc150/kbq-cpttest-diploidnumberfordogs-0.flr | pass | `pass` | 1.8 | 33.9 | 57.5 | 291,811,194 | 14329 |
| cyc150/kbq-cpttest-diploidnumberfordogs-2.flr | pass | `pass` | 1.9 | 33.5 | 56.6 | 291,822,634 | 14328 |
| cyc150/kbq-cpttest-duplicatedchromosomeconsistsof2chromatids-hyp-1.flr | pass | `pass` | 1.7 | 34.0 | 57.2 | 296,398,794 | 14311 |
| cyc150/kbq-cpttest-duringanaphaseiiwhathappens-0.flr | pass | `pass` | 1.7 | 35.2 | 59.0 | 303,700,204 | 14560 |
| cyc150/kbq-cpttest-duringwhatdochromosomesreplicate-3.flr | pass | `pass` | 1.7 | 33.0 | 55.6 | 284,126,708 | 14179 |
| cyc150/kbq-cpttest-duringwhatdoesaduplicatedchromosomeplayarole-0.flr | pass | `pass` | 1.7 | 32.9 | 55.2 | 287,462,535 | 14141 |
| cyc150/kbq-cpttest-duringwhatdoesaduplicatedchromosomeplayarole-1.flr | pass | `pass` | 1.7 | 32.9 | 55.3 | 287,483,815 | 14145 |
| cyc150/kbq-cpttest-duringwhatdoesaspindleforminahaploidcell-1.flr | pass | `pass` | 1.8 | 37.0 | 62.4 | 317,154,216 | 15500 |
| cyc150/kbq-cpttest-duringwhichofthefollowingdoesdnareplicate-0.flr | pass | `pass` | 1.7 | 33.6 | 56.9 | 292,056,703 | 14199 |
| cyc150/kbq-cpttest-eukaryoticcellcycleiterationsdontcontaincdkcreationevents-0.flr | pass | `pass` | 1.7 | 32.7 | 55.3 | 283,710,752 | 14210 |
| cyc150/kbq-cpttest-eukaryoticcellcycleiterationsdontcontaincdkdestructionevents-0.flr | pass | `pass` | 1.7 | 32.9 | 55.5 | 283,710,752 | 14210 |
| cyc150/kbq-cpttest-firstsignofprophase-1-0.flr | pass | `pass` | 1.7 | 35.5 | 59.8 | 306,829,206 | 14801 |
| cyc150/kbq-cpttest-fouroutputgametesisnottrueofoogenesis-0.flr | pass | `pass` | 1.7 | 34.2 | 57.6 | 299,965,627 | 14503 |
| cyc150/kbq-cpttest-fouroutputgametesisnottrueofoogenesis-2.flr | pass | `pass` | 1.7 | 34.6 | 58.6 | 299,653,485 | 14503 |
| cyc150/kbq-cpttest-fouroutputgametesisnottrueofoogenesis-3.flr | pass | `pass` | 1.7 | 33.6 | 56.5 | 293,795,267 | 14419 |
| cyc150/kbq-cpttest-g1followsmphaseincellcycle-0.flr | pass | `pass` | 1.8 | 33.5 | 57.9 | 286,668,209 | 14264 |
| cyc150/kbq-cpttest-homologouschromosomesmovetowardoppositepolesduringwhat-1.flr | pass | `pass` | 1.7 | 34.8 | 58.3 | 298,567,300 | 14546 |
| cyc150/kbq-cpttest-howmanychromatidsinaduplicatedchromosome-0.flr | pass | `pass` | 1.7 | 33.5 | 56.4 | 294,171,208 | 14216 |
| cyc150/kbq-cpttest-howmanychromatidsinaduplicatedchromosome-1.flr | pass | `pass` | 1.7 | 33.5 | 56.4 | 294,177,327 | 14213 |
| cyc150/kbq-cpttest-howmanykinetochoremicrotubuleattachmentsduringprophasei-0.flr | pass | `pass` | 1.7 | 33.3 | 56.0 | 291,124,755 | 14244 |
| cyc150/kbq-cpttest-howmanykinetochoremicrotubuleattachmentsduringprophasei-1.flr | pass | `pass` | 1.7 | 33.3 | 56.1 | 291,122,642 | 14244 |
| cyc150/kbq-cpttest-ifmeiosistakes100hourshowlongdoesitsprophaseitake-0.flr | pass | `pass` | 1.7 | 33.0 | 56.1 | 283,916,304 | 14245 |
| cyc150/kbq-cpttest-ifsteroidhormonescanenteracellviadiffusiontheytheycantbindtomembranereceptors-0.flr | pass | `pass` | 1.7 | 33.1 | 55.8 | 290,537,212 | 14142 |
| cyc150/kbq-cpttest-inacellwithfourcentromereshowmanychromosomesarethere-0.flr | pass | `pass` | 1.7 | 33.4 | 56.1 | 291,152,823 | 14274 |
| cyc150/kbq-cpttest-inacellwithfourcentromereshowmanychromosomesarethere-1.flr | pass | `pass` | 1.7 | 33.4 | 56.1 | 291,162,081 | 14274 |
| cyc150/kbq-cpttest-intracellularreceptorsareonlypresentintargetcells-0.flr | pass | `pass` | 1.7 | 32.9 | 55.6 | 283,896,015 | 14231 |
| cyc150/kbq-cpttest-ischromosomeofcellintelophaseunduplicated-0.flr | pass | `pass` | 1.7 | 33.1 | 55.5 | 288,918,638 | 14211 |
| cyc150/kbq-cpttest-meiosisandfertilizationdontalternateinwhichcycle-0.flr | pass | `pass` | 1.8 | 33.6 | 57.1 | 290,357,005 | 14222 |
| cyc150/kbq-cpttest-meiosisandfertilizationdontalternateinwhichcycle-1.flr | pass | `pass` | 1.7 | 33.1 | 55.7 | 289,643,174 | 14237 |
| cyc150/kbq-cpttest-meiosisandfertilizationdontalternateinwhichcycle-2.flr | pass | `pass` | 1.7 | 32.9 | 55.5 | 289,052,964 | 14215 |
| cyc150/kbq-cpttest-meiosisandfertilizationdontalternateinwhichcycle-3.flr | pass | `pass` | 1.7 | 32.9 | 55.5 | 289,052,964 | 14214 |
| cyc150/kbq-cpttest-meiosisandfertilizationdontalternateinwhichcycle-4.flr | pass | `pass` | 1.7 | 32.9 | 55.6 | 289,052,964 | 14214 |
| cyc150/kbq-cpttest-meiosisandfertilizationdontalternateinwhichcycle-5.flr | pass | `pass` | 1.7 | 32.9 | 55.7 | 285,147,274 | 14249 |
| cyc150/kbq-cpttest-microtubuledevelopmentinterferenceeffects-1.flr | pass | `pass` | 1.7 | 33.8 | 57.2 | 293,137,857 | 14220 |
| cyc150/kbq-cpttest-mitosispreserveschromosomenumber-0.flr | pass | `pass` | 1.7 | 34.9 | 59.1 | 301,707,915 | 14473 |
| cyc150/kbq-cpttest-mitoticspindlesaretubulin-0.flr | pass | `pass` | 1.7 | 34.4 | 57.9 | 299,137,735 | 14141 |
| cyc150/kbq-cpttest-mitoticspindlesaretubulin-1.flr | pass | `pass` | 1.7 | 34.1 | 57.7 | 299,146,510 | 14141 |
| cyc150/kbq-cpttest-mpfactivitydropofinmphasedoesdropoffinmphase-01-0.flr | pass | `pass` | 1.7 | 33.4 | 56.3 | 287,930,992 | 14286 |
| cyc150/kbq-cpttest-mpfdeactivatingenzymedoesnotdegradebothcdc2andcyclin-0.flr | pass | `pass` | 1.7 | 32.9 | 55.6 | 285,392,804 | 14298 |
| cyc150/kbq-cpttest-mpfdeactivatingenzymedoesnotdegradecdc2-0.flr | pass | `pass` | 1.7 | 33.3 | 56.2 | 285,658,024 | 14298 |
| cyc150/kbq-cpttest-mpfdeactivatingenzymedoesnotstimulatecdc2-0.flr | pass | `pass` | 1.7 | 33.1 | 56.0 | 285,658,024 | 14296 |
| cyc150/kbq-cpttest-mpfdeactivatingenzymedoesnotstimulatecyclin-0.flr | pass | `pass` | 1.7 | 34.3 | 57.7 | 294,446,682 | 14712 |
| cyc150/kbq-cpttest-mpfdeactivatingenzymemostlikelydoeswhat-0.flr | pass | `pass` | 1.7 | 33.0 | 55.9 | 286,276,614 | 14342 |
| cyc150/kbq-cpttest-mpfdeactivatingenzymemostlikelydoeswhat-1.flr | failed | `diff(2,0)` | 1.7 | 34.9 | 58.3 | 297,948,635 | 14783 |
| cyc150/kbq-cpttest-mpfdeactivatingenzymemostlikelydoeswhat-2.flr | failed | `diff(2,0)` | 1.7 | 34.9 | 58.2 | 298,196,821 | 14783 |
| cyc150/kbq-cpttest-mpfdeactivatingenzymemostlikelydoeswhat-3.flr | pass | `pass` | 1.7 | 34.4 | 57.7 | 295,420,461 | 14760 |
| cyc150/kbq-cpttest-mphasefollowsg2incellcycle-0.flr | pass | `pass` | 1.7 | 33.3 | 56.0 | 285,929,783 | 14262 |
| cyc150/kbq-cpttest-mphasefollowsinterphaseincellcycle-0.flr | pass | `pass` | 1.8 | 33.1 | 55.6 | 282,470,012 | 14198 |
| cyc150/kbq-cpttest-numberofchromatidsincellwith4duplicatedchromosomes-1.flr | pass | `pass` | 1.7 | 33.7 | 57.4 | 292,980,417 | 14277 |
| cyc150/kbq-cpttest-phosphorylationcascadescauseamplifiedcellularresponsebecausetheyincreasetheamountofactivatedenzymes-01-0.flr | pass | `pass` | 1.7 | 33.2 | 56.2 | 290,992,796 | 14136 |
| cyc150/kbq-cpttest-posprooffortestquestionq6-0.flr | pass | `pass` | 1.7 | 34.8 | 58.2 | 299,125,270 | 14751 |
| cyc150/kbq-cpttest-prokaryoticcellcyclepreserveschromosomenumber-0.flr | pass | `pass` | 1.7 | 33.9 | 57.2 | 298,395,261 | 14429 |
| cyc150/kbq-cpttest-proteinphosphorylationisinvolvedinallexcept-2.flr | pass | `pass` | 1.7 | 32.7 | 55.0 | 286,918,232 | 14109 |
| cyc150/kbq-cpttest-proteinphosphorylationisinvolvedinallexcept-3.flr | pass | `pass` | 1.7 | 32.8 | 55.1 | 286,348,197 | 14080 |
| cyc150/kbq-cpttest-steroidhormonescanenteracellbysimplediffusionsowhatfollows-0.flr | pass | `pass` | 1.9 | 33.1 | 55.9 | 290,537,212 | 14142 |
| cyc150/kbq-cpttest-steroidhormonescanenteracellbysimplediffusionsowhatfollows-1.flr | pass | `pass` | 1.7 | 32.9 | 55.6 | 289,118,314 | 14163 |
| cyc150/kbq-cpttest-subeventsofsphase-1.flr | out-of-memory | `out_of_memory` | 1.8 | 220.6 | 460.9 | 1,816,436,759 | 84456 |
| cyc150/kbq-cpttest-synapsisoccursduringwhat-1.flr | pass | `pass` | 1.7 | 33.3 | 56.2 | 282,562,654 | 14179 |
| cyc150/kbq-cpttest-whataremitoticspindlesmadeof-0.flr | pass | `pass` | 1.7 | 35.4 | 60.1 | 306,278,940 | 14167 |
| cyc150/kbq-cpttest-whatdoesnotoccurduringmitosis-1.flr | pass | `pass` | 1.7 | 33.7 | 56.6 | 289,491,098 | 14198 |
| cyc150/kbq-cpttest-whatdoesnotoccurindividingbacteria-0.flr | pass | `pass` | 1.7 | 33.4 | 56.2 | 291,094,421 | 14221 |
| cyc150/kbq-cpttest-whatdoesnotoverlapwithcytokinesis-version3-0.flr | pass | `pass` | 1.7 | 33.3 | 56.2 | 286,138,316 | 14286 |
| cyc150/kbq-cpttest-whatdoesnotoverlapwithcytokinesis-version3-1.flr | pass | `pass` | 1.7 | 33.7 | 56.6 | 291,562,484 | 14239 |
| cyc150/kbq-cpttest-whatdoesnotoverlapwithcytokinesis-version3-3.flr | pass | `pass` | 1.7 | 33.7 | 57.0 | 288,105,339 | 14321 |
| cyc150/kbq-cpttest-whatisalocus-2.flr | pass | `pass` | 1.7 | 38.6 | 66.2 | 323,881,089 | 17132 |
| cyc150/kbq-cpttest-whatisduplicationstatusofchromosomeofcellinsphase-0.flr | pass | `pass` | 1.7 | 34.9 | 59.2 | 290,034,267 | 14251 |
| cyc150/kbq-cpttest-whatisthediameterofacilium-0.flr | pass | `pass` | 1.8 | 33.4 | 55.9 | 287,238,163 | 14124 |
| cyc150/kbq-cpttest-whatistheregionthatconnectsreplicateddnamolecules-1.flr | pass | `pass` | 1.7 | 33.2 | 55.9 | 284,417,089 | 14241 |
| cyc150/kbq-cpttest-whatistheregionthatconnectsreplicateddnamolecules-2.flr | pass | `pass` | 1.7 | 33.3 | 55.9 | 284,417,089 | 14242 |
| cyc150/kbq-cpttest-whatistheregionthatconnectsreplicateddnamolecules-4.flr | pass | `pass` | 1.7 | 33.4 | 56.3 | 284,417,089 | 14241 |
| cyc150/kbq-cpttest-whatisthesecondmessengerinepinephrinetoglucosereleasesignaling-0.flr | pass | `pass` | 1.7 | 35.0 | 58.9 | 297,924,913 | 14678 |
| cyc150/kbq-cpttest-whatisthesecondmessengerinepinephrinetoglucosereleasesignaling-1.flr | pass | `pass` | 1.7 | 35.3 | 59.2 | 297,934,240 | 14677 |
| cyc150/kbq-cpttest-whatkindofcellisagamete-0.flr | pass | `pass` | 1.7 | 33.7 | 56.5 | 288,810,948 | 14153 |
| cyc150/kbq-cpttest-whatkindofthingisahaploidcell-4.flr | pass | `pass` | 1.7 | 33.7 | 56.5 | 288,478,578 | 14138 |
| cyc150/kbq-cpttest-whatkindsofmoleculearecandidateligandsforcytoplasmicreceptors-1.flr | pass | `pass` | 1.8 | 40.0 | 67.1 | 322,891,502 | 15819 |
| cyc150/kbq-cpttest-whatkindsofmoleculearecandidateligandsforcytoplasmicreceptors-3.flr | pass | `pass` | 1.9 | 39.3 | 66.5 | 322,891,535 | 15819 |
| cyc150/kbq-cpttest-whatkindsofmoleculearecandidateligandsforcytoplasmicreceptors-4.flr | pass | `pass` | 1.7 | 34.5 | 58.0 | 299,177,189 | 14545 |
| cyc150/kbq-cpttest-whatoverlapswithcytokinesis-0.flr | pass | `pass` | 1.7 | 33.6 | 56.5 | 291,562,484 | 14242 |
| cyc150/kbq-cpttest-whatphaseofmitosisistheoppositeofprometaphasewrtnuclearenvelope-2.flr | pass | `pass` | 1.7 | 32.9 | 55.5 | 281,675,155 | 14114 |
| cyc150/kbq-cpttest-whatphaseofmitosisistheoppositeofprometaphasewrtnuclearenvelope-3.flr | pass | `pass` | 1.7 | 33.1 | 55.7 | 281,675,155 | 14117 |
| cyc150/kbq-cpttest-whatphasesalternateintheeukaryoticcellcycle-0.flr | pass | `pass` | 1.7 | 33.8 | 56.8 | 292,060,537 | 14278 |
| cyc150/kbq-cpttest-whatphasesalternateintheeukaryoticcellcycle-1.flr | pass | `pass` | 1.7 | 33.4 | 56.2 | 288,770,051 | 14198 |
| cyc150/kbq-cpttest-whatphasesalternateintheeukaryoticcellcycle-2.flr | pass | `pass` | 1.7 | 35.0 | 58.3 | 295,139,220 | 14625 |
| cyc150/kbq-cpttest-whatsnottrueofthecellcycle-0.flr | pass | `pass` | 1.7 | 36.0 | 60.8 | 304,464,977 | 14219 |
| cyc150/kbq-cpttest-whatsnottrueofthecellcycle-1.flr | pass | `pass` | 1.8 | 37.1 | 59.9 | 289,565,911 | 14221 |
| cyc150/kbq-cpttest-whatsnottrueofthecellcycle-2.flr | pass | `pass` | 1.7 | 33.1 | 55.5 | 286,847,058 | 14117 |
| cyc150/kbq-cpttest-whichligandtypehasareceptorinthecytoplasm-0.flr | pass | `pass` | 1.7 | 33.7 | 56.6 | 290,866,587 | 14207 |
| cyc150/kbq-cpttest-whichligandtypehasareceptorinthecytoplasm-1.flr | pass | `pass` | 1.7 | 33.5 | 56.2 | 289,421,472 | 14148 |
| cyc150/kbq-cpttest-whichligandtypehasareceptorinthecytoplasm-2.flr | pass | `pass` | 1.7 | 33.4 | 56.1 | 289,421,472 | 14148 |
| cyc150/kbq-cpttest-whichligandtypehasareceptorinthecytoplasm-3.flr | pass | `pass` | 1.7 | 33.5 | 56.4 | 289,421,472 | 14149 |
| cyc150/kbq-cpttest-whichligandtypehasareceptorinthecytoplasm-5.flr | pass | `pass` | 1.8 | 41.8 | 69.5 | 343,484,095 | 17980 |
| cyc150/kbq-cpttest-whichofthefollowingisincentrosome-0.flr | pass | `pass` | 1.7 | 35.9 | 60.2 | 309,072,215 | 14346 |
| cyc150/kbq-cpttest-whichofthefollowingisincentrosome-1.flr | pass | `pass` | 1.7 | 34.7 | 58.3 | 301,424,551 | 14345 |
| cyc150/kbq-cpttest-whichofthefollowingistrueofreceptormolecules-0.flr | pass | `pass` | 1.7 | 34.8 | 58.6 | 301,715,683 | 14298 |
| cyc150/kbq-cpttest-whichofthefollowingwouldresultinaresponseatthecellularlevel-0.flr | pass | `pass` | 1.8 | 34.5 | 58.0 | 296,594,289 | 14401 |
| cyc150/kbq-cpttest-whichofthefollowingwouldresultintheamplificationofachemicalsignal-0.flr | pass | `pass` | 1.7 | 34.0 | 57.4 | 292,063,099 | 14253 |
| cyc150/kbq-cpttest-whichreduceschromosomenumberbyhalf-0.flr | pass | `pass` | 1.7 | 35.0 | 58.8 | 305,953,504 | 14752 |
| cyc150/kbq-cpttest-whichtwocanserveassecondmessengers-1.flr | pass | `pass` | 1.7 | 33.2 | 56.0 | 289,412,589 | 14126 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-diploidnumberfordogs-0.flr | pass | `pass` | 1.7 | 33.6 | 56.3 | 291,822,634 | 14329 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-duplicatedchromosomeconsistsof2chromatids-hyp-0.flr | pass | `pass` | 1.7 | 34.1 | 57.4 | 296,398,794 | 14312 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-duringwhatdoesaduplicatedchromosomeplayarole-0.flr | pass | `pass` | 1.7 | 33.0 | 55.5 | 287,483,815 | 14143 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-firstsignofprophase-1-0.flr | pass | `pass` | 1.7 | 36.3 | 60.7 | 306,829,206 | 14799 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-howmanychromatidsinaduplicatedchromosome-0.flr | pass | `pass` | 1.7 | 34.2 | 57.3 | 294,177,327 | 14215 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-ifcellcycleinputhas32chromosomeswhatdodaughtercellshave-0.flr | pass | `pass` | 1.7 | 34.4 | 58.0 | 294,130,560 | 14451 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-meiosisandfertilizationdontalternateinwhichcycle-0.flr | pass | `pass` | 1.7 | 33.9 | 56.8 | 285,147,274 | 14247 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-microtubuledevelopmentinterferenceeffects-0.flr | pass | `pass` | 1.8 | 34.6 | 58.6 | 293,921,786 | 14259 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-numberofchromatidsincellwith4duplicatedchromosomes-0.flr | pass | `pass` | 1.8 | 34.2 | 58.1 | 292,980,417 | 14277 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-subeventsofsphase-0.flr | out-of-memory | `out_of_memory` | 1.8 | 213.9 | 457.8 | 1,816,436,759 | 84489 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-whatphasesalternateintheeukaryoticcellcycle-0.flr | pass | `pass` | 1.8 | 34.0 | 58.9 | 292,060,537 | 14276 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-whichligandtypehasareceptorinthecytoplasm-0.flr | pass | `pass` | 1.8 | 41.8 | 69.7 | 343,484,095 | 17982 |
| cyc150/kbq-opensubquerykbctestfn-cpttest-whichofthefollowingisincentrosome-0.flr | pass | `pass` | 1.7 | 34.9 | 58.7 | 299,977,897 | 14188 |
| wine_ontology/wine2.flr | loaded | `loaded(0)` | 0.4 | 0.0 | 0.4 | 0 | 68 |


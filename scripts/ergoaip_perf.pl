/*  ergoaip_perf.pl — run the ErgoEngine/ErgoAI-performance programs on
    ergoAIp (ErgoAI on SWI-Prolog, ergoAIstudio2/ergoAIp) and time them.

    Usage (from anywhere):

        swipl scripts/ergoaip_perf.pl [options] [path ...]

    Each path is a .flr/.ergo file or a directory (its .flr and .ergo files,
    minus the helper KBs that the tests load themselves).  With no path the
    directory ErgoAI-performance/testall.sh runs is used: cyc150.

    Options:
        --timeout=Secs   per-file wall-clock limit (default 600)
        --out=File       also write the results as TSV
                         (file, mode, verdict, boot-ms, run-ms, inferences)
        --in-process     run all files in this process instead of one fresh
                         swipl per file (faster to start, but KB state can
                         leak between files)
        --verbose        show the engine's stderr (child processes)
        --stack-limit=Sz Prolog stack limit per child (default 16g)
        --table-space=Sz table space per child (default 8g)

    Sizes take a k, m or g suffix.  The defaults are far above SWI-Prolog's
    1 GB: tokenizing the 6-23 MB compiletests KBs and tabling some cyc150
    queries overflow the standard limits.

    A file with a golden transcript (<base>_old) is run the way ErgoAI's
    test_one_file.sh runs it: load, %test, compare the sorted `temp` with
    the golden.  This uses ergoAIp's own golden runner (src/golden.pl), so
    verdicts match the project's golden scoreboard.  Any other file is
    loaded, which also runs its `?-` queries, and only timed.  Run times
    include compilation.  ergo2p conversion is cached across runs
    (src/ergo2p/conv_cache.pl); set ERGOAIP_CONV_CACHE=off to time it.
*/

:- module(ergoaip_perf, []).
:- use_module(library(main)).
:- use_module(library(process)).
:- use_module(library(filesex)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(time)).
:- use_module(library(readutil)).

:- initialization(main, main).

:- prolog_load_context(directory, Dir),
   file_directory_name(Dir, Root),
   asserta(root_dir(Root)).

engine_dir(D) :- root_dir(R), atom_concat(R, '/ergoAIstudio2/ergoAIp', D).
perf_dir(D)   :- root_dir(R), atom_concat(R, '/ErgoEngine/ErgoAI-performance', D).

%   Files that are loaded BY other tests, not tests of their own
%   (ErgoAI-performance/test_dir.sh's exclude_list, plus the parts that
%   CYC_tests/test0 and PaulH_tests/test1 load).
helper_file('error_nonvar.flr').
helper_file('error_nonvar2.flr').
helper_file('error_nonvar3.flr').
helper_file('silk-predicates.flr').
helper_file('silk-predicates_at_builtin.flr').
helper_file('core-pragmatics.flr').
helper_file('core-rules.flr').
helper_file('latest-tiny-kb.flr').
helper_file('rmt-removal-lookup-pos-1.flr').
helper_file(F) :- sub_atom(F, 0, _, _, 'process-').

		 /*******************************
		 *            DRIVER            *
		 *******************************/

main(Argv) :-
    argv_options(Argv, Paths0, Opts),
    (   option(child(true), Opts)
    ->  child(Paths0, Opts)
    ;   set_lib_path,
        set_test_time_limit(Opts),
        (   Paths0 == []
        ->  perf_dir(P), atom_concat(P, '/cyc150', Def), Paths = [Def]
        ;   Paths = Paths0
        ),
        foldl(expand_path, Paths, Files0, []),
        sort(Files0, Files),
        length(Files, N),
        format("ergoaip_perf: ~d file(s)~n", [N]),
        foldl(run_and_report(Opts, N), Files, 1-[], _-Rs0),
        reverse(Rs0, Rs),
        summary(Rs),
        (   option(out(Out), Opts) -> write_tsv(Out, Rs) ; true )
    ).

option(Opt, Opts) :- memberchk(Opt, Opts).

/*  ergoAIp finds the packages that ErgoAI ships (?- [prettyprint>>pp],
    the argumentation theories, ...) through ERGOAIP_LIB_PATH.  golden.pl
    derives it only for files below ErgoAI-testsuite, so set it here.
    Child processes inherit it.                                         */
set_lib_path :-
    (   getenv('ERGOAIP_LIB_PATH', _)
    ->  true
    ;   root_dir(R),
        format(atom(P), '~w/ErgoEngine/ErgoAI/pkgs:~w/ErgoEngine/ErgoAI/ergo_lib',
               [R, R]),
        setenv('ERGOAIP_LIB_PATH', P)
    ).

/*  golden.pl stops %test after ERGOAIP_TIME_LIMIT seconds (default 60),
    long before our own --timeout.  Raise it to match.                   */
set_test_time_limit(Opts) :-
    (   getenv('ERGOAIP_TIME_LIMIT', _)
    ->  true
    ;   ( option(timeout(TO), Opts) -> true ; TO = 600 ),
        setenv('ERGOAIP_TIME_LIMIT', TO)
    ).

expand_path(Path, Files, Tail) :-
    absolute_file_name(Path, Abs, [file_errors(fail), access(exist),
                                   file_type(directory)]),
    !,
    directory_files(Abs, Es0),
    sort(Es0, Es),
    findall(F, ( member(E, Es),
                 file_name_extension(_, Ext, E),
                 memberchk(Ext, [flr, ergo]),
                 \+ helper_file(E),
                 directory_file_path(Abs, E, F) ),
            Fs),
    append(Fs, Tail, Files).
expand_path(Path, [Abs|Tail], Tail) :-
    absolute_file_name(Path, Abs, [file_errors(fail), access(read)]),
    !.
expand_path(Path, Tail, Tail) :-
    print_message(warning, format("~w: no such file or directory", [Path])).

run_and_report(Opts, N, File, I-Rs, I1-[R|Rs]) :-
    I1 is I + 1,
    (   option(in_process(true), Opts)
    ->  run_in_process(File, Opts, R)
    ;   run_child(File, Opts, R)
    ),
    R = result(_, Mode, Verdict, _Boot, Ms, Inf),
    perf_dir(PD),
    (   atom_concat(PD, '/', PDS), atom_concat(PDS, Rel, File) -> true
    ;   Rel = File
    ),
    format("[~d/~d] ~w~t~92| ~w ~w ~t~12+ ~t~1f s~10+ ~t~D inf~18+~n",
           [I, N, Rel, Mode, Verdict, Ms/1000, Inf]),
    flush_output.

		 /*******************************
		 *     ONE PROCESS PER FILE     *
		 *******************************/

/*  The child writes its result to a file rather than to stdout: the KBs
    print to stdout themselves, and a full pipe would block the child.   */
run_child(File, Opts, Result) :-
    ( option(timeout(TO), Opts) -> true ; TO = 600 ),
    current_prolog_flag(executable, Swipl),
    source_file(ergoaip_perf:main(_), Script),
    tmp_file(perf, ResFile),
    atom_concat('--result=', ResFile, ResOpt),
    (   option(verbose(true), Opts) -> Err = std ; Err = null ),
    ( option(stack_limit(SL), Opts) -> true ; SL = '16g' ),
    ( option(table_space(TS), Opts) -> true ; TS = '8g' ),
    format(atom(SLOpt), '--stack_limit=~w', [SL]),
    format(atom(TSOpt), '--table-space=~w', [TS]),
    process_create(Swipl,
                   ['-q', SLOpt, Script, '--child', ResOpt, TSOpt, File],
                   [ stdin(null), stdout(null), stderr(Err),
                     process(Pid) ]),
    get_time(T0),
    process_wait(Pid, Status, [timeout(TO)]),
    get_time(T1),
    Ms is (T1-T0)*1000,
    (   Status == timeout
    ->  process_kill(Pid, kill), process_wait(Pid, _),
        Result = result(File, '-', timeout, 0, Ms, 0)
    ;   catch(read_file_to_terms(ResFile, [Result0], []), _, fail)
    ->  Result = Result0
    ;   Result = result(File, '-', crashed(Status), 0, Ms, 0)
    ),
    catch(delete_file(ResFile), _, true).

child([File], Opts) :-
    option(result(ResFile), Opts),
    !,
    set_table_space(Opts),
    boot(BootMs),
    run_file(File, Opts, Mode, Verdict, Ms, Inf),
    setup_call_cleanup(
        open(ResFile, write, S),
        format(S, "~q.~n", [result(File, Mode, Verdict, BootMs, Ms, Inf)]),
        close(S)),
    halt(0).
child(_, _) :-
    format(user_error, "usage: --child --result=File KB~n", []),
    halt(2).

run_in_process(File, Opts, result(File, Mode, Verdict, BootMs, Ms, Inf)) :-
    set_table_space(Opts),
    boot(BootMs),
    run_file(File, Opts, Mode, Verdict, Ms, Inf).

set_table_space(Opts) :-
    ( option(table_space(TS), Opts) -> true ; TS = '8g' ),
    size_bytes(TS, Bytes),
    set_prolog_flag(table_space, Bytes).

size_bytes(N, N) :- integer(N), !.
size_bytes(A, Bytes) :-
    atom_codes(A, Cs),
    append(Ds, [U], Cs),
    memberchk(U-Mul, [0'k-1024, 0'm-1048576, 0'g-1073741824]),
    !,
    number_codes(N, Ds),
    Bytes is N*Mul.
size_bytes(A, Bytes) :-
    atom_number(A, Bytes).

%   Loading ergoAIp itself is the engine boot; reported apart from the run.
boot(Ms) :-
    get_time(T0),
    engine_dir(E),
    atom_concat(E, '/src/golden', Golden),
    atom_concat(E, '/src/ergoaip_compiler', Compiler),
    use_module(Golden),
    use_module(Compiler),
    get_time(T1),
    Ms is (T1-T0)*1000.

		 /*******************************
		 *          RUN ONE KB          *
		 *******************************/

run_file(File, Opts, Mode, Verdict, Ms, Inf) :-
    (   golden:golden_file(File, Old), exists_file(Old)
    ->  Mode = golden,
        measure(golden_verdict(File, Verdict), Ms, Inf)
    ;   Mode = load,
        ( option(timeout(TO), Opts) -> true ; TO = 600 ),
        measure(load_verdict(File, TO, Verdict), Ms, Inf)
    ).

measure(Goal, Ms, Inf) :-
    statistics(inferences, I0),
    get_time(T0),
    call(Goal),
    get_time(T1),
    statistics(inferences, I1),
    Ms is (T1-T0)*1000,
    Inf is I1-I0.

golden_verdict(File, Verdict) :-
    catch(golden:run_golden(File, V), E, V = run_error(E)),
    verdict_tag(V, Verdict).

verdict_tag(diff(Missing, Extra, _), diff(NM, NE)) :- !,
    length(Missing, NM), length(Extra, NE).
verdict_tag(diff_listorder(Missing, _), listorder(NM)) :- !,
    length(Missing, NM).
verdict_tag(load_error(_), load_error) :- !.
verdict_tag(run_error(_), run_error) :- !.
verdict_tag(V, V).

%   Load in the file's own directory, as ErgoAI's harness does, so the
%   KB's relative loads and its `temp` output stay where they belong.
load_verdict(File, TO, Verdict) :-
    file_directory_name(File, Dir),
    gensym(perf_kb, M),
    setup_call_cleanup(
        working_directory(Old, Dir),
        catch(( call_with_time_limit(TO,
                    ergoaip_compiler:load_ergo(File, M, Report)),
                Report = report(queries(Qs), _),
                length(Qs, NQ),
                Verdict = loaded(NQ) ),
              E,
              ( E == time_limit_exceeded -> Verdict = timeout
              ; Verdict = load_error )),
        working_directory(_, Old)).

		 /*******************************
		 *            REPORT            *
		 *******************************/

summary(Rs) :-
    aggregate_all(sum(Ms), member(result(_,_,_,_,Ms,_), Rs), TotalMs),
    aggregate_all(sum(Inf), member(result(_,_,_,_,_,Inf), Rs), TotalInf),
    findall(K, ( member(result(_,_,V,_,_,_), Rs), verdict_key(V, K) ), Ks0),
    msort(Ks0, Ks),
    clumped(Ks, Counts),
    format("~nTotal run time ~1f s, ~D inferences~n", [TotalMs/1000, TotalInf]),
    forall(member(K-C, Counts), format("  ~w~t~20|~d~n", [K, C])).

verdict_key(V, K) :- compound(V), !, functor(V, K, _).
verdict_key(V, V).

write_tsv(File, Rs) :-
    setup_call_cleanup(
        open(File, write, S),
        ( format(S, "file\tmode\tverdict\tboot_ms\trun_ms\tinferences~n", []),
          forall(member(result(F, Mode, V, B, Ms, Inf), Rs),
                 format(S, "~w\t~w\t~w\t~0f\t~0f\t~d~n", [F, Mode, V, B, Ms, Inf])) ),
        close(S)),
    format("wrote ~w~n", [File]).

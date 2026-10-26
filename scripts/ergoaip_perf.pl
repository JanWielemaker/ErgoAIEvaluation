/*  ergoaip_perf.pl — run the ErgoEngine/ErgoAI-performance programs on
    ergoAIp (ErgoAI on SWI-Prolog, ergoAIstudio2/ergoAIp) and time them.

    Usage (from anywhere):

        swipl scripts/ergoaip_perf.pl [options] [path ...]

    Each path is a .flr/.ergo file or a directory (its .flr and .ergo files,
    minus the helper KBs that the tests load themselves).  With no path the
    directory ErgoAI-performance/testall.sh runs is used: cyc150.
    Run with --help for the options (opt_type/3 and opt_help/2 below).

    The size defaults are far above SWI-Prolog's 1 GB: tokenizing the
    6-23 MB compiletests KBs and tabling some cyc150 queries overflow the
    standard limits.

    A file with a golden transcript (<base>_old) is run the way ErgoAI's
    test_one_file.sh runs it: load, %test, compare the sorted `temp` with
    the golden.  This uses ergoAIp's own golden runner (src/golden.pl), so
    verdicts match the project's golden scoreboard.  Any other file is
    loaded, which also runs its `?-` queries, and only timed.

    The run time of a golden program is split into CONVERT (ergo2p), LOAD
    (compilation plus the file's own load-time `?-` queries, which for a
    cyc150 program include loading the shared core KB) and SOLVE (`%test`).
    A plain load is reported as one LOAD phase.  Run times include
    compilation.  ergo2p conversion is cached across runs
    (src/ergo2p/conv_cache.pl); set ERGOAIP_CONV_CACHE=off to time it.
*/

:- module(ergoaip_perf, []).
:- use_module(library(main)).
:- use_module(library(process)).
:- use_module(library(filesex)).
:- use_module(library(lists)).
:- use_module(library(option)).
:- use_module(library(apply)).
:- use_module(library(time)).
:- use_module(library(readutil)).
:- use_module(library(aggregate)).
:- use_module(library(gensym)).
:- use_module(library(occurs)).
:- use_module(library(yall)).

:- initialization(main, main).

:- multifile
    user:file_search_path/2,
    user:prolog_file_type/2.

here.

user:file_search_path(ergo_eval, Dir) :-
    source_file(here, File),
    file_directory_name(File, ScriptDir),
    file_directory_name(ScriptDir, Dir).
user:file_search_path(ergo_engine, ergo_eval(ergoAIstudio2/ergoAIp)).
user:file_search_path(ergo_perf,   ergo_eval('ErgoEngine/ErgoAI-performance')).

%   The source files of a test: directory_member/3 and
%   absolute_file_name/3 find them with file_type(ergo).
user:prolog_file_type(flr,  ergo).
user:prolog_file_type(ergo, ergo).

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
		 *           OPTIONS            *
		 *******************************/

opt_type(timeout,     timeout,     nonneg).
opt_type(out,         out,         file(write)).
opt_type(in_process,  in_process,  boolean).
opt_type(resume,      resume,      boolean).
opt_type(interactive, interactive, boolean).
opt_type(i,           interactive, boolean).
opt_type(verbose,     verbose,     boolean).
opt_type(v,           verbose,     boolean).
opt_type(stack_limit, stack_limit, atom).
opt_type(table_space, table_space, atom).
opt_type(engine,      engine,      oneof([ergoaip, xsb])).
opt_type(goal,        goal,        atom).
opt_type(runergo,     runergo,     file).
opt_type(child,       child,       boolean).
opt_type(result,      result,      file).

opt_meta(timeout,     'SECS').
opt_meta(stack_limit, 'SIZE').
opt_meta(table_space, 'SIZE').
opt_meta(goal,        'GOAL').
opt_meta(runergo,     'FILE').

opt_help(help(header),
         [ ansi(bold, "Run the ErgoAI-performance programs on ergoAIp \c
                       and time them.", []) ]).
opt_help(help(usage),
         " [option ...] [file-or-directory-or-suite ...]").
opt_help(help(footer),
         "SIZE takes a k, m or g suffix.  Without a path, run cyc150.  \c
          A suite is a .pl file of bench(File, Goal) terms: load File \c
          (relative to the suite) and run the classic Ergo Goal.").
opt_help(engine,
         "ergoaip (default) or xsb: ErgoAI on XSB through runergo \c
          (load and goal programs only; golden files are just loaded)").
opt_help(goal,
         "Run this classic Ergo goal after loading each file").
opt_help(runergo,
         "ErgoAI's runergo (default ErgoEngine/ErgoAI/runergo)").
opt_help(timeout,
         "Per-file wall-clock limit (default 600)").
opt_help(out,
         "Also write the results as TSV (file, mode, verdict, boot, run, \c
          convert, load and solve ms, inferences, solve inferences, \c
          peak RSS MB)").
opt_help(resume,
         "With --out: keep an existing TSV, skip the files it has a row \c
          for and append the others").
opt_help(in_process,
         "Run all files in this process instead of one fresh swipl per \c
          file (faster to start, but KB state can leak between files)").
opt_help(interactive,
         "Enter the Prolog toplevel when done (with --in_process, the \c
          engine, the last KB and its tables are still loaded)").
opt_help(verbose,
         "Show the engine's stderr (child processes)").
opt_help(stack_limit,
         "Prolog stack limit per child (default 16g)").
opt_help(table_space,
         "Table space per child (default 8g)").
opt_help(child,
         "Internal: run as the child process for one file").
opt_help(result,
         "Internal: file the child writes its result to").

%   Option defaults, applied to the parsed options.
default_options([timeout(600), stack_limit('16g'), table_space('8g')]).

%   argv_options/3 does the type checking; sizes are atoms, check them here.
check_sizes(Opts) :-
    forall(( member(O, [stack_limit, table_space]),
             Opt =.. [O, V], memberchk(Opt, Opts) ),
           (   size_bytes(V, _)
           ->  true
           ;   print_message(error, ergoaip_perf(not_a_size(O, V))),
               halt(1)
           )).

		 /*******************************
		 *            DRIVER            *
		 *******************************/

main(Argv) :-
    argv_options(Argv, Paths0, Opts0),
    check_sizes(Opts0),
    default_options(Defs),
    merge_options(Opts0, Defs, Opts),
    (   option(child(true), Opts)
    ->  child(Paths0, Opts)
    ;   set_lib_path,
        set_test_time_limit(Opts),
        (   Paths0 == []
        ->  Paths = [ergo_perf(cyc150)]
        ;   Paths = Paths0
        ),
        foldl(expand_path, Paths, Files0, []),
        maplist(with_goal(Opts), Files0, Files1),
        list_to_set(Files1, Files2),
        start_tsv(Opts, Done),
        exclude(item_done(Done), Files2, Files),
        length(Files, N),
        length(Done, ND),
        print_message(informational, ergoaip_perf(files(N, ND))),
        foldl(run_and_report(Opts, N), Files, 1-[], _-Rs0),
        reverse(Rs0, Rs),
        summary(Rs),
        (   option(out(Out), Opts)
        ->  print_message(informational, ergoaip_perf(wrote(Out)))
        ;   true
        ),
        (   option(interactive(true), Opts)
        ->  cli_enable_development_system
        ;   true
        )
    ).

/*  ergoAIp finds the packages that ErgoAI ships (?- [prettyprint>>pp],
    the argumentation theories, ...) through ERGOAIP_LIB_PATH.  golden.pl
    derives it only for files below ErgoAI-testsuite, so set it here.
    Child processes inherit it.                                         */
set_lib_path :-
    (   getenv('ERGOAIP_LIB_PATH', _)
    ->  true
    ;   absolute_file_name(ergo_eval('ErgoEngine/ErgoAI/pkgs'), Pkgs,
                           [file_type(directory), access(exist)]),
        absolute_file_name(ergo_eval('ErgoEngine/ErgoAI/ergo_lib'), Lib,
                           [file_type(directory), access(exist)]),
        atomic_list_concat([Pkgs, Lib], :, P),
        setenv('ERGOAIP_LIB_PATH', P)
    ).

/*  golden.pl stops %test after ERGOAIP_TIME_LIMIT seconds (default 60)
    and the load after ERGOAIP_LOAD_TIME_LIMIT (default 20), long before
    our own --timeout.  Raise both to match.                             */
set_test_time_limit(Opts) :-
    option(timeout(TO), Opts),
    forall(member(Var, ['ERGOAIP_TIME_LIMIT', 'ERGOAIP_LOAD_TIME_LIMIT']),
           (   getenv(Var, _) -> true ; setenv(Var, TO) )).

/*  An ITEM is a program to run: a file, or goal(File, Goal) — load File,
    then run the classic Ergo Goal (a suite entry, or a file with --goal).
    Its KEY names it in the TSV, so --resume can skip it.                 */
with_goal(Opts, File, goal(File, Goal)) :-
    atom(File),
    option(goal(Goal), Opts),
    !.
with_goal(_, Item, Item).

item_key(goal(File, Goal), Key) :- !,
    format(atom(Key), '~w :: ~w', [File, Goal]).
item_key(File, File).

item_done(Done, Item) :-
    item_key(Item, Key),
    memberchk(Key, Done).

item_file(goal(File, _), File) :- !.
item_file(File, File).

expand_path(Path, Items, Tail) :-
    absolute_file_name(Path, Abs, [file_errors(fail), access(read),
                                   extensions([pl])]),
    file_name_extension(_, pl, Abs),
    !,
    suite_items(Abs, Items0),
    append(Items0, Tail, Items).
expand_path(Path, Files, Tail) :-
    absolute_file_name(Path, Abs, [file_errors(fail), access(exist),
                                   file_type(directory)]),
    !,
    findall(F, ( directory_member(Abs, F, [file_type(ergo)]),
                 file_base_name(F, E),
                 \+ helper_file(E) ),
            Fs0),
    sort(Fs0, Fs),
    append(Fs, Tail, Files).
expand_path(Path, [Abs|Tail], Tail) :-
    absolute_file_name(Path, Abs, [file_type(ergo), file_errors(fail),
                                   access(read)]),
    !.
expand_path(Path, Tail, Tail) :-
    print_message(warning, ergoaip_perf(no_file(Path))).

%   A suite: bench(File, Goal) terms, File relative to the suite file.
suite_items(Suite, Items) :-
    file_directory_name(Suite, Dir),
    read_file_to_terms(Suite, Terms, []),
    findall(goal(Abs, Goal),
            ( member(bench(Rel, Goal0), Terms),
              directory_file_path(Dir, Rel, Abs0),
              absolute_file_name(Abs0, Abs),
              atom_string(Goal, Goal0) ),
            Items).

run_and_report(Opts, N, Item, I-Rs, I1-[R|Rs]) :-
    I1 is I + 1,
    (   option(engine(xsb), Opts)
    ->  run_xsb(Item, Opts, R)
    ;   option(in_process(true), Opts)
    ->  run_in_process(Item, Opts, R)
    ;   run_child(Item, Opts, R)
    ),
    print_message(information, ergoaip_perf(done(I, N, R))),
    (   option(out(Out), Opts) -> tsv_row(Out, Opts, R) ; true ).

		 /*******************************
		 *     ONE PROCESS PER FILE     *
		 *******************************/

/*  The child writes its result to a file rather than to stdout: the KBs
    print to stdout themselves, and a full pipe would block the child.
    Its stdout goes to a file too: the last line a GOAL prints is the
    benchmark's own report, kept as the result's `output`.               */
run_child(Item, Opts, Result) :-
    option(timeout(TO), Opts),
    source_file(ergoaip_perf:main(_), Script),
    tmp_file(perf, ResFile),
    tmp_file(perf_out, OutFile),
    atom_concat('--result=', ResFile, ResOpt),
    (   option(verbose(true), Opts) -> Err = std ; Err = null ),
    option(stack_limit(SL), Opts),
    option(table_space(TS), Opts),
    format(atom(SLOpt), '--stack_limit=~w', [SL]),
    format(atom(TSOpt), '--table-space=~w', [TS]),
    (   Item = goal(File, Goal)
    ->  atom_concat('--goal=', Goal, GoalOpt),
        GoalOpts = [GoalOpt]
    ;   File = Item,
        GoalOpts = []
    ),
    append([['-q', SLOpt, Script, '--child', ResOpt, TSOpt], GoalOpts, [File]],
           Args),
    setup_call_cleanup(
        open(OutFile, write, OS),
        process_create(prolog(self), Args,
                       [ stdin(null), stdout(stream(OS)), stderr(Err),
                         process(Pid) ]),
        close(OS)),
    get_time(T0),
    process_wait(Pid, Status, [timeout(TO)]),
    get_time(T1),
    Ms is (T1-T0)*1000,
    (   Status == timeout
    ->  process_kill(Pid, kill), process_wait(Pid, _),
        Result = result(Item, '-', timeout, 0, Ms, 0, [])
    ;   catch(read_file_to_terms(ResFile, [Result0], []), _, fail)
    ->  Result0 = result(_, Mode, V, B, Ms0, Inf, Ps0),
        last_output_line(OutFile, Line),
        Result = result(Item, Mode, V, B, Ms0, Inf, [output-text(Line)|Ps0])
    ;   Result = result(Item, '-', crashed(Status), 0, Ms, 0, [])
    ),
    catch(delete_file(ResFile), _, true),
    catch(delete_file(OutFile), _, true).

%   The last non-blank line of File, '' if there is none.
last_output_line(File, Line) :-
    catch(read_file_to_string(File, Str, []), _, Str = ""),
    split_string(Str, "\n", " \t\r", Lines0),
    exclude(==(""), Lines0, Lines),
    (   last(Lines, Line0)
    ->  split_string(Line0, "\t", "", Parts),
        atomic_list_concat(Parts, ' ', Line)
    ;   Line = ''
    ).

child([File], Opts) :-
    option(result(ResFile), Opts),
    !,
    set_table_space(Opts),
    boot(BootMs),
    run_file(File, Opts, Mode, Verdict, Ms, Inf, Phases0),
    peak_rss_kb(KB),
    Phases = [peak_rss-kb(KB) | Phases0],
    setup_call_cleanup(
        open(ResFile, write, S),
        format(S, "~q.~n", [result(File, Mode, Verdict, BootMs, Ms, Inf, Phases)]),
        close(S)),
    halt(0).
child(_, _) :-
    print_message(error, ergoaip_perf(child_usage)),
    halt(2).

/*  The process's peak resident set size, from /proc/self/status (VmHWM, in
    KB).  0 where /proc is not available.                                */
peak_rss_kb(KB) :-
    catch(setup_call_cleanup(
              open('/proc/self/status', read, S),
              read_string(S, _, Str),
              close(S)), _, fail),
    split_string(Str, "\n", "", Lines),
    member(L, Lines),
    string_concat("VmHWM:", Rest, L),
    split_string(Rest, " \t", " \tkB", Parts),
    member(P, Parts), P \== "",
    number_string(KB, P), !.
peak_rss_kb(0).

peak_mb(Phases, MB) :-
    ( memberchk(peak_rss-kb(KB), Phases) -> MB is KB // 1024 ; MB = 0 ).

run_in_process(Item, Opts0,
               result(Item, Mode, Verdict, BootMs, Ms, Inf, Phases)) :-
    (   Item = goal(File, Goal)
    ->  merge_options([goal(Goal)], Opts0, Opts)
    ;   File = Item,
        Opts = Opts0
    ),
    set_table_space(Opts),
    boot(BootMs),
    run_file(File, Opts, Mode, Verdict, Ms, Inf, Phases0),
    peak_rss_kb(KB),
    Phases = [peak_rss-kb(KB) | Phases0].

set_table_space(Opts) :-
    option(table_space(TS), Opts),
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
    use_module(ergo_engine(src/golden)),
    use_module(ergo_engine(src/ergoaip_compiler)),
    get_time(T1),
    Ms is (T1-T0)*1000.

		 /*******************************
		 *          RUN ONE KB          *
		 *******************************/

%   Tables are abolished before a program, not after it, so that -i can
%   explore the tables the last program left.
run_file(File, Opts, Mode, Verdict, Ms, Inf, Phases) :-
    abolish_all_tables,
    (   option(goal(Goal), Opts)
    ->  Mode = goal,
        option(timeout(TO), Opts),
        measure(goal_verdict(File, Goal, TO, Verdict, Phases), Ms, Inf)
    ;   golden:golden_file(File, Old), exists_file(Old)
    ->  Mode = golden,
        measure(golden_verdict(File, Verdict), Ms, Inf),
        golden:last_phases(Phases)
    ;   Mode = load,
        option(timeout(TO), Opts),
        measure(load_verdict(File, TO, Verdict), Ms, Inf),
        Phases = [load-ms(Ms, Inf)]
    ).

phase_ms(P, Phases, Ms) :-
    ( memberchk(P-ms(Ms0, _), Phases) -> Ms = Ms0 ; Ms = 0 ).
phase_inf(P, Phases, Inf) :-
    ( memberchk(P-ms(_, Inf0), Phases) -> Inf = Inf0 ; Inf = 0 ).

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
verdict_tag(run_error(E), out_of_memory) :-
    sub_term(R, E), nonvar(R), R = resource_error(_), !.
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

/*  A goal program: load File, then run the classic Ergo Goal, the way the
    listener runs it (src/ergoaip_repl.pl), except that only a goal with
    an explicit update goes through kb_update/2.  Verdict `solved` or
    `failed`; the two phases are LOAD and SOLVE.                         */
goal_verdict(File, Goal, TO, Verdict, Phases) :-
    file_directory_name(File, Dir),
    gensym(perf_kb, M),
    State = state(none, []),
    setup_call_cleanup(
        working_directory(Old, Dir),
        catch(call_with_time_limit(TO, run_goal(File, M, Goal, State)),
              E, goal_error(E, State)),
        working_directory(_, Old)),
    State = state(Verdict0, Phases),
    (   Verdict0 == none -> Verdict = load_error ; Verdict = Verdict0 ).

run_goal(File, M, Goal, State) :-
    measure(ergoaip_compiler:load_ergo(File, M, _), LMs, LInf),
    nb_setarg(2, State, [load-ms(LMs, LInf)]),
    nb_setarg(1, State, run_error),
    perf_goal(M, Goal, G),
    measure(( call(G) -> V = solved ; V = failed ), SMs, SInf),
    nb_setarg(1, State, V),
    nb_setarg(2, State, [load-ms(LMs, LInf), test-ms(SMs, SInf)]).

goal_error(time_limit_exceeded, State) :- !,
    nb_setarg(1, State, timeout).
goal_error(E, State) :-
    sub_term(R, E), nonvar(R), R = resource_error(_), !,
    nb_setarg(1, State, out_of_memory).
goal_error(_, State) :-
    arg(1, State, V0),
    (   V0 == none -> true ; nb_setarg(1, State, run_error) ).

perf_goal(M, Classic0, Goal) :-
    normalize_space(atom(Classic1), Classic0),
    (   sub_atom(Classic1, _, 1, 0, '.') -> Classic = Classic1
    ;   atom_concat(Classic1, '.', Classic) ),
    ergoaip_compiler:ergo2p_string(Classic, Ergp),
    ergoaip_compiler:push_ergoaip_ops(ergoaip_perf_read),
    term_string(T, Ergp, [module(ergoaip_perf_read)]),
    (   nonvar(T), T = (?- G) -> true ; G = T ),
    (   update_goal(G)
    ->  Goal = ergoaip_compiler:kb_update(M, G)
    ;   ergoaip_compiler:kb_goal(M, G, Exec),
        Goal = call_delays(Exec, _)
    ).

/*  Only an explicit update goes through kb_update/2, whose transaction
    logs every assert (generate_net/1 makes millions) and which abolishes
    the module's tables afterwards: that is not part of a benchmark, and
    -i should find the tables.  A `%` call that updates nothing is just a
    call.                                                                 */
update_goal(G) :- var(G), !, fail.
update_goal(G) :-
    compound(G),
    functor(G, F, _),
    memberchk(F, [insert, insertall, delete, deleteall,
                  btinsert, btdelete, insertrule, deleterule]), !.
update_goal((A , B)) :- ( update_goal(A) ; update_goal(B) ), !.

		 /*******************************
		 *        ERGOAI ON XSB         *
		 *******************************/

/*  --engine=xsb runs an item with ErgoAI's runergo, in the file's own
    directory.  The command times itself in the engine: walltime/1 before
    and after the load and the goal, printed as one marker line.  GNU
    timeout kills the whole process group (runergo is a shell script that
    starts xsb), and /usr/bin/time reports the peak RSS of the tree.
    A golden file is only loaded here.                                    */
run_xsb(Item, Opts, Result) :-
    item_file(Item, File),
    option(timeout(TO), Opts),
    runergo(Opts, RunErgo),
    file_directory_name(File, Dir),
    file_base_name(File, Base),
    file_name_extension(Name, _, Base),
    (   Item = goal(_, Goal0)
    ->  normalize_space(atom(Goal1), Goal0),
        (   atom_concat(Goal, '.', Goal1) -> true ; Goal = Goal1 ),
        Mode = goal
    ;   Goal = '\\true',
        Mode = load
    ),
    format(atom(Cmd),
           "chatter{off}, walltime(?PerfT0)@\\plg, [~q], \c
            walltime(?PerfT1)@\\plg, (~w), walltime(?PerfT2)@\\plg, \c
            writeln(ergoaip_perf_times(?PerfT0,?PerfT1,?PerfT2))@\\plg, \c
            \\halt.",
           [Name, Goal]),
    tmp_file(xsb_out, OutFile),
    tmp_file(xsb_err, ErrFile),
    tmp_file(xsb_time, TimeFile),
    (   option(verbose(true), Opts) -> Err = std ; Err = stream(ES) ),
    format(atom(TOArg), '~w', [TO]),
    setup_call_cleanup(
        ( open(OutFile, write, OS), open(ErrFile, write, ES) ),
        process_create(path(timeout),
                       [ '-s', 'KILL', TOArg,
                         '/usr/bin/time', '-f', '%M', '-o', TimeFile,
                         RunErgo, '--nobanner', '--noprompt', '--nofeedback',
                         '--quietload', '-e', Cmd ],
                       [ cwd(Dir), stdin(null), stdout(stream(OS)),
                         stderr(Err), process(Pid) ]),
        ( close(OS), close(ES) )),
    get_time(T0),
    process_wait(Pid, Status),
    get_time(T1),
    Ms is (T1-T0)*1000,
    xsb_peak_kb(TimeFile, KB),
    xsb_output(OutFile, Times, Line),
    (   Times = ergoaip_perf_times(W0, W1, W2)
    ->  Verdict = solved,
        LMs is (W1-W0)*1000,
        SMs is (W2-W1)*1000,
        BootMs is max(0, Ms - (W2-W0)*1000),
        Phases = [load-ms(LMs, 0), test-ms(SMs, 0)]
    ;   Status == exit(137)
    ->  ( Ms >= TO*1000 - 1000 -> Verdict = timeout ; Verdict = crashed(killed(9)) ),
        BootMs = 0, Phases = []
    ;   xsb_failure(ErrFile, Verdict),
        BootMs = 0, Phases = []
    ),
    (   Mode == load, Verdict == solved -> Verdict1 = loaded ; Verdict1 = Verdict ),
    Result = result(Item, Mode, Verdict1, BootMs, Ms, 0,
                    [ peak_rss-kb(KB), output-text(Line) | Phases ]),
    maplist([F]>>catch(delete_file(F), _, true), [OutFile, ErrFile, TimeFile]).

runergo(Opts, RunErgo) :-
    (   option(runergo(R), Opts)
    ->  absolute_file_name(R, RunErgo, [access(execute)])
    ;   absolute_file_name(ergo_eval('ErgoEngine/ErgoAI/runergo'), RunErgo,
                           [access(execute)])
    ).

xsb_peak_kb(File, KB) :-
    catch(read_file_to_string(File, Str, []), _, Str = ""),
    split_string(Str, "\n", " \t", Lines),
    (   member(L, Lines), number_string(KB, L) -> true ; KB = 0 ).

%   The marker line, and the last line the program printed before it.
%   `@\plg` hands writeln/1 Ergo's internal HiLog form, so the marker
%   arrives as flapply(ergoaip_perf_times,T0,T1,T2).
xsb_output(File, Times, Line) :-
    catch(read_file_to_string(File, Str, []), _, Str = ""),
    split_string(Str, "\n", " \t\r", Lines0),
    exclude(==(""), Lines0, Lines),
    (   append(Before, [M | _], Lines),
        sub_string(M, _, _, _, "ergoaip_perf_times"),
        catch(term_string(T, M), _, fail),
        (   T = flapply(ergoaip_perf_times, W0, W1, W2)
        ->  Times = ergoaip_perf_times(W0, W1, W2)
        ;   Times = T
        )
    ->  true
    ;   Times = none, Before = Lines
    ),
    (   last(Before, L0)
    ->  split_string(L0, "\t", "", Parts),
        atomic_list_concat(Parts, ' ', Line)
    ;   Line = ''
    ).

xsb_failure(ErrFile, Verdict) :-
    catch(read_file_to_string(ErrFile, Err, []), _, Err = ""),
    (   sub_string(Err, _, _, _, "memory") -> Verdict = out_of_memory
    ;   ( sub_string(Err, _, _, _, "++Error") ; sub_string(Err, _, _, _, "++Abort") )
    ->  Verdict = run_error
    ;   Verdict = failed
    ).

		 /*******************************
		 *            REPORT            *
		 *******************************/

summary(Rs) :-
    aggregate_all(sum(Ms), member(result(_,_,_,_,Ms,_,_), Rs), TotalMs),
    aggregate_all(sum(Inf), member(result(_,_,_,_,_,Inf,_), Rs), TotalInf),
    aggregate_all(sum(L), ( member(result(_,_,_,_,_,_,P), Rs),
                            phase_ms(load, P, L) ), LoadMs),
    aggregate_all(sum(S), ( member(result(_,_,_,_,_,_,P), Rs),
                            phase_ms(test, P, S) ), SolveMs),
    findall(K, ( member(result(_,_,V,_,_,_,_), Rs), verdict_key(V, K) ), Ks0),
    msort(Ks0, Ks),
    clumped(Ks, Counts),
    print_message(information,
                  ergoaip_perf(summary(TotalMs, TotalInf, LoadMs, SolveMs,
                                       Counts))).

verdict_key(V, K) :- compound(V), !, functor(V, K, _).
verdict_key(V, V).

%   The TSV gets its header before the first file and a row as soon as
%   each file is done, so an interrupted run keeps what it measured and
%   --resume can continue it.  Done are the files the TSV already has.
start_tsv(Opts, Done) :-
    option(out(Out), Opts),
    !,
    (   option(resume(true), Opts),
        exists_file(Out)
    ->  tsv_files(Out, Done)
    ;   tsv_header(Out),
        Done = []
    ).
start_tsv(_, []).

tsv_files(File, Files) :-
    read_file_to_string(File, Str, []),
    split_string(Str, "\n", "", [_Header|Lines]),
    findall(F, ( member(L, Lines),
                 L \== "",
                 split_string(L, "\t", "", [FS|_]),
                 atom_string(F, FS) ),
            Files).

tsv_header(File) :-
    setup_call_cleanup(
        open(File, write, S),
        format(S, "file\tmode\tverdict\tboot_ms\trun_ms\tconvert_ms\t\c
                   load_ms\tsolve_ms\tinferences\tsolve_inferences\t\c
                   peak_rss_mb\tengine\toutput~n", []),
        close(S)).

%   `file` is the item's key: the file, or `File :: Goal`.  `output` is
%   the last line a goal printed (the benchmark's own report).
tsv_row(File, Opts, result(Item, Mode, V, B, Ms, Inf, P)) :-
    item_key(Item, F),
    option(engine(Engine), Opts, ergoaip),
    phase_ms(convert, P, CMs), phase_ms(load, P, LMs),
    phase_ms(test, P, SMs), phase_inf(test, P, SInf),
    peak_mb(P, MB),
    ( memberchk(output-text(Out), P) -> true ; Out = '' ),
    setup_call_cleanup(
        open(File, append, S),
        format(S, "~w\t~w\t~w\t~0f\t~0f\t~0f\t~0f\t~0f\t~d\t~d\t~d\t~w\t~w~n",
               [F, Mode, V, B, Ms, CMs, LMs, SMs, Inf, SInf, MB, Engine, Out]),
        close(S)).

		 /*******************************
		 *           MESSAGES           *
		 *******************************/

:- multifile prolog:message//1.

prolog:message(ergoaip_perf(Msg)) -->
    message(Msg).

message(files(N, 0)) -->
    !,
    [ 'ergoaip_perf: ~D file(s)'-[N] ].
message(files(N, Done)) -->
    [ 'ergoaip_perf: ~D file(s), ~D done before'-[N, Done] ].
message(done(I, N, result(Item, Mode, Verdict, _Boot, Ms, Inf, Phases))) -->
    { item_key(Item, File),
      rel_file(File, Rel),
      phase_ms(load, Phases, LMs), phase_ms(test, Phases, SMs),
      peak_mb(Phases, MB)
    },
    [ '[~d/~d] ~w~t~92| ~w ~w ~t~12+ ~t~1f s~10+ ~t~D inf~18+  \c
       load ~t~1f s~9+  solve ~t~1f s~9+  peak ~t~D MB~10+'-
      [I, N, Rel, Mode, Verdict, Ms/1000, Inf, LMs/1000, SMs/1000, MB] ].
message(summary(TotalMs, TotalInf, LoadMs, SolveMs, Counts)) -->
    [ 'Total run time ~1f s, ~D inferences'-[TotalMs/1000, TotalInf], nl,
      '  load ~1f s, solve ~1f s'-[LoadMs/1000, SolveMs/1000] ],
    counts(Counts).
message(wrote(File)) -->
    [ 'wrote ~w'-[File] ].
message(no_file(Path)) -->
    [ '~w: no such file or directory'-[Path] ].
message(not_a_size(Opt, Value)) -->
    [ '--~w=~w: not a size (e.g. 512m, 16g)'-[Opt, Value] ].
message(child_usage) -->
    [ 'usage: --child --result=File KB' ].

counts([]) --> [].
counts([K-C|T]) -->
    [ nl, '  ~w~t~20|~d'-[K, C] ],
    counts(T).

%   File relative to ErgoAI-performance or else to this repository, for
%   the progress lines.
rel_file(File, Rel) :-
    member(Base, [ergo_perf(.), ergo_eval(.)]),
    absolute_file_name(Base, PD, [file_type(directory)]),
    atom_concat(PD, '/', PDS),
    atom_concat(PDS, Rel, File),
    !.
rel_file(File, File).

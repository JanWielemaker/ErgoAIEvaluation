/*  ergoaip_cases.pl — load the cyc150 core KB once, then solve every test
    against it, each in its own SWI-Prolog snapshot.

    Usage:

        swipl scripts/ergoaip_cases.pl [options] [cyc150-dir]

    Options:
        --threads=N      solve N cases concurrently (default 1)
        --table-space=Sz table space per thread (default 8g)
        --out=File       also write the results as TSV, a row as soon as
                         its case is done, so a crash keeps the finished cases
        --max=N          only the first N cases
        --agc-margin=N   set the agc_margin flag (atom-GC frequency)
        --shard=K/N      of those, only the cases whose index is K modulo N,
                         to split them over N processes

    Every cyc150 program is the same 18-line header (argumentation theory,
    `\overrides` rules and the `[+…]` loads of the shared core KB) followed
    by its own CASE: hypothesis facts, a few rules, `%pretest` and `%test`.
    This driver loads the header once into module `kb`, then for each case

        snapshot(( add the case's statements to kb, run %pretest ))

    so a case's facts and rules are discarded when it is done and never seen
    by another case.  Tables are thread-private, so each case starts from
    empty tables; with --threads=N the cases run concurrently.  The case is
    solved with %pretest, which prints `SUCCESS …` when the query succeeds;
    a case passes when that line is the one its golden file expects.

    Reported per case: the time to ADD the case (convert, compile, install)
    and the time to SOLVE it, with the inferences and the thread CPU time
    of the solve.
*/

:- module(ergoaip_cases, []).
:- use_module(library(main)).
:- use_module(library(filesex)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(readutil)).
:- use_module(library(thread)).

:- initialization(main, main).

:- prolog_load_context(directory, Dir),
   file_directory_name(Dir, Root),
   asserta(root_dir(Root)).

main(Argv) :-
    argv_options(Argv, Pos, Opts),
    root_dir(Root),
    (   Pos = [Dir0|_] -> true
    ;   atom_concat(Root, '/ErgoEngine/ErgoAI-performance/cyc150', Dir0) ),
    absolute_file_name(Dir0, Dir, [file_type(directory)]),
    set_lib_path(Root),
    ( memberchk(table_space(TS), Opts) -> true ; TS = '8g' ),
    size_bytes(TS, TSBytes),
    set_prolog_flag(table_space, TSBytes),
    atom_concat(Root, '/ergoAIstudio2/ergoAIp/src/ergoaip_compiler', Compiler),
    use_module(Compiler),
    %  the vendored lexer is loaded lazily; loading code inside a snapshot
    %  does not work, so load it now
    lexer_bridge:ensure_lexer,
    ( memberchk(threads(NT), Opts) -> true ; NT = 1 ),
    (   memberchk(agc_margin(AGCM), Opts)
    ->  set_prolog_flag(agc_margin, AGCM)
    ;   true ),
    split_cases(Dir, Base, Cases0),
    (   memberchk(max(Max), Opts), length(Cases0, L0), L0 > Max
    ->  length(Cases1, Max), append(Cases1, _, Cases0)
    ;   Cases1 = Cases0 ),
    (   memberchk(shard(Shard), Opts)
    ->  shard(Shard, Cases1, Cases)
    ;   Cases = Cases1 ),
    length(Cases, NC),
    format("ergoaip_cases: ~d cases, ~d thread(s)~n", [NC, NT]),
    working_directory(_, Dir),
    measure(ergoaip_compiler:load_ergo(Base, kb, _), LoadMs, LoadInf),
    delete_file(Base),
    format("base KB loaded in ~1f s, ~D inferences~n", [LoadMs/1000, LoadInf]),
    (   memberchk(out(Out), Opts) -> open_tsv(Out) ; true ),
    get_time(T0),
    set_prolog_flag(cpu_count, NT),         % concurrent_maplist/3's pool size
    concurrent_maplist(run_case(TSBytes), Cases, Results),
    get_time(T1),
    maplist(report, Results),
    summary(Results, (T1-T0)*1000),
    (   memberchk(out(Out), Opts) -> close_tsv(Out) ; true ).

shard(Spec, All, Cases) :-
    atomic_list_concat([KA,NA], /, Spec),
    atom_number(KA, K), atom_number(NA, N),
    findall(C, ( nth0(I, All, C), I mod N =:= K ), Cases).

set_lib_path(Root) :-
    (   getenv('ERGOAIP_LIB_PATH', _) -> true
    ;   format(atom(P), '~w/ErgoEngine/ErgoAI/pkgs:~w/ErgoEngine/ErgoAI/ergo_lib',
               [Root, Root]),
        setenv('ERGOAIP_LIB_PATH', P)
    ).

size_bytes(N, N) :- integer(N), !.
size_bytes(A, Bytes) :-
    atom_codes(A, Cs), append(Ds, [U], Cs),
    memberchk(U-Mul, [0'k-1024, 0'm-1048576, 0'g-1073741824]), !,
    number_codes(N, Ds), Bytes is N*Mul.
size_bytes(A, Bytes) :- atom_number(A, Bytes).

measure(Goal, Ms, Inf) :-
    statistics(inferences, I0), get_time(T0),
    call(Goal),
    get_time(T1), statistics(inferences, I1),
    Ms is (T1-T0)*1000, Inf is I1-I0.

		 /*******************************
		 *      SPLIT BASE / CASES      *
		 *******************************/

%   The header ends with the `[+'core_files/rmt-removal-lookup-pos-1']`
%   load.  The base is written beside the programs (its loads are relative)
%   and each case to a temporary directory.
split_cases(Dir, Base, Cases) :-
    directory_files(Dir, Es0), sort(Es0, Es),
    findall(F, ( member(E, Es), atom_concat(kbq, _, E),
                 file_name_extension(_, flr, E),
                 directory_file_path(Dir, E, F) ), Files),
    Files = [First|_],
    read_file_to_string(First, S0, []),
    header_split(S0, Header, _),
    current_prolog_flag(pid, Pid),          % concurrent drivers do not clash
    format(atom(BaseName), '.cases_base_~d.flr', [Pid]),
    directory_file_path(Dir, BaseName, Base),
    write_file(Base, Header),
    tmp_file(cases, TmpDir), make_directory(TmpDir),
    maplist(case_file(Dir, TmpDir), Files, Cases).

header_split(S, Header, Rest) :-
    Marker = "rmt-removal-lookup-pos-1'].",
    sub_string(S, B, L, _, Marker), !,
    E is B+L,
    sub_string(S, 0, E, _, Header0),
    string_concat(Header0, "\n", Header),
    sub_string(S, E, _, 0, Rest).

case_file(_Dir, TmpDir, File, case(File, CaseFile, Golden)) :-
    read_file_to_string(File, S, []),
    header_split(S, _, Rest),
    file_base_name(File, B),
    directory_file_path(TmpDir, B, CaseFile),
    %  the iriprefix the case's own statements use
    string_concat(":- iriprefix{silk = \"http://vulcan.com/2008/silk#\"}.\n",
                  Rest, Case),
    write_file(CaseFile, Case),
    file_name_extension(Stem, _, File),
    atom_concat(Stem, '_old', Golden).

write_file(F, S) :-
    setup_call_cleanup(open(F, write, Out), write(Out, S), close(Out)).

		 /*******************************
		 *          RUN A CASE          *
		 *******************************/

run_case(TSBytes, case(File, CaseFile, Golden), Result) :-
    Result = result(File, Verdict, AddMs, SolveMs, SolveInf, CpuMs),
    set_prolog_flag(table_space, TSBytes),
    catch(snapshot(solve_case(CaseFile, Golden, Verdict,
                              AddMs, SolveMs, SolveInf, CpuMs)),
          E, ( Verdict = error(E), AddMs = 0, SolveMs = 0, SolveInf = 0,
               CpuMs = 0 )),
    abolish_all_tables,
    tsv_row(Result).

solve_case(CaseFile, Golden, Verdict, AddMs, SolveMs, SolveInf, CpuMs) :-
    measure(ergoaip_compiler:load_spec(kb, +CaseFile), AddMs, _),
    statistics(cputime, C0),                % of this thread
    measure(with_output_to(string(Out),
                           ( catch(once(kb:pretest), E, true) -> true ; true )),
            SolveMs, SolveInf),
    statistics(cputime, C1),
    CpuMs is (C1-C0)*1000,
    (   getenv('ERGOAIP_TABLE_STATS', _) -> table_stats ; true ),
    (   nonvar(E) -> Verdict = run_error
    ;   verdict(Out, Golden, Verdict) ).

%   The golden transcript holds %pretest's output twice (%test runs it with
%   mustDefine on and off); compare the distinct lines.
verdict(Out, Golden, Verdict) :-
    split_string(Out, "\n", " \t", L0), exclude(==(""), L0, L1), sort(L1, Got),
    (   exists_file(Golden)
    ->  read_file_to_string(Golden, G, []),
        split_string(G, "\n", " \t", G0), exclude(==(""), G0, G1), sort(G1, Want),
        (   Got == Want -> Verdict = pass
        ;   Got == [] -> Verdict = no_answer
        ;   Verdict = diff )
    ;   Verdict = no_golden ).

table_stats :-
    findall(K, ( current_table(M:V, _),
                 functor(V, N, A),
                 (   predicate_property(M:V, (dynamic)) -> T = (dynamic) ; T = tabled ),
                 K = T-(M:N/A) ), Ks0),
    msort(Ks0, Ks), clumped(Ks, KCs),
    pairs_values_sort(KCs, Sorted),
    length(Ks, Total),
    format("tables: ~D~n", [Total]),
    forall(( member(C-K, Sorted), C > 1000 ), format("  ~D~t~12| ~q~n", [C, K])).

pairs_values_sort(KCs, Sorted) :-
    findall(C-K, member(K-C, KCs), L0), sort(1, @>=, L0, Sorted).

		 /*******************************
		 *            REPORT            *
		 *******************************/

report(result(File, V, AddMs, SolveMs, Inf, CpuMs)) :-
    file_base_name(File, B),
    format("~w~t~84| ~w~t~10+ add ~t~1f s~8+  solve ~t~2f s~9+ \c
            cpu ~t~2f s~9+ ~t~D inf~16+~n",
           [B, V, AddMs/1000, SolveMs/1000, CpuMs/1000, Inf]).

summary(Rs, WallMs) :-
    aggregate_all(sum(A), member(result(_,_,A,_,_,_), Rs), AddMs),
    aggregate_all(sum(S), member(result(_,_,_,S,_,_), Rs), SolveMs),
    findall(V, member(result(_,V,_,_,_,_), Rs), Vs0), msort(Vs0, Vs),
    clumped(Vs, Counts),
    format("~nwall ~1f s for all cases; sum of add ~1f s, sum of solve ~1f s~n",
           [WallMs/1000, AddMs/1000, SolveMs/1000]),
    forall(member(K-C, Counts), format("  ~w~t~20|~d~n", [K, C])),
    statistics(agc, AGC), statistics(agc_time, AGCTime),
    statistics(agc_gained, AGCGained), statistics(atoms, Atoms),
    format("atom GC: ~D runs, ~2f s, ~D atoms reclaimed, ~D atoms now~n",
           [AGC, AGCTime, AGCGained, Atoms]),
    (   getenv('ERGOAIP_BLOB_STATS', _)
    ->  aggregate_all(count, current_blob(_, _), _),
        findall(T, current_blob(_, T), Ts0), msort(Ts0, Ts), clumped(Ts, TCs),
        forall(member(T-C, TCs), format("  blob ~w~t~30|~D~n", [T, C]))
    ;   true ).

:- dynamic tsv_stream/1.

open_tsv(File) :-
    open(File, write, S),
    format(S, "file\tverdict\tadd_ms\tsolve_ms\tsolve_inferences\tsolve_cpu_ms~n",
           []),
    flush_output(S),
    asserta(tsv_stream(S)).

tsv_row(result(F, V, A, Sv, I, C)) :-
    (   tsv_stream(S)
    ->  with_mutex(ergoaip_cases_tsv,
                   ( format(S, "~w\t~q\t~0f\t~0f\t~d\t~0f~n", [F, V, A, Sv, I, C]),
                     flush_output(S) ))
    ;   true
    ).

close_tsv(File) :-
    retract(tsv_stream(S)),
    close(S),
    format("wrote ~w~n", [File]).

#!/bin/bash
# modernize.sh DIR — minimal edits so ErgoAI 3.01 accepts the cyc150 corpus
# in DIR/cyc150 and DIR/aux_files, where DIR is a copy of ErgoAI-performance
# (never run this on the original tree), e.g.
#   cp -r ErgoEngine/ErgoAI-performance /tmp/perf && scripts/modernize.sh /tmp/perf
D=${1:?usage: modernize.sh DIR}
HERE=$(dirname "$(readlink -f "$0")")
for f in $D/cyc150/*.flr $D/cyc150/core_files/*.flr; do
  sed -i -E \
    -e 's|^:- setsemantics\{tabling\(incremental\)\}\.|// & (rejected by ErgoAI 3.01)|' \
    -e 's|^:- iriprefix +([A-Za-z]+) *= *("[^"]*") *\.|:- iriprefix{\1 = \2}.|' \
    "$f"
done
for f in $D/cyc150/kbq-*.flr; do
  sed -i -E \
    -e 's|%mustDefine\(|mustDefine(|g' \
    -e 's|^\?- [\]optimize\(class_expressions, main\) *\.|// & (not an ErgoAI 3.01 optimizer option)|' \
    "$f"
  grep -q 'iriprefix{silk' "$f" ||
    sed -i '1i :- iriprefix{silk = "http://vulcan.com/2008/silk#"}.' "$f"
done
# the KB relies on subgoal abstraction at depth 100 to terminate (terms like
# hypotheticalTerm(hypotheticalTerm(...)) grow otherwise); current XSB spells
# the old max_table_subgoal_depth flag as max_table_subgoal_size + an action
sed -i -E 's/^\?- set_prolog_flag\(max_table_subgoal_depth, *([0-9]+)\)@\\prolog\./?- set_prolog_flag(max_table_subgoal_size, \1)@\\prolog, set_prolog_flag(max_table_subgoal_size_action, abstract)@\\prolog./' $D/aux_files/silk-predicates.flr
# a bare ground/1 is an (undefined, hence false) Ergo predicate in 3.01, which
# makes %silkb#isGround always fail and starves every core rule it guards
sed -i -E 's|^%silkb#isGround\(\?X\) :- ground\(\?X\)\.|%silkb#isGround(?X) :- ground(?X)@\\prolog.|' $D/aux_files/silk-predicates_at_builtin.flr
# \baseType module and \isTypeOf method are \basetype / isTypeOf in 3.01
sed -i -E -e 's|[\]isTypeOf\(|isTypeOf(|g' -e 's|@[\]baseType|@\\basetype|g' $D/aux_files/*.flr
# old \"urn:..." IRI literals and equality(none) option
sed -i -E -e 's|[\_]"(urn:[^"]*)"|"\1"^^\\iri|g' -e 's|setsemantics\{equality\(none\)\}|setsemantics{equality=none}|' \
  $D/cyc150/core_files/*.flr $D/cyc150/kbq-*.flr
# 3.01 rejects variable tags: @{?, Iri} -> @{Iri}
sed -i -E 's|@\{\?, *("[^"]*"\^\^[\]iri)\}|@{\1}|g' $D/cyc150/core_files/*.flr $D/cyc150/kbq-*.flr
# SILK connectives in rule bodies
python3 -I "$HERE/silkconn.py" $D/cyc150/core_files/*.flr $D/cyc150/kbq-*.flr
# \io predicates are non-transactional in 3.01
sed -i -E 's/%(writeln|write|nl)\(([^)]*)\)@\\io/\1(\2)@\\io/g' $D/aux_files/*.flr $D/cyc150/kbq-*.flr $D/cyc150/core_files/*.flr
sed -i -E 's/^\?- optimize\{class_expressions, *main\} *\./\/\/ & (not an ErgoAI 3.01 optimizer option)/' $D/cyc150/kbq-*.flr

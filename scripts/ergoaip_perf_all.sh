#!/bin/bash
# Run all ErgoAI-performance test files on ergoAIp, one child process per
# file, and collect the results in $D/results.tsv (a row per finished
# file, see ergoaip_perf.pl --out).  --resume skips the files that
# already have a row, so the script can simply be restarted.
#
#   scripts/ergoaip_perf_all.sh            # in the foreground
#   nohup scripts/ergoaip_perf_all.sh &    # detached; stop it with
#                                          # systemctl --user stop 'ergoaip-perf-*.scope'
#
# Env: ERGOAIP_PERF_DIR (default ~/.cache/ergoaip-perf), ERGOAIP_PERF_MEM
# (memory cap, default 90G).
#
# The run is in the scope ergoaip-perf-<pid>, capped at $ERGOAIP_PERF_MEM
# without swap.  OOMPolicy=continue makes an OOM kill only the child (it
# shows as crashed(killed(9))); ergoaip_perf then continues with the next
# file.
D=${ERGOAIP_PERF_DIR:-$HOME/.cache/ergoaip-perf}
MEM=${ERGOAIP_PERF_MEM:-90G}
P=ErgoEngine/ErgoAI-performance
cd "$(dirname "$0")/.." || exit 1
mkdir -p "$D"
systemd-run --user --scope --quiet --unit=ergoaip-perf-$$ \
            -p MemoryMax=$MEM -p MemorySwapMax=0 -p OOMPolicy=continue \
  swipl scripts/ergoaip_perf.pl --resume --timeout=1800 --table-space=40g \
        --out="$D/results.tsv" \
        $P/compiletests $P/cyc150 $P/CYC_tests $P/CYC_tests/test0 \
        $P/PaulH_tests/test1 $P/UDF_tests $P/wine_ontology \
        >> "$D/full.log" 2>&1
echo "$(date +%T) DONE (exit $?)" >> "$D/full.log"

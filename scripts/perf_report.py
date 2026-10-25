#!/usr/bin/env python3
"""perf_report.py -- turn an ergoaip_perf.pl TSV (--out=File) into a
Markdown report: a summary and one row per test file.

    python3 scripts/perf_report.py RESULTS.tsv [--title T] [--note N] > report.md

Result classes: pass, loaded (no golden output: loaded and its queries
run without error), failed (golden mismatch, load or run error),
out-of-memory (a resource error, or a crash), timeout.
"""
import argparse
import csv
import os
import statistics


def result_class(verdict):
    if verdict == "pass":
        return "pass"
    if verdict.startswith("loaded("):
        return "loaded"
    if verdict == "timeout":
        return "timeout"
    if verdict == "out_of_memory" or verdict.startswith("crashed"):
        return "out-of-memory"
    return "failed"


def fmt_s(ms):
    return f"{int(ms) / 1000:.1f}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tsv")
    ap.add_argument("--title", default="ergoAIp performance report")
    ap.add_argument("--note", action="append", default=[])
    a = ap.parse_args()

    with open(a.tsv, newline="") as f:
        rows = list(csv.DictReader(f, delimiter="\t"))

    def rel(path):
        key = "ErgoAI-performance/"
        return path.split(key, 1)[1] if key in path else os.path.basename(path)

    for r in rows:
        r["class"] = result_class(r["verdict"])
        r["rel"] = rel(r["file"])

    out = [f"# {a.title}", ""]
    for n in a.note:
        out += [n, ""]

    counts = {}
    for r in rows:
        counts[r["class"]] = counts.get(r["class"], 0) + 1
    out += ["## Summary", "", "| Result | Files |", "|---|---|"]
    for k in ("pass", "loaded", "failed", "out-of-memory", "timeout"):
        out.append(f"| {k} | {counts.get(k, 0)} |")
    out.append(f"| **total** | **{len(rows)}** |")
    out.append("")

    def col(name, sel):
        return [int(r[name]) for r in sel if r[name] not in ("", None)]

    groups = {}
    for r in rows:
        groups.setdefault(os.path.dirname(r["rel"]) or ".", []).append(r)
    out += ["| Directory | Files | Pass | Median solve s | Max solve s | "
            "Sum of run times s | Median peak MB | Max peak MB |",
            "|---|---|---|---|---|---|---|---|"]
    for d in sorted(groups):
        g = groups[d]
        solve = col("solve_ms", g)
        run = col("run_ms", g)
        peak = col("peak_rss_mb", g)
        npass = sum(1 for r in g if r["class"] == "pass")
        out.append(
            f"| {d} | {len(g)} | {npass} | "
            f"{fmt_s(statistics.median(solve)) if solve else '-'} | "
            f"{fmt_s(max(solve)) if solve else '-'} | "
            f"{fmt_s(sum(run))} | "
            f"{int(statistics.median(peak)) if peak else '-'} | "
            f"{max(peak) if peak else '-'} |")
    out.append("")

    out += ["## All test files", "",
            "Times are wall clock in seconds; *run* is the whole child "
            "process after engine boot (convert + load + solve + "
            "comparison).  *Peak* is the process's peak resident set "
            "size (VmHWM).", "",
            "| File | Result | Verdict | Load s | Solve s | Run s | "
            "Solve inferences | Peak MB |",
            "|---|---|---|---|---|---|---|---|"]
    for r in sorted(rows, key=lambda r: r["rel"]):
        out.append(
            f"| {r['rel']} | {r['class']} | `{r['verdict']}` | "
            f"{fmt_s(r['load_ms'])} | {fmt_s(r['solve_ms'])} | "
            f"{fmt_s(r['run_ms'])} | {int(r['solve_inferences']):,} | "
            f"{r['peak_rss_mb']} |")
    out.append("")
    print("\n".join(out))


if __name__ == "__main__":
    main()

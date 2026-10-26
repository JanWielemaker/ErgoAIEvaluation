#!/usr/bin/env python3
"""perf_report.py -- turn an ergoaip_perf.pl TSV (--out=File) into a
Markdown report: a summary and one row per test file.

    python3 scripts/perf_report.py RESULTS.tsv [--title T] [--note N] > report.md
    python3 scripts/perf_report.py --compare A.tsv B.tsv [--labels A,B] > cmp.md

Result classes: pass, loaded (no golden output: loaded and its queries
run without error), solved (a goal program's goal succeeded), failed
(golden mismatch, load or run error, failed goal), out-of-memory (a
resource error, or a crash), timeout.

--compare puts two runs of the same programs side by side, typically
--engine=xsb against ergoAIp: verdicts, load and solve time, the solve
time ratio B/A, peak memory, and the time the program reports itself
(the last number of its output line).
"""
import argparse
import csv
import os
import re
import statistics


def result_class(verdict):
    if verdict == "pass":
        return "pass"
    if verdict in ("solved", "loaded"):
        return verdict
    if verdict.startswith("loaded("):
        return "loaded"
    if verdict == "timeout":
        return "timeout"
    if verdict == "out_of_memory" or verdict.startswith("crashed"):
        return "out-of-memory"
    return "failed"


def fmt_s(ms):
    return f"{int(ms) / 1000:.1f}"


def read_rows(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def display_name(key):
    """A goal item's key is `File :: Goal`; show the file relative to
    ErgoAI-performance, or its directory and name."""
    path, sep, goal = key.partition(" :: ")
    mark = "ErgoAI-performance/"
    if mark in path:
        name = path.split(mark, 1)[1]
    else:
        name = os.path.join(os.path.basename(os.path.dirname(path)),
                            os.path.basename(path))
    return f"{name} `{goal}`" if sep else name


def reported_time(output):
    """The last number of a program's output line: the time a TPLP
    benchmark reports itself (time_tc_*(Limit,Cpu,Wall), datum(...,T))."""
    nums = re.findall(r"-?\d+(?:\.\d+)?(?:e-?\d+)?", output or "")
    return float(nums[-1]) if nums else None


def answer_part(output):
    """The output line without its timing numbers, to check that both
    systems computed the same thing (e.g. datum(elemNet,count(N),T))."""
    out = output or ""
    m = re.match(r"(time_\w+\()(\d+),", out)
    if m:
        return m.group(1) + m.group(2) + ")"
    return re.sub(r",-?\d+(?:\.\d+)?(?:e-?\d+)?\)\.?$", ")", out)


def fmt_opt_s(ms):
    return "-" if ms in ("", None) else f"{int(ms) / 1000:.2f}"


def ratio(a, b):
    try:
        a, b = float(a), float(b)
    except (TypeError, ValueError):
        return "-"
    return f"{b / a:.2f}" if a > 0 else "-"


def compare(a):
    la, lb = (a.labels.split(",") + ["A", "B"])[:2]
    ra = {r["file"]: r for r in read_rows(a.compare[0])}
    rb = {r["file"]: r for r in read_rows(a.compare[1])}
    keys = list(ra) + [k for k in rb if k not in ra]
    out = [f"# {a.title}", ""]
    for n in a.note:
        out += [n, ""]
    out += [f"*Solve* is the goal (or `%test`) in wall-clock seconds, "
            f"measured by the driver; *ratio* is {lb}/{la}.  *Reported* is "
            f"the time the program prints itself.  *Peak* is the peak "
            f"resident set size.  *Same* compares the output line without "
            f"its timings.", "",
            f"| Program | {la} | {lb} | {la} load s | {lb} load s | "
            f"{la} solve s | {lb} solve s | Ratio | {la} reported s | "
            f"{lb} reported s | {la} peak MB | {lb} peak MB | Same |",
            "|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    ratios = []
    for k in keys:
        x, y = ra.get(k, {}), rb.get(k, {})
        both_ok = (result_class(x.get("verdict", "-")) in ("solved", "pass", "loaded")
                   and result_class(y.get("verdict", "-")) in ("solved", "pass", "loaded"))
        r = ratio(x.get("solve_ms"), y.get("solve_ms")) if both_ok else "-"
        if r != "-":
            ratios.append(float(r))
        tx, ty = reported_time(x.get("output")), reported_time(y.get("output"))
        same = "-"
        if both_ok and x.get("output") and y.get("output"):
            same = "yes" if answer_part(x["output"]) == answer_part(y["output"]) else "**no**"
        out.append(
            f"| {display_name(k)} | {x.get('verdict', '-')} | "
            f"{y.get('verdict', '-')} | {fmt_opt_s(x.get('load_ms'))} | "
            f"{fmt_opt_s(y.get('load_ms'))} | {fmt_opt_s(x.get('solve_ms'))} | "
            f"{fmt_opt_s(y.get('solve_ms'))} | {r} | "
            f"{'-' if tx is None else f'{tx:.2f}'} | "
            f"{'-' if ty is None else f'{ty:.2f}'} | "
            f"{x.get('peak_rss_mb', '-')} | {y.get('peak_rss_mb', '-')} | {same} |")
    if ratios:
        geo = statistics.geometric_mean([max(r, 1e-6) for r in ratios])
        out += ["", f"Programs both systems completed: {len(ratios)}.  "
                f"Solve time ratio {lb}/{la}: median {statistics.median(ratios):.2f}, "
                f"geometric mean {geo:.2f}, range {min(ratios):.2f}-{max(ratios):.2f}."]
    out.append("")
    print("\n".join(out))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tsv", nargs="?")
    ap.add_argument("--compare", nargs=2, metavar=("A_TSV", "B_TSV"))
    ap.add_argument("--labels", default="XSB,ergoAIp")
    ap.add_argument("--title", default="ergoAIp performance report")
    ap.add_argument("--note", action="append", default=[])
    a = ap.parse_args()

    if a.compare:
        compare(a)
        return
    if not a.tsv:
        ap.error("a TSV file or --compare A B is required")
    rows = read_rows(a.tsv)

    def rel(path):
        key = "ErgoAI-performance/"
        return path.split(key, 1)[1] if key in path else os.path.basename(path)

    for r in rows:
        r["class"] = result_class(r["verdict"])
        r["rel"] = display_name(r["file"]) if " :: " in r["file"] else rel(r["file"])

    out = [f"# {a.title}", ""]
    for n in a.note:
        out += [n, ""]

    counts = {}
    for r in rows:
        counts[r["class"]] = counts.get(r["class"], 0) + 1
    out += ["## Summary", "", "| Result | Files |", "|---|---|"]
    for k in ("pass", "loaded", "solved", "failed", "out-of-memory", "timeout"):
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
            f"{fmt_s(r['run_ms'])} | {int(r['solve_inferences'] or 0):,} | "
            f"{r['peak_rss_mb']} |")
    out.append("")
    print("\n".join(out))


if __name__ == "__main__":
    main()

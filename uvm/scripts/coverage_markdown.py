#!/usr/bin/env python3
"""Generate a compact Markdown coverage report from IMC text output.

The Cadence IMC command-line report format varies by release and options, so
this parser intentionally accepts a broad set of text-table shapes. It extracts
coverage percentages, optional covered/total counts, and obvious uncovered
counts from the raw IMC transcript, then highlights the lowest-coverage rows.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")
PERCENT_RE = re.compile(r"(?P<pct>\d+(?:\.\d+)?)\s*%")
RATIO_RE = re.compile(r"(?P<covered>\d+)\s*/\s*(?P<total>\d+)")
UNCOVERED_RE = re.compile(
    r"(?:uncovered|uncovered\s+bins|missed|holes?|unhit|not\s+covered)"
    r"[^0-9]*(?P<count>\d+)",
    re.IGNORECASE,
)


@dataclass
class CoverageRow:
    label: str
    metric: str
    coverage: float
    covered: int | None
    total: int | None
    uncovered: int | None
    source: str
    line_no: int
    raw: str

    @property
    def gap(self) -> float:
        return max(0.0, 100.0 - self.coverage)


METRIC_WORDS = (
    "all",
    "assertion",
    "bin",
    "branch",
    "block",
    "covergroup",
    "coverpoint",
    "expression",
    "fsm",
    "functional",
    "line",
    "statement",
    "toggle",
    "total",
)


def clean_line(line: str) -> str:
    line = ANSI_RE.sub("", line)
    line = line.replace("\t", " ")
    return line.strip()


def md_escape(text: object) -> str:
    return str(text).replace("|", "\\|")


def split_columns(line: str) -> list[str]:
    if "|" in line:
        return [part.strip() for part in line.split("|") if part.strip()]
    return [part.strip() for part in re.split(r"\s{2,}", line) if part.strip()]


def classify_metric(text: str) -> str:
    low = text.lower()
    for word in METRIC_WORDS:
        if re.search(rf"\b{re.escape(word)}\b", low):
            if word == "bin":
                return "functional bin"
            return word
    return "coverage"


def strip_numeric_fragments(text: str) -> str:
    text = PERCENT_RE.sub("", text)
    text = RATIO_RE.sub("", text)
    text = UNCOVERED_RE.sub("", text)
    text = re.sub(r"\b(?:covered|uncovered|missed|holes?|bins?|total)\b", "", text, flags=re.IGNORECASE)
    text = re.sub(r"\s+", " ", text)
    text = text.strip(" :-,")
    return text


def parse_line(line: str, source: str, line_no: int) -> CoverageRow | None:
    raw = clean_line(line)
    if not raw or raw.startswith(("#", "//")):
        return None
    if "report_metrics" in raw and "%" not in raw:
        return None

    pct_match = PERCENT_RE.search(raw)
    if not pct_match:
        return None

    coverage = float(pct_match.group("pct"))
    if coverage < 0.0 or coverage > 100.0:
        return None

    columns = split_columns(raw)
    pct_col_idx = None
    for idx, col in enumerate(columns):
        if PERCENT_RE.search(col):
            pct_col_idx = idx
            break

    label = ""
    metric = classify_metric(raw)
    if pct_col_idx is not None and len(columns) > 1:
        prefix_cols = columns[:pct_col_idx]
        suffix_cols = columns[pct_col_idx + 1 :]
        if prefix_cols:
            metric = classify_metric(prefix_cols[0])
            if len(prefix_cols) > 1 and prefix_cols[0].lower() in METRIC_WORDS:
                label = " / ".join(prefix_cols[1:])
            else:
                label = " / ".join(prefix_cols)
        if not label and suffix_cols:
            label = " / ".join(suffix_cols)

    if not label:
        label = strip_numeric_fragments(raw[: pct_match.start()])
    if not label:
        label = strip_numeric_fragments(raw)
    if not label:
        label = f"{source}:{line_no}"

    ratio_match = RATIO_RE.search(raw)
    covered = int(ratio_match.group("covered")) if ratio_match else None
    total = int(ratio_match.group("total")) if ratio_match else None
    uncovered = None
    uncov_match = UNCOVERED_RE.search(raw)
    if uncov_match:
        uncovered = int(uncov_match.group("count"))
    elif covered is not None and total is not None and total >= covered:
        uncovered = total - covered

    return CoverageRow(
        label=label,
        metric=metric,
        coverage=coverage,
        covered=covered,
        total=total,
        uncovered=uncovered,
        source=source,
        line_no=line_no,
        raw=raw,
    )


def read_rows(raw_paths: Iterable[Path]) -> list[CoverageRow]:
    rows: list[CoverageRow] = []
    seen: set[tuple[str, str, float, int | None, int | None]] = set()
    for path in raw_paths:
        if not path.exists():
            continue
        for line_no, line in enumerate(path.read_text(errors="replace").splitlines(), start=1):
            row = parse_line(line, str(path), line_no)
            if row is None:
                continue
            key = (row.metric, row.label, row.coverage, row.covered, row.total)
            if key in seen:
                continue
            seen.add(key)
            rows.append(row)
    return rows


def read_tests(runfile: Path) -> list[str]:
    if not runfile.exists():
        return []
    tests: list[str] = []
    for line in runfile.read_text(errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        tests.append(Path(line).name)
    return tests


def row_counts(row: CoverageRow) -> str:
    if row.covered is not None and row.total is not None:
        return f"{row.covered}/{row.total}"
    return "-"


def row_uncovered(row: CoverageRow) -> str:
    if row.uncovered is not None:
        return str(row.uncovered)
    return "-"


def table(rows: list[list[object]]) -> list[str]:
    if not rows:
        return []
    widths = [0] * len(rows[0])
    for row in rows:
        for idx, col in enumerate(row):
            widths[idx] = max(widths[idx], len(str(col)))
    out = []
    header = "| " + " | ".join(md_escape(col).ljust(widths[idx]) for idx, col in enumerate(rows[0])) + " |"
    sep = "| " + " | ".join("-" * widths[idx] for idx in range(len(widths))) + " |"
    out.extend([header, sep])
    for row in rows[1:]:
        out.append("| " + " | ".join(md_escape(col).ljust(widths[idx]) for idx, col in enumerate(row)) + " |")
    return out


def choose_summary_rows(rows: list[CoverageRow]) -> list[CoverageRow]:
    summary_terms = ("overall", "total", "summary", "all ")
    summary = [
        row
        for row in rows
        if any(term in row.label.lower() or term in row.metric.lower() for term in summary_terms)
    ]
    if summary:
        return summary[:12]
    return rows[:12]


def choose_gap_rows(rows: list[CoverageRow], limit: int) -> list[CoverageRow]:
    gaps = [row for row in rows if row.coverage < 100.0]
    return sorted(
        gaps,
        key=lambda row: (
            row.gap,
            row.uncovered if row.uncovered is not None else -1,
            row.total if row.total is not None else -1,
        ),
        reverse=True,
    )[:limit]


def choose_bin_rows(rows: list[CoverageRow], limit: int) -> list[CoverageRow]:
    candidates = [
        row
        for row in rows
        if row.coverage < 100.0
        and (
            "bin" in row.metric.lower()
            or "bin" in row.label.lower()
            or "coverpoint" in row.label.lower()
            or "covergroup" in row.label.lower()
        )
    ]
    return sorted(
        candidates,
        key=lambda row: (
            row.coverage,
            -(row.uncovered if row.uncovered is not None else 0),
            row.label,
        ),
    )[:limit]


def write_report(args: argparse.Namespace, rows: list[CoverageRow], tests: list[str]) -> None:
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)

    now = _dt.datetime.now().astimezone().isoformat(timespec="seconds")
    work = Path(args.work).resolve()
    raw_paths = [Path(path).resolve() for path in args.raw]
    merged_db = Path(args.merged_db).resolve() if args.merged_db else work / "scope" / "merged_all"

    lines: list[str] = []
    suite = args.suite.upper()
    lines.append(f"# {suite} Coverage Report")
    lines.append("")
    lines.append(f"- Generated: `{now}`")
    lines.append(f"- Coverage work dir: `{work}`")
    lines.append(f"- Merged database: `{merged_db}`")
    lines.append(f"- Raw IMC text: {', '.join(f'`{p}`' for p in raw_paths)}")
    lines.append("")

    lines.append("## Tests Included")
    lines.append("")
    if tests:
        for test in tests:
            lines.append(f"- `{test}`")
    else:
        lines.append("- No `runfile.txt` entries found.")
    lines.append("")

    lines.append("## Coverage Summary")
    lines.append("")
    if rows:
        summary_table = [["Metric", "Scope / Item", "Coverage", "Covered/Total", "Uncovered"]]
        for row in choose_summary_rows(rows):
            summary_table.append([
                row.metric,
                row.label,
                f"{row.coverage:.1f}%",
                row_counts(row),
                row_uncovered(row),
            ])
        lines.extend(table(summary_table))
    else:
        lines.append("No coverage percentage rows were parsed from the raw IMC text.")
    lines.append("")

    lines.append("## Largest Coverage Gaps")
    lines.append("")
    gap_rows = choose_gap_rows(rows, args.gap_limit)
    if gap_rows:
        gap_table = [["Gap", "Coverage", "Uncovered", "Metric", "Scope / Item"]]
        for row in gap_rows:
            gap_table.append([
                f"{row.gap:.1f}%",
                f"{row.coverage:.1f}%",
                row_uncovered(row),
                row.metric,
                row.label,
            ])
        lines.extend(table(gap_table))
    else:
        lines.append("No coverage gaps were parsed, or all parsed rows were at 100%.")
    lines.append("")

    lines.append("## Uncovered Functional Bins")
    lines.append("")
    bin_rows = choose_bin_rows(rows, args.bin_limit)
    if bin_rows:
        bin_table = [["Coverage", "Uncovered", "Covergroup / Coverpoint / Bin"]]
        for row in bin_rows:
            bin_table.append([f"{row.coverage:.1f}%", row_uncovered(row), row.label])
        lines.extend(table(bin_table))
    else:
        lines.append("No uncovered functional-bin rows were identified in the raw IMC text.")
    lines.append("")

    lines.append("## Exclusions / Known Gaps")
    lines.append("")
    if args.exclusion:
        for exclusion in args.exclusion:
            lines.append(f"- {exclusion}")
    if args.suite.lower() == "mbinit":
        lines.append(
            "- `mbinit_state_sync_sva` / XC-03 is excluded from assertion coverage "
            "because the current one-cycle requester/responder state-sync property "
            "is too strict for MBINIT RTL substate timing."
        )
        lines.append(
            "- RM-05/RM-08 and several TRAINERROR closures remain known MBINIT-only "
            "coverage limitations; use the verification plan for requirement-level status."
        )
    if not args.exclusion and args.suite.lower() != "mbinit":
        lines.append("- No suite-specific exclusions were provided.")
    lines.append("")

    lines.append("## Parser Notes")
    lines.append("")
    lines.append(
        "- This Markdown was generated from IMC text output captured in batch mode."
    )
    lines.append(
        "- If a table is empty, inspect the raw IMC text artifact above and adjust "
        "`uvm/scripts/coverage_markdown.py` for the local IMC transcript format."
    )
    lines.append("")

    out.write_text("\n".join(lines))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", required=True, help="Coverage suite name, e.g. mbinit")
    parser.add_argument("--work", required=True, help="Coverage work directory")
    parser.add_argument("--raw", action="append", required=True, help="Raw IMC text report path")
    parser.add_argument("--output", required=True, help="Markdown output path")
    parser.add_argument("--merged-db", default="", help="Merged IMC database path")
    parser.add_argument("--runfile", default="", help="Runfile path")
    parser.add_argument("--exclusion", action="append", default=[], help="Exclusion note to include")
    parser.add_argument("--gap-limit", type=int, default=20)
    parser.add_argument("--bin-limit", type=int, default=40)
    args = parser.parse_args()

    raw_paths = [Path(path) for path in args.raw]
    rows = read_rows(raw_paths)
    runfile = Path(args.runfile) if args.runfile else Path(args.work) / "runfile.txt"
    tests = read_tests(runfile)
    write_report(args, rows, tests)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

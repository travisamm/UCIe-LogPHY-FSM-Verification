#!/usr/bin/env bash
# Open IMC GUI for MBINIT coverage.
# Usage:
#   ./open_imc.sh              — load merged database (union of all runs)
#   ./open_imc.sh sanity       — load only the sanity run
#   ./open_imc.sh report       — open the HTML report in a browser

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export MDV_XLM_HOME=/share/instsww/cadence/XCELIUM2509
IMC=/share/instsww/cadence/VMANAGER2509/tools/bin/imc

SCOPE="$SCRIPT_DIR/cov_work/mbinit/scope"
MERGED="$SCOPE/merged_all"
RUNFILE="$SCRIPT_DIR/cov_work/mbinit/runfile.txt"
REPORT="$SCRIPT_DIR/cov_work/mbinit/report/index.html"

case "${1:-}" in
  sanity)
    DB="$SCOPE/test_mbinit_sanity"
    if [ ! -d "$DB" ]; then
      echo "No sanity run found. Run 'make cov_mbinit' first."
      exit 1
    fi
    echo "Opening IMC GUI with sanity run only."
    "$IMC" -load "$DB" &
    ;;
  report)
    if [ ! -f "$REPORT" ]; then
      echo "No report found. Run 'make cov_mbinit' first."
      exit 1
    fi
    echo "Opening HTML report: $REPORT"
    xdg-open "$REPORT" 2>/dev/null || firefox "$REPORT" 2>/dev/null || echo "Open manually: $REPORT"
    ;;
  *)
    # Build merged database if it doesn't exist yet
    if [ ! -d "$MERGED" ]; then
      echo "Merged database not found — building it now..."
      if [ ! -d "$SCOPE" ]; then
        echo "No coverage data found. Run 'make cov_mbinit' first."
        exit 1
      fi
      ls "$SCOPE" | grep "^test_" | while read d; do echo "$SCOPE/$d"; done > "$RUNFILE"
      first=$(head -1 "$RUNFILE")
      "$IMC" -load "$first" \
        -execcmd "merge -runfile $RUNFILE -out $MERGED -overwrite; exit"
    fi
    echo "Opening IMC GUI with merged database (all runs union)."
    "$IMC" -load "$MERGED" \
      -initcmd "exclude -type mbinit_state_sync_sva -metrics assertion -comment {Intentionally unbound: XC-03 property too tight for RTL substate timing}" &
    ;;
esac

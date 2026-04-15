#!/usr/bin/env bash
# generate_logphy_sv.sh
#
# Elaborates LogPHY Chisel modules to SystemVerilog using the minimal sbt
# project in elab/.  That project pulls only Chisel 7.8 from Maven Central —
# no Berkeley-internal JARs required.
#
# Output lands in:
#   elab/generatedVerilog/logphy/   (relative to where sbt runs)
#
# Usage:
#   ./generate_logphy_sv.sh           # elaborate all modules
#   ./generate_logphy_sv.sh tops      # FSM tops only (fastest)
#   ./generate_logphy_sv.sh <Module>  # single module, e.g. MainMBInitSM

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ELAB_DIR="$SCRIPT_DIR/elab"
PKG="edu.berkeley.cs.uciedigital.logphy"
OUT="$ELAB_DIR/generatedVerilog/logphy"

# Mill requires Java 17+; set it if the system default is older.
JAVA17="/usr/lib/jvm/java-17"
if [[ -d "$JAVA17" ]]; then
  export JAVA_HOME="$JAVA17"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

# ── Module lists ─────────────────────────────────────────────────────────────

# Top-level FSMs — each instantiates its own Requester + Responder.
# Primary DUT targets for UVM verification.
TOPS=(
  MainSBInit
  MainMBInitSM
  MainMBTrainSM
  MainPhyRetrainSidebandHandshake
  MainLinkInitSidebandHandshake
  MainTrainErrorRequester
  MainTrainErrorResponder
  MainRDIStateMachine
)

# D2C link-operation modules — no top-level wrapper, req/resp are separate DUTs.
D2C=(
  MainTxD2CPointTestRequester
  MainTxD2CPointTestResponder
  MainTxD2CEyeWidthSweepRequester
  MainTxD2CEyeWidthSweepResponder
  MainRxD2CPointTestRequester
  MainRxD2CPointTestResponder
  MainRxD2CEyeWidthSweepRequester
  MainRxD2CEyeWidthSweepResponder
)

# Utility / datapath modules.
UTILS=(
  MainPatternWriter
  MainPatternReader
  MainUCIeLFSR
  MainSidebandMessageExchanger
  MainRDIStallRequester
  MainRDIWakeHandshakeResponder
  MainRDIClockHandshakeRequester
)

# ── Argument handling ─────────────────────────────────────────────────────────

case "${1:-all}" in
  tops)
    TARGETS=("${TOPS[@]}")
    ;;
  all)
    TARGETS=("${TOPS[@]}" "${D2C[@]}" "${UTILS[@]}")
    ;;
  *)
    TARGETS=("$1")
    ;;
esac

# ── Preflight ────────────────────────────────────────────────────────────────

if ! command -v sbt &>/dev/null; then
  echo "ERROR: sbt not found on PATH"
  exit 1
fi

mkdir -p "$OUT"

# ── Build one sbt session that runs all targets ───────────────────────────────
#
# All runMain calls are chained with ";" so sbt starts once and compiles once.

echo ""
echo "Elab dir  : $ELAB_DIR"
echo "Output    : $OUT"
echo "Targets   : ${#TARGETS[@]} module(s)"
echo "────────────────────────────────────────────────────"
echo ""

cd "$ELAB_DIR"

# Compile once so all subsequent runMain calls skip recompilation.
echo "Compiling..."
sbt compile 2>&1 | grep -E "^\[info\] (compiling|done compiling|warning|error)" || true
echo ""

# ── Per-module elaboration ────────────────────────────────────────────────────

PASS=0
FAIL=0
FAILED_MODULES=()

for MODULE in "${TARGETS[@]}"; do
  printf "  %-40s" "$MODULE"
  LOG=$(mktemp)

  if sbt "runMain ${PKG}.${MODULE}" >"$LOG" 2>&1; then
    echo "OK"
    PASS=$((PASS + 1))
  else
    echo "FAILED"
    FAIL=$((FAIL + 1))
    FAILED_MODULES+=("$MODULE")
    # Show the firtool error (uninitialized sinks, etc.)
    grep "\[error\].*not fully initialized\|\[error\].*error:" "$LOG" 2>/dev/null \
      | grep -v "stack trace\|FirtoolNon\|ExitCode\|runMain\|Total time" \
      | head -3 | sed 's/^/    | /'
  fi

  rm -f "$LOG"
done

echo "────────────────────────────────────────────────────"
echo "  Passed: $PASS   Failed: $FAIL"
echo ""

if [[ $PASS -gt 0 ]]; then
  echo "Generated files:"
  find "$OUT" -name "*.sv" -printf "  %f\n" 2>/dev/null | sort
  echo ""
fi

rm -f "$LOG"

if [[ $FAIL -gt 0 ]]; then
  echo "Failed modules:"
  for m in "${FAILED_MODULES[@]}"; do echo "  - $m"; done
  echo ""
  exit 1
fi

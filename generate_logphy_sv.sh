#!/usr/bin/env bash
# generate_logphy_sv.sh
#
# Elaborates LogPHY Chisel modules to SystemVerilog by running the Main*
# App objects that already exist in each source file.
#
# Uses the Chipyard sbt build (which has all Berkeley deps pre-wired) rather
# than the standalone Mill build, which requires those deps to be published
# locally first.
#
# Output lands in:
#   <CHIPYARD_DIR>/generatedVerilog/logphy/
#
# Usage:
#   ./generate_logphy_sv.sh           # elaborate all modules
#   ./generate_logphy_sv.sh tops      # FSM tops only (fastest)
#   ./generate_logphy_sv.sh <Module>  # single module, e.g. MainMBInitSM

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Chipyard root — sbt runs from here so relative paths in Main* objects
# (./generatedVerilog/logphy) resolve under CHIPYARD_DIR.
CHIPYARD_DIR="/scratch/cs199-akc/chipyard-Cybiii"
PKG="edu.berkeley.cs.uciedigital.logphy"
OUT="$CHIPYARD_DIR/generatedVerilog/logphy"

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

# D2C link-operation modules — no top-level wrapper, elaborate req/resp separately.
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

if [[ ! -d "$CHIPYARD_DIR" ]]; then
  echo "ERROR: Chipyard not found at $CHIPYARD_DIR"
  exit 1
fi

if ! command -v sbt &>/dev/null; then
  echo "ERROR: sbt not found on PATH"
  exit 1
fi

mkdir -p "$OUT"

# ── Build one sbt command string that runs all targets in a single session ───
#
# Running each module as a separate sbt invocation would pay the JVM warm-up
# cost (~30s) 23 times.  Chaining with ";" runs them all in one session.
#
# Format: ;project ucie;runMain PKG.M1;runMain PKG.M2;...

SBT_CMDS=";project ucie"
for MODULE in "${TARGETS[@]}"; do
  SBT_CMDS="${SBT_CMDS};runMain ${PKG}.${MODULE}"
done

# ── Run ──────────────────────────────────────────────────────────────────────

echo ""
echo "Chipyard dir : $CHIPYARD_DIR"
echo "Output dir   : $OUT"
echo "Targets      : ${#TARGETS[@]} module(s)"
echo "────────────────────────────────────────────────────"
echo ""

cd "$CHIPYARD_DIR"

# Run the whole batch.  sbt prints each runMain result; tee to a log for
# post-processing.
LOG=$(mktemp)
if sbt "$SBT_CMDS" 2>&1 | tee "$LOG"; then
  SBT_EXIT=0
else
  SBT_EXIT=$?
fi

# ── Report ───────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────────────────────────"

PASS=0
FAIL=0
FAILED_MODULES=()

for MODULE in "${TARGETS[@]}"; do
  # A successful runMain prints "[success]" or the module name with no error.
  # A failed one prints a stack trace mentioning the class name.
  if grep -q "running.*${MODULE}\|${MODULE}.*success" "$LOG" 2>/dev/null || \
     ( [[ $SBT_EXIT -eq 0 ]] && ! grep -q "${MODULE}.*error\|error.*${MODULE}" "$LOG" 2>/dev/null ); then
    printf "  %-40s OK\n" "$MODULE"
    PASS=$((PASS + 1))
  else
    printf "  %-40s FAILED\n" "$MODULE"
    FAIL=$((FAIL + 1))
    FAILED_MODULES+=("$MODULE")
  fi
done

echo "────────────────────────────────────────────────────"
echo "  Passed: $PASS   Failed: $FAIL"
echo ""

if [[ -d "$OUT" ]] && compgen -G "$OUT/*.sv" > /dev/null 2>&1; then
  echo "Generated files in $OUT:"
  find "$OUT" -name "*.sv" -printf "  %f\n" | sort
  echo ""
fi

rm -f "$LOG"

if [[ $FAIL -gt 0 ]]; then
  echo "Failed modules:"
  for m in "${FAILED_MODULES[@]}"; do
    echo "  - $m"
  done
  echo ""
  exit 1
fi

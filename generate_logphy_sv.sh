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
#   ./generate_logphy_sv.sh sbinit    # SBINIT top + requester/responder
#   ./generate_logphy_sv.sh <Module>  # single module, e.g. MainMBInitSM

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ELAB_DIR="$SCRIPT_DIR/elab"
PKG="edu.berkeley.cs.uciedigital.logphy"
OUT="$ELAB_DIR/generatedVerilog/logphy"
RUNNER_DIR="$ELAB_DIR/src/main/scala/edu/berkeley/cs/uciedigital/logphy"
RUNNER="$RUNNER_DIR/GeneratedLogphyElab.scala"
RUNNER_MAIN="${PKG}.GeneratedLogphyElab"

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
  MainLinkTrainingSM
  MainPhyRetrainSidebandHandshake
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
  MainRDIStallRequester
  MainRDIWakeHandshakeResponder
  MainRDIClockHandshakeRequester
)

# ── Argument handling ─────────────────────────────────────────────────────────

case "${1:-all}" in
  sbinit)
    TARGETS=(MainSBInit MainSBInitRequester MainSBInitResponder)
    ;;
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
mkdir -p "$RUNNER_DIR"

common_firtool_opts() {
  cat <<'EOF'
      "-O=debug",
      "-g",
      "--disable-all-randomization",
      "--strip-debug-info",
      "--lowering-options=disallowLocalVariables",
EOF
}

module_ctor() {
  case "$1" in
    MainSBInit) echo "new SBInitSM(new SidebandParams(), 8000000)" ;;
    MainSBInitRequester) echo "new SBInitRequester(new SidebandParams(), 8000000)" ;;
    MainSBInitResponder) echo "new SBInitResponder(new SidebandParams())" ;;
    MainMBInitSM) echo "new MBInitSM(new AfeParams(), new SidebandParams())" ;;
    MainMBInitRequester) echo "new MBInitRequester(new AfeParams(), new SidebandParams())" ;;
    MainMBInitResponder) echo "new MBInitResponder(new AfeParams(), new SidebandParams())" ;;
    MainMBTrainSM) echo "new MBTrainSM(new AfeParams(), new SidebandParams())" ;;
    MainMBTrainRequester) echo "new MBTrainRequester(new AfeParams(), new SidebandParams())" ;;
    MainMBTrainResponder) echo "new MBTrainResponder(new AfeParams(), new SidebandParams())" ;;
    MainLinkTrainingSM) echo "new LinkTrainingSM(new SidebandParams(), new AfeParams(), retryW = 10)" ;;
    MainPhyRetrainSidebandHandshake) echo "new PhyRetrainSidebandHandshake(new SidebandParams())" ;;
    MainPhyRetrainRequester) echo "new PhyRetrainRequester(new SidebandParams())" ;;
    MainPhyRetrainResponder) echo "new PhyRetrainResponder(new SidebandParams())" ;;
    MainTrainErrorRequester) echo "new TrainErrorRequester(new SidebandParams())" ;;
    MainTrainErrorResponder) echo "new TrainErrorResponder(new SidebandParams())" ;;
    MainRDIStateMachine) echo "new RDIStateMachine(new SidebandParams())" ;;
    MainRDIStateMachineRequester) echo "new RDIStateMachineRequester(new SidebandParams())" ;;
    MainRDIStateMachineResponder) echo "new RDIStateMachineResponder(new SidebandParams())" ;;
    MainRDIController) echo "new RDIController(new SidebandParams())" ;;
    MainRDIStallRequester) echo "new RDIStallRequester()" ;;
    MainRDIWakeHandshakeResponder) echo "new RDIWakeHandshakeResponder()" ;;
    MainRDIClockHandshakeRequester) echo "new RDIClockHandshakeRequester()" ;;
    MainTxD2CPointTestRequester) echo "new TxD2CPointTestRequester(new AfeParams(), new SidebandParams())" ;;
    MainTxD2CPointTestResponder) echo "new TxD2CPointTestResponder(new AfeParams(), new SidebandParams())" ;;
    MainTxD2CEyeWidthSweepRequester) echo "new TxD2CEyeWidthSweepRequester(new AfeParams(), new SidebandParams())" ;;
    MainTxD2CEyeWidthSweepResponder) echo "new TxD2CEyeWidthSweepResponder(new AfeParams(), new SidebandParams())" ;;
    MainRxD2CPointTestRequester) echo "new RxD2CPointTestRequester(new AfeParams(), new SidebandParams())" ;;
    MainRxD2CPointTestResponder) echo "new RxD2CPointTestResponder(new AfeParams(), new SidebandParams())" ;;
    MainRxD2CEyeWidthSweepRequester) echo "new RxD2CEyeWidthSweepRequester(new AfeParams(), new SidebandParams())" ;;
    MainRxD2CEyeWidthSweepResponder) echo "new RxD2CEyeWidthSweepResponder(new AfeParams(), new SidebandParams())" ;;
    MainPatternWriter) echo "new PatternWriter(new AfeParams())" ;;
    MainPatternReader) echo "new PatternReader(new AfeParams())" ;;
    MainUCIeLFSR) echo "new UcieLFSR(new AfeParams())" ;;
    MainSidebandMessageExchanger) echo "new SidebandMessageExchanger(new SidebandParams())" ;;
    *)
      echo "ERROR: unknown elab target '$1'" >&2
      return 1
      ;;
  esac
}

module_sources() {
  case "$1" in
    MainSBInit|MainSBInitRequester|MainSBInitResponder)
      echo "logphy/modules/linktraining/SBInit.scala"
      ;;
    MainPhyRetrainSidebandHandshake|MainPhyRetrainRequester|MainPhyRetrainResponder)
      echo "logphy/modules/linktraining/PhyRetrainSidebandHandshake.scala:logphy/modules/SidebandMessageExchanger.scala"
      ;;
    MainTrainErrorRequester|MainTrainErrorResponder)
      echo "logphy/modules/linktraining/TrainError.scala:logphy/modules/SidebandMessageExchanger.scala"
      ;;
    MainRDIStateMachine|MainRDIStateMachineRequester|MainRDIStateMachineResponder|MainRDIController)
      echo "logphy/modules/rdi/RDIStateMachine.scala:logphy/modules/rdi/RDIController.scala:logphy/modules/rdi/RDIWakeHandshakeResponder.scala:logphy/modules/rdi/RDIClockHandshakeRequester.scala:logphy/modules/rdi/RDIStallRequester.scala:logphy/modules/SidebandMessageExchanger.scala"
      ;;
    MainRDIStallRequester)
      echo "logphy/modules/rdi/RDIStallRequester.scala"
      ;;
    MainRDIWakeHandshakeResponder)
      echo "logphy/modules/rdi/RDIWakeHandshakeResponder.scala"
      ;;
    MainRDIClockHandshakeRequester)
      echo "logphy/modules/rdi/RDIClockHandshakeRequester.scala"
      ;;
    MainSidebandMessageExchanger)
      echo "logphy/modules/SidebandMessageExchanger.scala"
      ;;
    MainUCIeLFSR)
      echo "logphy/modules/UcieLFSR.scala"
      ;;
    MainPatternReader)
      echo "logphy/modules/PatternReader.scala"
      ;;
    MainPatternWriter)
      echo "logphy/modules/PatternWriter.scala"
      ;;
    MainMBInitSM|MainMBInitRequester|MainMBInitResponder)
      echo "logphy/modules/linktraining/MBInitSM.scala:logphy/modules/linktraining/TxD2CPointTest.scala:logphy/modules/linktraining/TxD2CEyeWidthSweep.scala:logphy/modules/linktraining/RxD2CPointTest.scala:logphy/modules/linktraining/RxD2CEyeWidthSweep.scala:logphy/modules/PatternWriter.scala:logphy/modules/PatternReader.scala:logphy/modules/UcieLFSR.scala:logphy/modules/SidebandMessageExchanger.scala:logphy/modules/PhyLaneTrainer.scala"
      ;;
    MainMBTrainSM|MainMBTrainRequester|MainMBTrainResponder)
      echo "logphy/modules/linktraining/MBTrainSM.scala:logphy/modules/linktraining/TxD2CPointTest.scala:logphy/modules/linktraining/TxD2CEyeWidthSweep.scala:logphy/modules/linktraining/RxD2CPointTest.scala:logphy/modules/linktraining/RxD2CEyeWidthSweep.scala:logphy/modules/PatternWriter.scala:logphy/modules/PatternReader.scala:logphy/modules/UcieLFSR.scala:logphy/modules/SidebandMessageExchanger.scala:logphy/modules/PhyLaneTrainer.scala"
      ;;
    MainLinkTrainingSM)
      echo "logphy/modules/linktraining/:logphy/modules/PhyLaneTrainer.scala:logphy/modules/PatternWriter.scala:logphy/modules/PatternReader.scala:logphy/modules/UcieLFSR.scala:logphy/modules/SidebandMessageExchanger.scala"
      ;;
    MainTxD2CPointTestRequester|MainTxD2CPointTestResponder)
      echo "logphy/modules/linktraining/TxD2CPointTest.scala:logphy/modules/PatternWriter.scala:logphy/modules/PatternReader.scala:logphy/modules/SidebandMessageExchanger.scala"
      ;;
    MainTxD2CEyeWidthSweepRequester|MainTxD2CEyeWidthSweepResponder)
      echo "logphy/modules/linktraining/TxD2CEyeWidthSweep.scala:logphy/modules/PatternWriter.scala:logphy/modules/PatternReader.scala:logphy/modules/SidebandMessageExchanger.scala"
      ;;
    MainRxD2CPointTestRequester|MainRxD2CPointTestResponder)
      echo "logphy/modules/linktraining/RxD2CPointTest.scala:logphy/modules/PatternWriter.scala:logphy/modules/PatternReader.scala:logphy/modules/SidebandMessageExchanger.scala"
      ;;
    MainRxD2CEyeWidthSweepRequester|MainRxD2CEyeWidthSweepResponder)
      echo "logphy/modules/linktraining/RxD2CEyeWidthSweep.scala:logphy/modules/PatternWriter.scala:logphy/modules/PatternReader.scala:logphy/modules/SidebandMessageExchanger.scala"
      ;;
    *)
      echo "ERROR: no source closure for '$1'" >&2
      return 1
      ;;
  esac
}

# CIRCT firtool (see header in emitted SidebandMessageExchanger.sv) sometimes lowers
# io.msgReceived = Output(Bool()) to an internal net only — no module port — while
# MBInitRequester/MBInitResponder still connect .io_msgReceived. Reconcile here so we
# do not hand-edit generated SV after every run.
patch_sideband_message_exchanger_sv() {
  local f="$OUT/SidebandMessageExchanger.sv"
  [[ -f "$f" ]] || return 0
  python3 - "$f" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as fp:
    text = fp.read()

# Port list already exports io_msgReceived (fixed firtool or re-run).
port_block = re.search(
    r"(module\s+SidebandMessageExchanger\s*\()(.*?)(\)\s*;)",
    text,
    flags=re.S,
)
if not port_block:
    sys.exit(0)
ports = port_block.group(2)
# Already exported (fixed firtool or second script run).
if re.search(r"\bio_msgReceived\b", ports):
    pass
elif re.search(
    r"(?m)^(\s*output\s+io_msgSent,)\s*\n(\s*)input\s+io_sbLaneIo_tx_ready",
    text,
):
    text = re.sub(
        r"(?m)^(\s*output\s+io_msgSent,)\s*\n(\s*)input\s+io_sbLaneIo_tx_ready",
        r"\1\n  output         io_msgReceived,\n\2input          io_sbLaneIo_tx_ready",
        text,
        count=1,
    )
else:
    print(
        "patch_sideband_message_exchanger_sv: could not find io_msgSent / tx_ready stub",
        file=sys.stderr,
    )

# With an output port, an inner `wire io_msgReceived;` duplicates the net name.
text = re.sub(r"(?m)^\s*wire\s+io_msgReceived;\s*\n", "", text)

with open(path, "w", encoding="utf-8") as fp:
    fp.write(text)
PY
}

write_runner() {
  local module="$1"
  local ctor="$2"

  cat >"$RUNNER" <<EOF
package edu.berkeley.cs.uciedigital.logphy

import circt.stage.ChiselStage
import edu.berkeley.cs.uciedigital.sideband._

object GeneratedLogphyElab extends App {
  ChiselStage.emitSystemVerilogFile(
    ${ctor},
    args = Array("-td", "./generatedVerilog/logphy/"),
    firtoolOpts = Array(
$(common_firtool_opts)
    ),
  )
}
EOF
}

echo ""
echo "Elab dir  : $ELAB_DIR"
echo "Output    : $OUT"
echo "Targets   : ${#TARGETS[@]} module(s)"
echo "────────────────────────────────────────────────────"
echo ""

cd "$ELAB_DIR"

# ── Per-module elaboration ────────────────────────────────────────────────────

PASS=0
FAIL=0
FAILED_MODULES=()

for MODULE in "${TARGETS[@]}"; do
  printf "  %-40s" "$MODULE"
  LOG=$(mktemp)
  CTOR=$(module_ctor "$MODULE")
  SOURCES=$(module_sources "$MODULE")
  write_runner "$MODULE" "$CTOR"

  if UCIE_ELAB_SOURCES="$SOURCES" sbt "runMain ${RUNNER_MAIN}" >"$LOG" 2>&1; then
    echo "OK"
    PASS=$((PASS + 1))
  else
    echo "FAILED"
    FAIL=$((FAIL + 1))
    FAILED_MODULES+=("$MODULE")
    grep "\[error\]" "$LOG" 2>/dev/null \
      | grep -v "stack trace\|FirtoolNon\|ExitCode\|runMain\|Total time" \
      | head -8 | sed 's/^/    | /'
  fi

  rm -f "$LOG"
done

patch_sideband_message_exchanger_sv

echo "────────────────────────────────────────────────────"
echo "  Passed: $PASS   Failed: $FAIL"
echo ""

if [[ $PASS -gt 0 ]]; then
  echo "Generated files:"
  find "$OUT" -name "*.sv" -type f -exec basename {} \; 2>/dev/null | sort | sed 's/^/  /'
  echo ""
fi

rm -f "$LOG"

if [[ $FAIL -gt 0 ]]; then
  echo "Failed modules:"
  for m in "${FAILED_MODULES[@]}"; do echo "  - $m"; done
  echo ""
  exit 1
fi

`ifndef SB_CTRL_IF_SV
`define SB_CTRL_IF_SV

// ---------------------------------------------------------------------------
// sb_ctrl_if
// ---------------------------------------------------------------------------
// SBInitSM top-level FSM control bus. Split out from the per-lane interfaces
// so the requester/responder lane VIPs stay purely about their sideband
// lanes. The SBINIT requester agent drives fsmCtrl_start and observes the
// rest; nothing drives the lanes from here.
//
// TODO(tier1-clocking): add a clocking block with input/output skews so the
// req agent samples/drives these synchronously without races.
// ---------------------------------------------------------------------------
interface sb_ctrl_if(input logic clock, input logic reset);
  logic fsmCtrl_start;                 // TB drives  (kick the SBINIT FSM)
  logic fsmCtrl_done;                  // DUT drives (SBINIT complete)
  logic fsmCtrl_error;                 // tied 0 in tb (RTL hardcodes error=0)
  logic fsmCtrl_substateTransitioning; // DUT-level; currently unconnected
  logic sbRxTxMode;                    // DUT drives (0=RAW pattern, 1=PACKET)
endinterface

`endif

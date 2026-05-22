`ifndef SB_CTRL_IF_SV
`define SB_CTRL_IF_SV

// ---------------------------------------------------------------------------
// sb_ctrl_if
// ---------------------------------------------------------------------------
// SBInitSM top-level FSM control bus. Split out from the per-lane interfaces
// so the requester/responder lane VIPs stay purely about their sideband
// lanes. The SBINIT requester rx driver drives fsmCtrl_start; the passive
// control monitor observes mode/done/error.
//
// Timing hygiene: TB access goes through clocking blocks (drv_cb/mon_cb) so the
// driver/monitor sample and drive synchronously without races. The DUT still
// binds to the raw nets in the testbench top.
// ---------------------------------------------------------------------------
interface sb_ctrl_if(input logic clock, input logic reset);
  logic fsmCtrl_start;                 // TB drives  (kick the SBINIT FSM)
  logic fsmCtrl_done;                  // DUT drives (SBINIT complete)
  logic fsmCtrl_error;                 // tied 0 in tb (RTL hardcodes error=0)
  logic fsmCtrl_substateTransitioning; // DUT-level; currently unconnected
  logic sbRxTxMode;                    // DUT drives (0=RAW pattern, 1=PACKET)

  // Driver view: TB drives fsmCtrl_start, samples the rest.
  clocking drv_cb @(posedge clock);
    default input #1step output #1;
    output fsmCtrl_start;
    input  fsmCtrl_done;
    input  fsmCtrl_error;
    input  fsmCtrl_substateTransitioning;
    input  sbRxTxMode;
  endclocking

  // Monitor view: sample everything.
  clocking mon_cb @(posedge clock);
    default input #1step;
    input fsmCtrl_start;
    input fsmCtrl_done;
    input fsmCtrl_error;
    input fsmCtrl_substateTransitioning;
    input sbRxTxMode;
  endclocking

  modport drv (clocking drv_cb, input clock, input reset);
  modport mon (clocking mon_cb, input clock, input reset);
endinterface

`endif

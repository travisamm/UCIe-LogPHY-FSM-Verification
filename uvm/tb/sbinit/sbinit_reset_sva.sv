`ifndef SBINIT_RESET_SVA_SV
`define SBINIT_RESET_SVA_SV

// ===========================================================================
// sbinit_reset_sva
// ---------------------------------------------------------------------------
// Reset-handling assertions, bound onto the SBINIT interfaces. They confirm
// that while the DUT is held in reset:
//   * the DUT does not actively transmit (tx_valid / fsmCtrl_done / sbRxTxMode
//     are not asserted), and
//   * the testbench drives its inputs idle (rx_valid / fsmCtrl_start are not
//     asserted) - i.e. the reset-aware drivers actually idle.
//
// Each rule is qualified by `(reset && $past(reset))` so it only fires once
// reset has been stable for >=2 cycles. That tolerates the one cycle of
// register/driver reaction latency at the reset edge (a synchronous output
// register clears the cycle AFTER reset is sampled; the reset-aware drivers
// idle their clocking outputs one cycle after they see the reset edge), while
// still catching a signal that stays active throughout a held reset.
//
// `!== 1'b1` (rather than `== 1'b0`) lets X during early power-on reset pass.
// Always on (no enable gate): these are fundamental and must hold for every
// test, power-on and mid-sim resets alike.
// ===========================================================================

checker sbinit_lane_reset_sva (
  input logic clock,
  input logic reset,
  input logic tx_valid,
  input logic rx_valid
);
  import uvm_pkg::*;

  a_dut_quiesce: assert property (@(posedge clock)
    (reset && $past(reset)) |-> (tx_valid !== 1'b1))
    else uvm_report_error("SBINIT_SVA",
      "DUT tx_valid asserted while held in reset");

  a_tb_idle: assert property (@(posedge clock)
    (reset && $past(reset)) |-> (rx_valid !== 1'b1))
    else uvm_report_error("SBINIT_SVA",
      "TB rx_valid driven while DUT held in reset (reset-aware driver did not idle)");

endchecker

checker sbinit_ctrl_reset_sva (
  input logic clock,
  input logic reset,
  input logic fsmCtrl_done,
  input logic sbRxTxMode,
  input logic fsmCtrl_start
);
  import uvm_pkg::*;

  a_done_quiesce: assert property (@(posedge clock)
    (reset && $past(reset)) |-> (fsmCtrl_done !== 1'b1))
    else uvm_report_error("SBINIT_SVA", "fsmCtrl_done asserted while held in reset");

  a_mode_quiesce: assert property (@(posedge clock)
    (reset && $past(reset)) |-> (sbRxTxMode !== 1'b1))
    else uvm_report_error("SBINIT_SVA", "sbRxTxMode asserted while held in reset");

  a_start_idle: assert property (@(posedge clock)
    (reset && $past(reset)) |-> (fsmCtrl_start !== 1'b1))
    else uvm_report_error("SBINIT_SVA",
      "fsmCtrl_start driven while DUT held in reset (reset-aware driver did not idle)");

endchecker

// ---------------------------------------------------------------------------
// Binds onto the lane and control interfaces.
// ---------------------------------------------------------------------------
bind sb_req_if sbinit_lane_reset_sva u_req_reset (
  .clock    (clock),
  .reset    (reset),
  .tx_valid (tx_valid),
  .rx_valid (rx_valid)
);

bind sb_rsp_if sbinit_lane_reset_sva u_rsp_reset (
  .clock    (clock),
  .reset    (reset),
  .tx_valid (tx_valid),
  .rx_valid (rx_valid)
);

bind sb_ctrl_if sbinit_ctrl_reset_sva u_ctrl_reset (
  .clock         (clock),
  .reset         (reset),
  .fsmCtrl_done  (fsmCtrl_done),
  .sbRxTxMode    (sbRxTxMode),
  .fsmCtrl_start (fsmCtrl_start)
);

`endif

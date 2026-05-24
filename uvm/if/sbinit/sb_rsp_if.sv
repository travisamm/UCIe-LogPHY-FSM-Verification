`ifndef SB_RSP_IF_SV
`define SB_RSP_IF_SV

// ---------------------------------------------------------------------------
// sb_rsp_if
// ---------------------------------------------------------------------------
// SBINIT responder sideband lane. Same shape as sb_req_if; kept as its own
// interface so the responder VIP is fully independent of the requester and
// can apply back-pressure concurrently.
//
// Direction notes are from the test bench's point of view:
//   tx_*  the DUT transmits to its partner (TB observes; TB drives tx_ready)
//   rx_*  the partner transmits to the DUT (TB drives; DUT drives rx_ready)
//
// Timing hygiene: TB access goes through clocking blocks (drv_cb/mon_cb).
// ---------------------------------------------------------------------------
interface sb_rsp_if(input logic clock, input logic reset);
  logic         tx_ready;       // TB drives
  logic         tx_valid;       // DUT drives
  logic [127:0] tx_bits_data;   // DUT drives
  logic         rx_ready;       // DUT drives
  logic         rx_valid;       // TB drives
  logic [127:0] rx_bits_data;   // TB drives

  // SVA enable, set by the test from sbinit_env_cfg.expect_rsp_tx_data_stable.
  bit           stable_chk_en = 0;

  // Driver view: TB drives tx_ready + rx_*; samples the DUT-driven signals.
  clocking drv_cb @(posedge clock);
    default input #1step output #1;
    output tx_ready;
    output rx_valid;
    output rx_bits_data;
    input  tx_valid;
    input  tx_bits_data;
    input  rx_ready;
  endclocking

  // Monitor view: sample everything.
  clocking mon_cb @(posedge clock);
    default input #1step;
    input tx_ready;
    input tx_valid;
    input tx_bits_data;
    input rx_ready;
    input rx_valid;
    input rx_bits_data;
  endclocking

  modport drv (clocking drv_cb, input clock, input reset);
  modport mon (clocking mon_cb, input clock, input reset);
endinterface

`endif

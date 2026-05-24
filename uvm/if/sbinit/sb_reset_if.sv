`ifndef SB_RESET_IF_SV
`define SB_RESET_IF_SV

// ---------------------------------------------------------------------------
// sb_reset_if
// ---------------------------------------------------------------------------
// Reset injection + observation interface. Lets the testbench drive a
// sequence-controlled reset (reset_req) on top of the power-on reset without
// touching the DUT reset port connection. In logphy_tb_top:
//
//   sb_reset_if rst_if(clock, reset);
//   assign reset = por_reset | rst_if.reset_req;   // DUT .reset(reset) unchanged
//
// The reset driver drives reset_req through drv_cb; the reset monitor observes
// the *combined* reset (the `reset` input) through mon_cb and emits the single
// reset event stream.
// ---------------------------------------------------------------------------
interface sb_reset_if(input logic clock, input logic reset);
  logic reset_req;   // TB drives (OR'd into the DUT reset by tb_top)

  // Driver view: TB drives reset_req; samples the combined reset.
  clocking drv_cb @(posedge clock);
    default input #1step output #1;
    output reset_req;
    input  reset;
  endclocking

  // Monitor view: sample the combined reset (and reset_req for diagnostics).
  clocking mon_cb @(posedge clock);
    default input #1step;
    input reset;
    input reset_req;
  endclocking

  modport drv (clocking drv_cb, input clock, input reset);
  modport mon (clocking mon_cb, input clock, input reset);
endinterface

`endif

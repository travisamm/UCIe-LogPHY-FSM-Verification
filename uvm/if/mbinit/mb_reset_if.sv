`ifndef MB_RESET_IF_SV
`define MB_RESET_IF_SV

// ---------------------------------------------------------------------------
// mb_reset_if  (MBINIT reset injection + observation)
// ---------------------------------------------------------------------------
// Lets the testbench drive a sequence-controlled reset (reset_req) on top of
// the power-on reset without touching the DUT reset port connection. The OR into
// the DUT reset is wired in Pass 6:
//
//   mb_reset_if rst_if(clock, reset);
//   assign reset = por_reset | rst_if.reset_req;   // DUT .reset(reset) unchanged
//
// Pass 2 staging: reset_req is undriven (no reset injector yet) and is NOT OR'd
// into the DUT reset; this interface only observes the combined `reset` so the
// future reset monitor has a home. mon_cb samples the combined reset.
// ---------------------------------------------------------------------------
interface mb_reset_if(input logic clock, input logic reset);
  logic reset_req;   // TB drives (Pass 6 OR's it into the DUT reset)

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

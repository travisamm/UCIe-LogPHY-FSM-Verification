`ifndef MB_PTTEST_RSP_IF_SV
`define MB_PTTEST_RSP_IF_SV

// ---------------------------------------------------------------------------
// mb_pttest_rsp_if  (MBINIT Tx point-test responder handshake)
// ---------------------------------------------------------------------------
// Responder side of the Tx point test: the DUT raises start, the TB stub pulses
// done. Direction notes from the TB's point of view:
//   start  DUT drives
//   done   TB drives
//
// Pass 2 staging: passive observation mirror of mbinit_if; service stub stays in
// the legacy driver until Pass 3.
// ---------------------------------------------------------------------------
interface mb_pttest_rsp_if(input logic clock, input logic reset);
  logic start;  // DUT drives
  logic done;   // TB drives

  clocking drv_cb @(posedge clock);
    default input #1step output #1;
    output done;
    input  start;
  endclocking

  clocking mon_cb @(posedge clock);
    default input #1step;
    input start;
    input done;
  endclocking

  modport drv (clocking drv_cb, input clock, input reset);
  modport mon (clocking mon_cb, input clock, input reset);
endinterface

`endif

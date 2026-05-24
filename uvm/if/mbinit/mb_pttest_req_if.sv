`ifndef MB_PTTEST_REQ_IF_SV
`define MB_PTTEST_REQ_IF_SV

// ---------------------------------------------------------------------------
// mb_pttest_req_if  (MBINIT Tx point-test requester handshake)
// ---------------------------------------------------------------------------
// In REPAIRMB the DUT starts a Tx point test (start); the TB stub returns
// completion (done) and per-lane result bits (ptTestResults_*). Direction notes
// from the TB's point of view:
//   start          DUT drives
//   done           TB drives
//   results_valid  TB drives
//   results_bits   TB drives  (16-bit per-lane; carries the RM-02/05/07 scenarios)
//
// Pass 2 staging: passive observation mirror of mbinit_if; the point-test
// service stub (incl. RM scenario injects) keeps living in the legacy driver
// until Pass 3, where its policy moves behind the service config.
// ---------------------------------------------------------------------------
interface mb_pttest_req_if(input logic clock, input logic reset);
  logic        start;          // DUT drives
  logic        done;           // TB drives
  logic        results_valid;  // TB drives
  logic [15:0] results_bits;   // TB drives

  clocking drv_cb @(posedge clock);
    default input #1step output #1;
    output done;
    output results_valid;
    output results_bits;
    input  start;
  endclocking

  clocking mon_cb @(posedge clock);
    default input #1step;
    input start;
    input done;
    input results_valid;
    input results_bits;
  endclocking

  modport drv (clocking drv_cb, input clock, input reset);
  modport mon (clocking mon_cb, input clock, input reset);
endinterface

`endif

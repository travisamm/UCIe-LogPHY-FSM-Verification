`ifndef MB_CAL_IF_SV
`define MB_CAL_IF_SV

// ---------------------------------------------------------------------------
// mb_cal_if  (MBINIT calibration handshake)
// ---------------------------------------------------------------------------
// The CAL sub-state handshake: the DUT raises mbInitCalStart (level-high for all
// of sCAL) and the TB pulses mbInitCalDone once calibration is "complete".
// Direction notes from the TB's point of view:
//   cal_start  DUT drives (request)
//   cal_done   TB drives  (completion, pulsed cal_done_repeat_cycles after start)
//
// Pass 2 staging: passive observation mirror of mbinit_if; the cal service stub
// keeps living in the legacy driver until Pass 3.
// ---------------------------------------------------------------------------
interface mb_cal_if(input logic clock, input logic reset);
  logic cal_start;   // DUT drives (mbInitCalStart)
  logic cal_done;    // TB drives  (mbInitCalDone)

  // Driver view: TB drives cal_done; samples cal_start.
  clocking drv_cb @(posedge clock);
    default input #1step output #1;
    output cal_done;
    input  cal_start;
  endclocking

  clocking mon_cb @(posedge clock);
    default input #1step;
    input cal_start;
    input cal_done;
  endclocking

  modport drv (clocking drv_cb, input clock, input reset);
  modport mon (clocking mon_cb, input clock, input reset);
endinterface

`endif

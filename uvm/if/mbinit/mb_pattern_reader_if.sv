`ifndef MB_PATTERN_READER_IF_SV
`define MB_PATTERN_READER_IF_SV

// ---------------------------------------------------------------------------
// mb_pattern_reader_if  (MBINIT PatternReader service handshake)
// ---------------------------------------------------------------------------
// The DUT requests a pattern check (req_valid + patternType, with done/clear
// substate flags); the TB stub returns per-lane status + aggregate. Only the
// signals actually connected to the DUT in mbinit_tb_top are modeled here
// (comparisonMode / errorThreshold / doConsecutiveCount exist in the legacy
// mbinit_if but are left unconnected by the DUT instantiation). Direction notes
// from the TB's point of view:
//   req_ready        TB drives
//   req_valid        DUT drives
//   req_patternType  DUT drives
//   req_done         DUT drives  (substate flag)
//   req_clear        DUT drives  (substate flag)
//   resp_valid       TB drives
//   resp_perLane     TB drives   (16-bit per-lane pass/fail)
//   resp_aggregate   TB drives
//
// Pass 2 staging: passive observation mirror of mbinit_if; the reader service
// stub keeps living in the legacy driver until Pass 3.
// ---------------------------------------------------------------------------
interface mb_pattern_reader_if(input logic clock, input logic reset);
  logic        req_ready;       // TB drives
  logic        req_valid;       // DUT drives
  logic [1:0]  req_patternType; // DUT drives
  logic        req_done;        // DUT drives
  logic        req_clear;       // DUT drives
  logic        resp_valid;      // TB drives
  logic [15:0] resp_perLane;    // TB drives
  logic        resp_aggregate;  // TB drives

  clocking drv_cb @(posedge clock);
    default input #1step output #1;
    output req_ready;
    output resp_valid;
    output resp_perLane;
    output resp_aggregate;
    input  req_valid;
    input  req_patternType;
    input  req_done;
    input  req_clear;
  endclocking

  clocking mon_cb @(posedge clock);
    default input #1step;
    input req_ready;
    input req_valid;
    input req_patternType;
    input req_done;
    input req_clear;
    input resp_valid;
    input resp_perLane;
    input resp_aggregate;
  endclocking

  modport drv (clocking drv_cb, input clock, input reset);
  modport mon (clocking mon_cb, input clock, input reset);
endinterface

`endif

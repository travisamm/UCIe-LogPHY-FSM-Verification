`ifndef MB_PATTERN_WRITER_IF_SV
`define MB_PATTERN_WRITER_IF_SV

// ---------------------------------------------------------------------------
// mb_pattern_writer_if  (MBINIT PatternWriter service handshake)
// ---------------------------------------------------------------------------
// The DUT requests a training pattern (req_valid + patternType); the TB stub
// accepts (req_ready) and later signals completion (resp_complete). Direction
// notes from the TB's point of view:
//   req_ready       TB drives  (stub accepts the request)
//   req_valid       DUT drives
//   req_patternType DUT drives  (0=CLKREPAIR, 1=VALTRAIN, 2=PERLANEID)
//   resp_complete   TB drives  (pulsed after the request)
//
// Pass 2 staging: passive observation mirror of mbinit_if; the writer service
// stub keeps living in the legacy driver until Pass 3.
// ---------------------------------------------------------------------------
interface mb_pattern_writer_if(input logic clock, input logic reset);
  logic       req_ready;        // TB drives
  logic       req_valid;        // DUT drives
  logic [1:0] req_patternType;  // DUT drives
  logic       resp_complete;    // TB drives

  clocking drv_cb @(posedge clock);
    default input #1step output #1;
    output req_ready;
    output resp_complete;
    input  req_valid;
    input  req_patternType;
  endclocking

  clocking mon_cb @(posedge clock);
    default input #1step;
    input req_ready;
    input req_valid;
    input req_patternType;
    input resp_complete;
  endclocking

  modport drv (clocking drv_cb, input clock, input reset);
  modport mon (clocking mon_cb, input clock, input reset);
endinterface

`endif

`ifndef LOGPHY_IF_SV
`define LOGPHY_IF_SV

// ---------------------------------------------------------------------------
// DEPRECATED — do not use in new code.
// ---------------------------------------------------------------------------
// SBINIT has migrated to the split interfaces sb_ctrl_if / sb_req_if /
// sb_rsp_if. This combined interface is retained ONLY because the MBINIT and
// MBTRAIN Makefile targets still list ./if/logphy_if.sv on their compile
// lines. It is compiled-but-unused there (those suites use mbinit_if /
// mbtrain_if). Once MB/MBTRAIN are migrated off it, delete this file and
// remove it from those Makefile targets.
// ---------------------------------------------------------------------------
interface logphy_if(input logic clock, input logic reset);
  logic          fsmCtrl_start;
  logic          fsmCtrl_substateTransitioning;
  logic          fsmCtrl_error;
  logic          fsmCtrl_done;
  logic          sbRxTxMode;

  // Requester
  logic          requesterSbLaneIo_tx_ready;
  logic          requesterSbLaneIo_tx_valid;
  logic [127:0]  requesterSbLaneIo_tx_bits_data;
  logic          requesterSbLaneIo_rx_ready;
  logic          requesterSbLaneIo_rx_valid;
  logic [127:0]  requesterSbLaneIo_rx_bits_data;

  // Responder
  logic          responderSbLaneIo_tx_ready;
  logic          responderSbLaneIo_tx_valid;
  logic [127:0]  responderSbLaneIo_tx_bits_data;
  logic          responderSbLaneIo_rx_ready;
  logic          responderSbLaneIo_rx_valid;
  logic [127:0]  responderSbLaneIo_rx_bits_data;

endinterface

`endif

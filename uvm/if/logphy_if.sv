`ifndef LOGPHY_IF_SV
`define LOGPHY_IF_SV

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

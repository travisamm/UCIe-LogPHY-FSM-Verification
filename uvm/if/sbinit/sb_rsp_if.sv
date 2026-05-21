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
// TODO(tier1-clocking): add a clocking block (input/output skews).
// TODO(tier1-threading): tx_ready is bundled with rx_* in one transaction;
// independent tx-ready vs rx control on this lane is a later chunk.
// ---------------------------------------------------------------------------
interface sb_rsp_if(input logic clock, input logic reset);
  logic         tx_ready;       // TB drives
  logic         tx_valid;       // DUT drives
  logic [127:0] tx_bits_data;   // DUT drives
  logic         rx_ready;       // DUT drives
  logic         rx_valid;       // TB drives
  logic [127:0] rx_bits_data;   // TB drives
endinterface

`endif

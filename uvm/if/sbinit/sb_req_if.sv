`ifndef SB_REQ_IF_SV
`define SB_REQ_IF_SV

// ---------------------------------------------------------------------------
// sb_req_if
// ---------------------------------------------------------------------------
// SBINIT requester sideband lane. Signal names drop the historical
// `requesterSbLaneIo_` prefix since the interface name carries the side.
//
// Direction notes are from the test bench's point of view:
//   tx_*  the DUT transmits to its partner (TB observes; TB drives tx_ready)
//   rx_*  the partner transmits to the DUT (TB drives; DUT drives rx_ready)
//
// TODO(tier1-clocking): add a clocking block (input/output skews) so the
// driver/monitor sample and drive synchronously instead of touching nets
// directly.
// TODO(tier1-threading): tx_ready is bundled with rx_* in one transaction,
// so within this lane tx_ready cannot be varied independently of rx_* in the
// same cycle. Splitting the driver into independent tx-ready and rx threads
// (or separate sub-sequences) is a later chunk.
// ---------------------------------------------------------------------------
interface sb_req_if(input logic clock, input logic reset);
  logic         tx_ready;       // TB drives  (partner ready to accept DUT TX)
  logic         tx_valid;       // DUT drives
  logic [127:0] tx_bits_data;   // DUT drives
  logic         rx_ready;       // DUT drives
  logic         rx_valid;       // TB drives
  logic [127:0] rx_bits_data;   // TB drives
endinterface

`endif

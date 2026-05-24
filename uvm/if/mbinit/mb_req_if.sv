`ifndef MB_REQ_IF_SV
`define MB_REQ_IF_SV

// ---------------------------------------------------------------------------
// mb_req_if  (MBINIT requester sideband lane)
// ---------------------------------------------------------------------------
// Signal names drop the historical `requesterSbLaneIo_` prefix since the
// interface name carries the side. Direction notes are from the TB's point of
// view:
//   tx_*  the DUT transmits to its partner (TB observes; TB drives tx_ready)
//   rx_*  the partner transmits to the DUT (TB drives; DUT drives rx_ready)
//
// Pass 2 staging: this interface is instantiated in mbinit_tb_top as a passive
// observation mirror of the monolithic mbinit_if (assign mb_req.x = vif.x). The
// DUT still binds to vif in Pass 2; the DUT-port migration and the bridge flip
// (so the new drivers drive these clocking outputs) happen in Pass 3.
// ---------------------------------------------------------------------------
interface mb_req_if(input logic clock, input logic reset);
  logic         tx_ready;       // TB drives  (partner ready to accept DUT TX)
  logic         tx_valid;       // DUT drives
  logic [127:0] tx_bits_data;   // DUT drives
  logic         rx_ready;       // DUT drives
  logic         rx_valid;       // TB drives
  logic [127:0] rx_bits_data;   // TB drives

  // SVA enable (Pass 6 payload-stability checker), set from mbinit_env_cfg.
  bit           stable_chk_en = 0;

  // Driver view: TB drives tx_ready + rx_*; samples the DUT-driven signals.
  clocking drv_cb @(posedge clock);
    default input #1step output #1;
    output tx_ready;
    output rx_valid;
    output rx_bits_data;
    input  tx_valid;
    input  tx_bits_data;
    input  rx_ready;
  endclocking

  // Monitor view: sample everything.
  clocking mon_cb @(posedge clock);
    default input #1step;
    input tx_ready;
    input tx_valid;
    input tx_bits_data;
    input rx_ready;
    input rx_valid;
    input rx_bits_data;
  endclocking

  modport drv (clocking drv_cb, input clock, input reset);
  modport mon (clocking mon_cb, input clock, input reset);
endinterface

`endif

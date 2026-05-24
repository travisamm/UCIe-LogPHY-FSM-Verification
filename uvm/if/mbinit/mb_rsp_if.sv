`ifndef MB_RSP_IF_SV
`define MB_RSP_IF_SV

// ---------------------------------------------------------------------------
// mb_rsp_if  (MBINIT responder sideband lane)
// ---------------------------------------------------------------------------
// Responder analog of mb_req_if; same ready/valid shape. Direction notes from
// the TB's point of view:
//   tx_*  the DUT transmits to its partner (TB observes; TB drives tx_ready)
//   rx_*  the partner transmits to the DUT (TB drives; DUT drives rx_ready)
//
// Pass 2 staging: passive observation mirror of mbinit_if; see mb_req_if.
// ---------------------------------------------------------------------------
interface mb_rsp_if(input logic clock, input logic reset);
  logic         tx_ready;       // TB drives
  logic         tx_valid;       // DUT drives
  logic [127:0] tx_bits_data;   // DUT drives
  logic         rx_ready;       // DUT drives
  logic         rx_valid;       // TB drives
  logic [127:0] rx_bits_data;   // TB drives

  // SVA enable (Pass 6 payload-stability checker), set from mbinit_env_cfg.
  bit           stable_chk_en = 0;

  clocking drv_cb @(posedge clock);
    default input #1step output #1;
    output tx_ready;
    output rx_valid;
    output rx_bits_data;
    input  tx_valid;
    input  tx_bits_data;
    input  rx_ready;
  endclocking

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

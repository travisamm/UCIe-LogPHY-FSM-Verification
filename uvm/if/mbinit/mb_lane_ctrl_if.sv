`ifndef MB_LANE_CTRL_IF_SV
`define MB_LANE_CTRL_IF_SV

// ---------------------------------------------------------------------------
// mb_lane_ctrl_if  (MBINIT mainband lane-control observation, XC-05)
// ---------------------------------------------------------------------------
// mbLaneCtrlIo is entirely DUT-driven (per-state Tx/Rx enable encoding). This
// interface is observe-only: there is no TB-driven signal, so it provides only a
// monitor clocking block / modport. En polarity: 1 = enabled/active.
//
// Pass 2 staging: passive observation mirror of mbinit_if; the lane-control
// monitor that publishes XC-05 evidence arrives in Pass 4.
// ---------------------------------------------------------------------------
interface mb_lane_ctrl_if(input logic clock, input logic reset);
  logic [15:0] tx_data_en;   // DUT drives
  logic        tx_clk_en;    // DUT drives
  logic        tx_valid_en;  // DUT drives
  logic        tx_track_en;  // DUT drives
  logic [15:0] rx_data_en;   // DUT drives
  logic        rx_clk_en;    // DUT drives
  logic        rx_valid_en;  // DUT drives
  logic        rx_track_en;  // DUT drives

  // Monitor view only (nothing is TB-driven).
  clocking mon_cb @(posedge clock);
    default input #1step;
    input tx_data_en;
    input tx_clk_en;
    input tx_valid_en;
    input tx_track_en;
    input rx_data_en;
    input rx_clk_en;
    input rx_valid_en;
    input rx_track_en;
  endclocking

  modport mon (clocking mon_cb, input clock, input reset);
endinterface

`endif

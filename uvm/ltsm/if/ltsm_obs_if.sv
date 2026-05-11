`ifndef LTSM_OBS_IF_SV
`define LTSM_OBS_IF_SV

// Observation hook for LinkTrainingSM RV-06 / train-error tests (fused SB + ltState).
interface ltsm_obs_if (input logic clk, input logic rst);
  logic [3:0] lt_state;
  logic       sb_tx_valid;
  logic [127:0] sb_tx_data;
  logic       sb_rx_valid;
  logic [127:0] sb_rx_data;
  logic       tb_sw_start;

  modport tb(
      input lt_state,
      sb_tx_valid,
      sb_tx_data,
      sb_rx_valid,
      sb_rx_data,
      clk,
      rst,
      output tb_sw_start
  );
endinterface

`endif

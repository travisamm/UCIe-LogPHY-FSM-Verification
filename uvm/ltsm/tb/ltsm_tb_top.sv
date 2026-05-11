`timescale 1ns/1ps
/*
  LinkTrainingSM + fused sideband partner: SBINIT → MBINIT with REPAIRVAL fail (RV-06),
  then TRAINERROR_ENTRY REQ/RESP on io_sbLaneIo (TE-02 / TE-03 style closure).

  Sources live under uvm/ltsm/{tb,if,tests}/.

  Run from uvm/:  make ltsm
                  make ltsm LTSTEST=test_ltsm_mbinit_repairval_trainerror
*/
module ltsm_tb_top;
  import uvm_pkg::*;
  import ltsm_test_pkg::*;
  `include "uvm_macros.svh"

  `include "ltsm_tb_wires.inc.sv"

  ltsm_obs_if obs_if (
      .clk  (clock),
      .rst  (reset)
  );

  assign io_swStartLinkTraining = obs_if.tb_sw_start;
  assign obs_if.lt_state       = io_ltState;
  assign obs_if.sb_tx_valid    = io_sbLaneIo_tx_valid;
  assign obs_if.sb_tx_data     = io_sbLaneIo_tx_bits_data;
  assign obs_if.sb_rx_valid    = io_sbLaneIo_rx_valid;
  assign obs_if.sb_rx_data     = io_sbLaneIo_rx_bits_data;

  `include "ltsm_tb_input_assigns.inc.sv"

  initial begin
    clock = 0;
    forever #5 clock = ~clock;
  end

  initial begin
    reset = 1;
    #20 reset = 0;
  end

  initial begin
    obs_if.tb_sw_start = 0;
    io_patternWriterIo_resp_complete = 0;
    io_patternReaderIo_resp_valid = 0;
  end

  // PatternWriter stub (matches mbinit_driver idea)
  initial begin
    forever begin
      @(posedge clock iff io_patternWriterIo_req_valid);
      repeat (5) @(posedge clock);
      io_patternWriterIo_resp_complete = 1;
      @(posedge clock);
      io_patternWriterIo_resp_complete = 0;
    end
  end

  // PatternReader stub — pulse resp_valid when DUT pulses req_bits_done
  initial begin
    forever begin
      @(posedge clock iff (io_patternReaderIo_req_valid && io_patternReaderIo_req_bits_done));
      io_patternReaderIo_resp_valid = 1;
      @(posedge clock);
      io_patternReaderIo_resp_valid = 0;
    end
  end

  ltsm_fused_sb_partner u_partner (
      .clk           (clock),
      .rst           (reset),
      .lt_state      (io_ltState),
      .dut_tx_valid  (io_sbLaneIo_tx_valid),
      .dut_tx_data   (io_sbLaneIo_tx_bits_data),
      .dut_tx_ready  (io_sbLaneIo_tx_ready),
      .dut_rx_valid  (io_sbLaneIo_rx_valid),
      .dut_rx_data   (io_sbLaneIo_rx_bits_data)
  );

  LinkTrainingSM dut (
`include "ltsm_tb_dut_pins.inc.sv"
  );

  initial begin
    uvm_config_db#(virtual ltsm_obs_if.tb)::set(null, "*", "ltsm_obs_vif", obs_if.tb);
    run_test();
  end
endmodule

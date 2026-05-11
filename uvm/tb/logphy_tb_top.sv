`timescale 1ns/1ps

module logphy_tb_top;
  import uvm_pkg::*;
  import logphy_test_pkg::*;

  logic clock;
  logic reset;

  // Clock generation
  initial begin
    clock = 0;
    forever #5 clock = ~clock;
  end

  // Reset generation
  initial begin
    reset = 1;
    #20 reset = 0;
  end

  // Interface instance
  logphy_if vif(clock, reset);

  // DUT instantiation
  // SBInitSM exposes only io_fsmCtrl_{start,done}; substateTransitioning/error are tied inside RTL.
  SBInitSM dut (
    .clock(clock),
    .reset(reset),
    .io_fsmCtrl_start(vif.fsmCtrl_start),
    .io_fsmCtrl_done(vif.fsmCtrl_done),
    .io_sbRxTxMode(vif.sbRxTxMode),
    .io_requesterSbLaneIo_tx_ready(vif.requesterSbLaneIo_tx_ready),
    .io_requesterSbLaneIo_tx_valid(vif.requesterSbLaneIo_tx_valid),
    .io_requesterSbLaneIo_tx_bits_data(vif.requesterSbLaneIo_tx_bits_data),
    .io_requesterSbLaneIo_rx_ready(vif.requesterSbLaneIo_rx_ready),
    .io_requesterSbLaneIo_rx_valid(vif.requesterSbLaneIo_rx_valid),
    .io_requesterSbLaneIo_rx_bits_data(vif.requesterSbLaneIo_rx_bits_data),
    .io_responderSbLaneIo_tx_ready(vif.responderSbLaneIo_tx_ready),
    .io_responderSbLaneIo_tx_valid(vif.responderSbLaneIo_tx_valid),
    .io_responderSbLaneIo_tx_bits_data(vif.responderSbLaneIo_tx_bits_data),
    .io_responderSbLaneIo_rx_ready(vif.responderSbLaneIo_rx_ready),
    .io_responderSbLaneIo_rx_valid(vif.responderSbLaneIo_rx_valid),
    .io_responderSbLaneIo_rx_bits_data(vif.responderSbLaneIo_rx_bits_data)
  );

  // Initial UVM config db and start test
  initial begin
    uvm_config_db#(virtual logphy_if)::set(null, "*", "vif", vif);
    run_test();
  end

endmodule

`timescale 1ns/1ps

module logphy_tb_top;
  import uvm_pkg::*;
  import sbinit_test_pkg::*;

  logic clock;
  logic reset;
  logic por_reset;

  // Clock generation
  initial begin
    clock = 0;
    forever #5 clock = ~clock;
  end

  // Reset generation: power-on reset OR a sequence-injected reset. The reset
  // agent drives rst_if.reset_req; the DUT reset is the OR of the two so
  // mid-sim resets can be injected WITHOUT touching the DUT port connection.
  initial begin
    por_reset = 1;
    #20 por_reset = 0;
  end

  // Reset injection + observation interface, and the combined DUT reset.
  sb_reset_if rst_if(clock, reset);
  assign reset = por_reset | rst_if.reset_req;

  // Split interfaces: FSM control, requester lane, responder lane.
  sb_ctrl_if ctrl_if(clock, reset);
  sb_req_if  req_if (clock, reset);
  sb_rsp_if  rsp_if (clock, reset);

  // fsmCtrl_error is hardcoded 0 inside SBInitSM (not exposed as a port); tie the interface wire so
  // the monitor never samples X and cp_fsm_error.no_error is reachable.
  assign ctrl_if.fsmCtrl_error = 1'b0;

  // DUT instantiation
  // SBInitSM exposes only io_fsmCtrl_{start,done}; substateTransitioning/error are tied inside RTL.
  SBInitSM dut (
    .clock(clock),
    .reset(reset),
    .io_fsmCtrl_start(ctrl_if.fsmCtrl_start),
    .io_fsmCtrl_done(ctrl_if.fsmCtrl_done),
    .io_sbRxTxMode(ctrl_if.sbRxTxMode),
    .io_requesterSbLaneIo_tx_ready(req_if.tx_ready),
    .io_requesterSbLaneIo_tx_valid(req_if.tx_valid),
    .io_requesterSbLaneIo_tx_bits_data(req_if.tx_bits_data),
    .io_requesterSbLaneIo_rx_ready(req_if.rx_ready),
    .io_requesterSbLaneIo_rx_valid(req_if.rx_valid),
    .io_requesterSbLaneIo_rx_bits_data(req_if.rx_bits_data),
    .io_responderSbLaneIo_tx_ready(rsp_if.tx_ready),
    .io_responderSbLaneIo_tx_valid(rsp_if.tx_valid),
    .io_responderSbLaneIo_tx_bits_data(rsp_if.tx_bits_data),
    .io_responderSbLaneIo_rx_ready(rsp_if.rx_ready),
    .io_responderSbLaneIo_rx_valid(rsp_if.rx_valid),
    .io_responderSbLaneIo_rx_bits_data(rsp_if.rx_bits_data)
  );

  // Initial UVM config db and start test
  initial begin
    uvm_config_db#(virtual sb_ctrl_if )::set(null, "*", "sbinit_ctrl_vif",  ctrl_if);
    uvm_config_db#(virtual sb_req_if  )::set(null, "*", "sbinit_req_vif",   req_if);
    uvm_config_db#(virtual sb_rsp_if  )::set(null, "*", "sbinit_rsp_vif",   rsp_if);
    uvm_config_db#(virtual sb_reset_if)::set(null, "*", "sbinit_reset_vif", rst_if);
    run_test();
  end

endmodule

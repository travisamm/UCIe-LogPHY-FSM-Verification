`ifndef LTSM_TESTS_SV
`define LTSM_TESTS_SV

// RV-06 + TE-02/TE-03: LinkTrainingSM runs embedded MBINIT; partner forces REPAIRVAL fail;
// DUT raises localError → TrainError REQ on fused SB; partner returns TRAINERROR_ENTRY RESP;
// scoreboard-style checks on the same io_sbLaneIo path the LTSM uses.
class test_ltsm_mbinit_repairval_trainerror extends uvm_test;
  `uvm_component_utils(test_ltsm_mbinit_repairval_trainerror)

  virtual ltsm_obs_if.tb vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual ltsm_obs_if.tb)::get(this, "", "ltsm_obs_vif", vif))
      `uvm_fatal("NO_VIF", "ltsm_obs_vif not set")
  endfunction

  task run_phase(uvm_phase phase);
    int unsigned cyc;
    bit saw_te_req, saw_te_resp;
    phase.raise_objection(this);

    // Wait for LTSM resetMinWait (~half of 8ms @ 800MHz nominal ≈ 3.2M cycles @ 100MHz TB clock).
    `uvm_info("TEST", "Waiting resetMinWait window...", UVM_LOW)
    vif.tb_sw_start = 0;
    repeat (3_500_000) @(posedge vif.clk);

    vif.tb_sw_start = 1;
    @(posedge vif.clk);
    vif.tb_sw_start = 0;

    saw_te_req  = 0;
    saw_te_resp = 0;
    cyc         = 0;
    while (cyc < 25_000_000) begin
      @(posedge vif.clk);
      cyc++;
      if (vif.sb_tx_valid && (vif.sb_tx_data[4:0] == 5'h12) && (vif.sb_tx_data[21:14] == 8'hE5))
        saw_te_req = 1;
      if (vif.sb_rx_valid && (vif.sb_rx_data[4:0] == 5'h12) && (vif.sb_rx_data[21:14] == 8'hEA))
        saw_te_resp = 1;
      if (vif.lt_state == 4'd7 && saw_te_req && saw_te_resp) break;
    end

    if (vif.lt_state != 4'd7)
      `uvm_error("TEST", $sformatf("Expected LTState sTRAINERROR (7), got %0d", vif.lt_state))
    if (!saw_te_req)
      `uvm_error("TEST", "Never saw TRAINERROR_ENTRY_REQ (msgCode 0xE5) on DUT SB TX")
    if (!saw_te_resp)
      `uvm_error("TEST", "Never saw TRAINERROR_ENTRY_RESP (msgCode 0xEA) on DUT SB RX")

    `uvm_info("TEST", "RV-06 + train-error SB handshake observed on fused LTSM path.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

`endif

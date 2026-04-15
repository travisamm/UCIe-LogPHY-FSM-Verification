`ifndef LOGPHY_DRIVER_SV
`define LOGPHY_DRIVER_SV

class logphy_driver extends uvm_driver #(logphy_transaction);
  `uvm_component_utils(logphy_driver)

  virtual logphy_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual logphy_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"});
  endfunction

  task run_phase(uvm_phase phase);
    vif.fsmCtrl_start = 0;
    vif.requesterSbLaneIo_rx_valid = 0;
    vif.requesterSbLaneIo_rx_bits_data = 0;
    vif.responderSbLaneIo_rx_valid = 0;
    vif.responderSbLaneIo_rx_bits_data = 0;
    vif.requesterSbLaneIo_tx_ready = 1;
    vif.responderSbLaneIo_tx_ready = 1;

    // Wait for reset
    wait(vif.reset == 0);

    forever begin
      seq_item_port.get_next_item(req);
      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_item(logphy_transaction req);
    repeat(req.delay) @(posedge vif.clock);
    
    if (req.start_fsm) begin
      vif.fsmCtrl_start = 1;
      @(posedge vif.clock);
      vif.fsmCtrl_start = 0;
    end else begin
      vif.requesterSbLaneIo_rx_valid = req.rx_valid;
      vif.requesterSbLaneIo_rx_bits_data = req.rx_data;
      @(posedge vif.clock);
      vif.requesterSbLaneIo_rx_valid = 0;
    end
  endtask

endclass
`endif

`ifndef SBINIT_REQ_DRIVER_SV
`define SBINIT_REQ_DRIVER_SV

class sbinit_req_driver extends uvm_driver #(sbinit_req_transaction);
  `uvm_component_utils(sbinit_req_driver)

  virtual logphy_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual logphy_if)::get(this, "", "sbinit_req_vif", vif))
      `uvm_fatal("NO_VIF", {"sbinit_req_vif must be set for: ", get_full_name()})
  endfunction

  task run_phase(uvm_phase phase);
    vif.fsmCtrl_start              = 0;
    vif.requesterSbLaneIo_rx_valid = 0;
    vif.requesterSbLaneIo_rx_bits_data = 0;
    vif.requesterSbLaneIo_tx_ready = 1;

    wait (vif.reset == 0);

    forever begin
      seq_item_port.get_next_item(req);
      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_item(sbinit_req_transaction t);
    vif.requesterSbLaneIo_tx_ready = t.tx_ready;

    if (t.delay > 0) begin
      vif.requesterSbLaneIo_rx_valid = 0;
      repeat (t.delay) @(posedge vif.clock);
    end

    vif.fsmCtrl_start                  = t.fsmCtrl_start;
    vif.requesterSbLaneIo_rx_valid     = t.rx_valid;
    vif.requesterSbLaneIo_rx_bits_data = t.rx_data;

    repeat (t.hold_cycles > 0 ? t.hold_cycles : 1) @(posedge vif.clock);

    vif.requesterSbLaneIo_rx_valid = 0;
  endtask

endclass

`endif

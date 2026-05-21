`ifndef SBINIT_RSP_DRIVER_SV
`define SBINIT_RSP_DRIVER_SV

class sbinit_rsp_driver extends uvm_driver #(sbinit_rsp_transaction);
  `uvm_component_utils(sbinit_rsp_driver)

  virtual sb_rsp_if vif;  // responder sideband lane

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual sb_rsp_if)::get(this, "", "sbinit_rsp_vif", vif))
      `uvm_fatal("NO_VIF", {"sbinit_rsp_vif must be set for: ", get_full_name()})
  endfunction

  task run_phase(uvm_phase phase);
    vif.rx_valid     = 0;
    vif.rx_bits_data = 0;
    vif.tx_ready     = 1;

    wait (vif.reset == 0);

    forever begin
      seq_item_port.get_next_item(req);
      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  // TODO(tier1-threading): tx_ready and rx_* come from one transaction, so
  // they cannot be varied independently within the same cycle on this lane.
  // Split into separate tx-ready and rx threads/sub-sequences later.
  task drive_item(sbinit_rsp_transaction t);
    vif.tx_ready = t.tx_ready;

    if (t.delay > 0) begin
      vif.rx_valid = 0;
      repeat (t.delay) @(posedge vif.clock);
    end

    vif.rx_valid     = t.rx_valid;
    vif.rx_bits_data = t.rx_data;

    repeat (t.hold_cycles > 0 ? t.hold_cycles : 1) @(posedge vif.clock);

    vif.rx_valid = 0;
  endtask

endclass

`endif

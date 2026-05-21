`ifndef SBINIT_RSP_TXREADY_DRIVER_SV
`define SBINIT_RSP_TXREADY_DRIVER_SV

// ---------------------------------------------------------------------------
// sbinit_rsp_txready_driver
// ---------------------------------------------------------------------------
// Drives ONLY rsp_if.tx_ready. Mirror of sbinit_req_txready_driver on the
// responder lane. tx_ready is a level that persists between items.
// ---------------------------------------------------------------------------
class sbinit_rsp_txready_driver extends uvm_driver #(sbinit_txready_transaction);
  `uvm_component_utils(sbinit_rsp_txready_driver)

  virtual sb_rsp_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual sb_rsp_if)::get(this, "", "sbinit_rsp_vif", vif))
      `uvm_fatal("NO_VIF", {"sbinit_rsp_vif must be set for: ", get_full_name()})
  endfunction

  task run_phase(uvm_phase phase);
    vif.tx_ready = 1;  // partner ready to accept by default

    wait (vif.reset == 0);

    forever begin
      seq_item_port.get_next_item(req);
      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_item(sbinit_txready_transaction t);
    if (t.delay > 0)
      repeat (t.delay) @(posedge vif.clock);

    vif.tx_ready = t.tx_ready;

    repeat (t.hold_cycles > 0 ? t.hold_cycles : 1) @(posedge vif.clock);
  endtask

endclass

`endif

`ifndef SBINIT_REQ_TXREADY_DRIVER_SV
`define SBINIT_REQ_TXREADY_DRIVER_SV

// ---------------------------------------------------------------------------
// sbinit_req_txready_driver
// ---------------------------------------------------------------------------
// Drives ONLY req_if.tx_ready (the partner's readiness to accept the DUT's
// requester TX). Independent of the rx driver, so back-pressure can be held
// or pulsed while rx activity proceeds concurrently. tx_ready is a level: it
// persists at the last driven value between items.
//
// Two txready driver classes exist (req + rsp) because the lane interfaces are
// distinct types; they share the sbinit_txready_transaction item.
// ---------------------------------------------------------------------------
class sbinit_req_txready_driver extends uvm_driver #(sbinit_txready_transaction);
  `uvm_component_utils(sbinit_req_txready_driver)

  virtual sb_req_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual sb_req_if)::get(this, "", "sbinit_req_vif", vif))
      `uvm_fatal("NO_VIF", {"sbinit_req_vif must be set for: ", get_full_name()})
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
    // Hold the current level for `delay` cycles, then apply the new level and
    // hold it for `hold_cycles`. The level then persists until the next item.
    if (t.delay > 0)
      repeat (t.delay) @(posedge vif.clock);

    vif.tx_ready = t.tx_ready;

    repeat (t.hold_cycles > 0 ? t.hold_cycles : 1) @(posedge vif.clock);
  endtask

endclass

`endif

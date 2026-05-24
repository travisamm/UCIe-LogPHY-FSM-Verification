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

  // Reset-aware run loop (see sbinit_req_txready_driver for the pattern).
  task run_phase(uvm_phase phase);
    bit item_in_flight;
    forever begin
      drive_idle();
      wait (vif.reset == 1'b0);
      item_in_flight = 0;
      fork
        begin : active
          forever begin
            seq_item_port.get_next_item(req);
            item_in_flight = 1;
            drive_item(req);
            seq_item_port.item_done();
            item_in_flight = 0;
          end
        end
        begin : reset_watch
          @(posedge vif.reset);
        end
      join_any
      disable fork;
      drive_idle();
      if (item_in_flight) begin
        seq_item_port.item_done();
        item_in_flight = 0;
      end
    end
  endtask

  task drive_idle();
    vif.drv_cb.tx_ready <= 1;  // partner ready to accept by default
  endtask

  task drive_item(sbinit_txready_transaction t);
    if (t.delay > 0)
      repeat (t.delay) @(vif.drv_cb);

    vif.drv_cb.tx_ready <= t.tx_ready;

    repeat (t.hold_cycles > 0 ? t.hold_cycles : 1) @(vif.drv_cb);
  endtask

endclass

`endif

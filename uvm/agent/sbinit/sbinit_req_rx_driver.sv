`ifndef SBINIT_REQ_RX_DRIVER_SV
`define SBINIT_REQ_RX_DRIVER_SV

// ---------------------------------------------------------------------------
// sbinit_req_rx_driver
// ---------------------------------------------------------------------------
// Drives ONLY the requester RX lane (rx_valid/rx_bits_data) plus the FSM kick
// (fsmCtrl_start on the control bus). It never touches tx_ready — that is the
// sbinit_req_txready_driver's job, so the two run as independent concurrent
// channels on the same lane.
//
// fsmCtrl_start is a level the test holds; the rx item carries its value and
// the driver leaves it asserted across items until a later item clears it
// (the RTL gates sPATTERN on io.start, so it must stay high until the FSM
// reaches sOUT_OF_RESET).
// ---------------------------------------------------------------------------
class sbinit_req_rx_driver extends uvm_driver #(sbinit_req_rx_transaction);
  `uvm_component_utils(sbinit_req_rx_driver)

  virtual sb_req_if  vif;       // requester sideband lane
  virtual sb_ctrl_if ctrl_vif;  // FSM control (drives fsmCtrl_start)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual sb_req_if)::get(this, "", "sbinit_req_vif", vif))
      `uvm_fatal("NO_VIF", {"sbinit_req_vif must be set for: ", get_full_name()})
    if (!uvm_config_db#(virtual sb_ctrl_if)::get(this, "", "sbinit_ctrl_vif", ctrl_vif))
      `uvm_fatal("NO_VIF", {"sbinit_ctrl_vif must be set for: ", get_full_name()})
  endfunction

  // Reset-aware run loop: idle outputs, run until reset asserts, then abort the
  // in-flight drive, re-idle, and complete the UVM item handshake so the
  // sequence is never stranded across a reset boundary.
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
        seq_item_port.item_done();  // release the aborted item
        item_in_flight = 0;
      end
    end
  endtask

  task drive_idle();
    ctrl_vif.drv_cb.fsmCtrl_start <= 0;
    vif.drv_cb.rx_valid           <= 0;
    vif.drv_cb.rx_bits_data       <= 0;
  endtask

  task drive_item(sbinit_req_rx_transaction t);
    if (t.delay > 0) begin
      vif.drv_cb.rx_valid <= 0;
      repeat (t.delay) @(vif.drv_cb);
    end

    ctrl_vif.drv_cb.fsmCtrl_start <= t.fsmCtrl_start;
    vif.drv_cb.rx_valid           <= t.rx_valid;
    vif.drv_cb.rx_bits_data       <= t.rx_data;

    repeat (t.hold_cycles > 0 ? t.hold_cycles : 1) @(vif.drv_cb);

    vif.drv_cb.rx_valid <= 0;
  endtask

endclass

`endif

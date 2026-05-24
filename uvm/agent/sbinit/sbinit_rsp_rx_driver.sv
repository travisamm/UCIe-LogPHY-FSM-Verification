`ifndef SBINIT_RSP_RX_DRIVER_SV
`define SBINIT_RSP_RX_DRIVER_SV

// ---------------------------------------------------------------------------
// sbinit_rsp_rx_driver
// ---------------------------------------------------------------------------
// Drives ONLY the responder RX lane (rx_valid/rx_bits_data). Never touches
// tx_ready (sbinit_rsp_txready_driver owns that), so the two run as
// independent concurrent channels on the responder lane.
// ---------------------------------------------------------------------------
class sbinit_rsp_rx_driver extends uvm_driver #(sbinit_rsp_rx_transaction);
  `uvm_component_utils(sbinit_rsp_rx_driver)

  virtual sb_rsp_if vif;  // responder sideband lane

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual sb_rsp_if)::get(this, "", "sbinit_rsp_vif", vif))
      `uvm_fatal("NO_VIF", {"sbinit_rsp_vif must be set for: ", get_full_name()})
  endfunction

  // Reset-aware run loop (see sbinit_req_rx_driver for the pattern).
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
    vif.drv_cb.rx_valid     <= 0;
    vif.drv_cb.rx_bits_data <= 0;
  endtask

  task drive_item(sbinit_rsp_rx_transaction t);
    if (t.delay > 0) begin
      vif.drv_cb.rx_valid <= 0;
      repeat (t.delay) @(vif.drv_cb);
    end

    vif.drv_cb.rx_valid     <= t.rx_valid;
    vif.drv_cb.rx_bits_data <= t.rx_data;

    repeat (t.hold_cycles > 0 ? t.hold_cycles : 1) @(vif.drv_cb);

    vif.drv_cb.rx_valid <= 0;
  endtask

endclass

`endif

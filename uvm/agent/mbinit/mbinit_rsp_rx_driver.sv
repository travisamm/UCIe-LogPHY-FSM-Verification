`ifndef MBINIT_RSP_RX_DRIVER_SV
`define MBINIT_RSP_RX_DRIVER_SV

// ---------------------------------------------------------------------------
// mbinit_rsp_rx_driver  (Pass 3)
// ---------------------------------------------------------------------------
// Responder analog of mbinit_req_rx_driver: drives the responder RX lane on
// mb_rsp_if plus the tx_ready auto-stub. See mbinit_req_rx_driver for notes.
// ---------------------------------------------------------------------------
class mbinit_rsp_rx_driver extends uvm_driver #(mbinit_rx_transaction);
  `uvm_component_utils(mbinit_rsp_rx_driver)

  virtual mb_rsp_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mb_rsp_if)::get(this, "", "mbinit_rsp_vif", vif))
      `uvm_fatal("NO_VIF", {"mbinit_rsp_vif must be set for: ", get_full_name()})
  endfunction

  task run_phase(uvm_phase phase);
    drive_idle();
    wait (vif.reset == 1'b0);
    fork
      forever begin
        @(vif.drv_cb);
        vif.drv_cb.tx_ready <= vif.drv_cb.tx_valid;
      end
    join_none
    forever begin
      seq_item_port.get_next_item(req);
      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_idle();
    vif.drv_cb.tx_ready     <= 0;
    vif.drv_cb.rx_valid     <= 0;
    vif.drv_cb.rx_bits_data <= 0;
  endtask

  task drive_item(mbinit_rx_transaction t);
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

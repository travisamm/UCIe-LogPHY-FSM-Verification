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

  task run_phase(uvm_phase phase);
    vif.rx_valid     = 0;
    vif.rx_bits_data = 0;

    wait (vif.reset == 0);

    forever begin
      seq_item_port.get_next_item(req);
      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_item(sbinit_rsp_rx_transaction t);
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

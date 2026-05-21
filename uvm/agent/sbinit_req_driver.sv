`ifndef SBINIT_REQ_DRIVER_SV
`define SBINIT_REQ_DRIVER_SV

class sbinit_req_driver extends uvm_driver #(sbinit_req_transaction);
  `uvm_component_utils(sbinit_req_driver)

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

  task run_phase(uvm_phase phase);
    ctrl_vif.fsmCtrl_start = 0;
    vif.rx_valid           = 0;
    vif.rx_bits_data       = 0;
    vif.tx_ready           = 1;

    wait (vif.reset == 0);

    forever begin
      seq_item_port.get_next_item(req);
      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  // TODO(tier1-threading): tx_ready and rx_* are applied from one transaction,
  // so they cannot be varied independently within the same cycle window on
  // this lane. Split into separate tx-ready and rx threads/sub-sequences when
  // we tackle that chunk.
  task drive_item(sbinit_req_transaction t);
    vif.tx_ready = t.tx_ready;

    if (t.delay > 0) begin
      vif.rx_valid = 0;
      repeat (t.delay) @(posedge vif.clock);
    end

    ctrl_vif.fsmCtrl_start = t.fsmCtrl_start;
    vif.rx_valid           = t.rx_valid;
    vif.rx_bits_data       = t.rx_data;

    repeat (t.hold_cycles > 0 ? t.hold_cycles : 1) @(posedge vif.clock);

    vif.rx_valid = 0;
  endtask

endclass

`endif

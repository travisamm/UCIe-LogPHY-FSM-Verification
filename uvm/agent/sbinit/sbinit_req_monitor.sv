`ifndef SBINIT_REQ_MONITOR_SV
`define SBINIT_REQ_MONITOR_SV

// ---------------------------------------------------------------------------
// sbinit_req_monitor
// ---------------------------------------------------------------------------
// Requester sideband lane monitor. Samples sb_req_if each cycle through its
// monitor clocking block and emits decoded protocol events (sbinit_event) via
// the shared base. FSM control (mode/done/error) is observed by the dedicated
// sbinit_ctrl_monitor, not here.
// ---------------------------------------------------------------------------
class sbinit_req_monitor extends sbinit_lane_monitor_base;
  `uvm_component_utils(sbinit_req_monitor)

  virtual sb_req_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    src = SB_SRC_REQ_LANE;
    if (!uvm_config_db#(virtual sb_req_if)::get(this, "", "sbinit_req_vif", vif))
      `uvm_fatal("NO_VIF", {"sbinit_req_vif must be set for: ", get_full_name()})
  endfunction

  task run_phase(uvm_phase phase);
    reset_state();
    forever begin
      @(vif.mon_cb);
      if (vif.reset === 1'b1) begin
        reset_state();
        continue;
      end
      process_tx(vif.mon_cb.tx_valid, vif.mon_cb.tx_ready, vif.mon_cb.tx_bits_data);
      process_rx(vif.mon_cb.rx_valid, vif.mon_cb.rx_bits_data);
    end
  endtask

endclass

`endif

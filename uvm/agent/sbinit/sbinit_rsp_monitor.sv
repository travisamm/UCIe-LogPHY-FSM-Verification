`ifndef SBINIT_RSP_MONITOR_SV
`define SBINIT_RSP_MONITOR_SV

// ---------------------------------------------------------------------------
// sbinit_rsp_monitor
// ---------------------------------------------------------------------------
// Responder sideband lane monitor. Mirror of sbinit_req_monitor on sb_rsp_if;
// emits decoded protocol events (sbinit_event) via the shared base.
// ---------------------------------------------------------------------------
class sbinit_rsp_monitor extends sbinit_lane_monitor_base;
  `uvm_component_utils(sbinit_rsp_monitor)

  virtual sb_rsp_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    src = SB_SRC_RSP_LANE;
    if (!uvm_config_db#(virtual sb_rsp_if)::get(this, "", "sbinit_rsp_vif", vif))
      `uvm_fatal("NO_VIF", {"sbinit_rsp_vif must be set for: ", get_full_name()})
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

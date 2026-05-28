`ifndef MBINIT_RSP_MONITOR_SV
`define MBINIT_RSP_MONITOR_SV

// Responder sideband lane monitor (Pass 4). Samples mb_rsp_if each cycle and
// hands TX/RX observations to the shared base.
class mbinit_rsp_monitor extends mbinit_lane_monitor_base;
  `uvm_component_utils(mbinit_rsp_monitor)

  virtual mb_rsp_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    src = MB_SRC_RSP_LANE;
    if (!uvm_config_db#(virtual mb_rsp_if)::get(this, "", "mbinit_rsp_vif", vif))
      `uvm_fatal("NO_VIF", {"mbinit_rsp_vif must be set for: ", get_full_name()})
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

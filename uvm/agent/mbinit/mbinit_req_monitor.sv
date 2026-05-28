`ifndef MBINIT_REQ_MONITOR_SV
`define MBINIT_REQ_MONITOR_SV

// Requester sideband lane monitor (Pass 4). Samples mb_req_if each cycle and
// hands TX/RX observations to the shared base.
class mbinit_req_monitor extends mbinit_lane_monitor_base;
  `uvm_component_utils(mbinit_req_monitor)

  virtual mb_req_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    src = MB_SRC_REQ_LANE;
    if (!uvm_config_db#(virtual mb_req_if)::get(this, "", "mbinit_req_vif", vif))
      `uvm_fatal("NO_VIF", {"mbinit_req_vif must be set for: ", get_full_name()})
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

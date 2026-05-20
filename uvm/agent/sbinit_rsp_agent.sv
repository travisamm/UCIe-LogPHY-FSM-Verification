`ifndef SBINIT_RSP_AGENT_SV
`define SBINIT_RSP_AGENT_SV

class sbinit_rsp_agent extends uvm_agent;
  `uvm_component_utils(sbinit_rsp_agent)

  sbinit_rsp_driver    driver;
  sbinit_rsp_sequencer sequencer;
  sbinit_rsp_monitor   monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = sbinit_rsp_monitor::type_id::create("monitor", this);
    if (get_is_active() == UVM_ACTIVE) begin
      driver    = sbinit_rsp_driver::type_id::create("driver", this);
      sequencer = sbinit_rsp_sequencer::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

endclass

`endif

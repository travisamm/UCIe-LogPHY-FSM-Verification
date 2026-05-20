`ifndef SBINIT_REQ_AGENT_SV
`define SBINIT_REQ_AGENT_SV

class sbinit_req_agent extends uvm_agent;
  `uvm_component_utils(sbinit_req_agent)

  sbinit_req_driver    driver;
  sbinit_req_sequencer sequencer;
  sbinit_req_monitor   monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = sbinit_req_monitor::type_id::create("monitor", this);
    if (get_is_active() == UVM_ACTIVE) begin
      driver    = sbinit_req_driver::type_id::create("driver", this);
      sequencer = sbinit_req_sequencer::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

endclass

`endif

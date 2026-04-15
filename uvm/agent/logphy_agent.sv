`ifndef LOGPHY_AGENT_SV
`define LOGPHY_AGENT_SV

class logphy_agent extends uvm_agent;
  `uvm_component_utils(logphy_agent)

  logphy_driver    driver;
  logphy_sequencer sequencer;
  logphy_monitor   monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = logphy_monitor::type_id::create("monitor", this);
    if(get_is_active() == UVM_ACTIVE) begin
      driver = logphy_driver::type_id::create("driver", this);
      sequencer = logphy_sequencer::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    if(get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

endclass
`endif

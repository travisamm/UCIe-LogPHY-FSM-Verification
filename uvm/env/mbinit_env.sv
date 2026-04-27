`ifndef MBINIT_ENV_SV
`define MBINIT_ENV_SV

class mbinit_env extends uvm_env;
  `uvm_component_utils(mbinit_env)

  mbinit_agent      agent;
  mbinit_scoreboard scoreboard;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = mbinit_agent::type_id::create("agent", this);
    scoreboard = mbinit_scoreboard::type_id::create("scoreboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.monitor.item_collected_port.connect(scoreboard.item_collected_export);
  endfunction

endclass
`endif

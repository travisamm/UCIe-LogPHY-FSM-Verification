`ifndef MBTRAIN_ENV_SV
`define MBTRAIN_ENV_SV

class mbtrain_env extends uvm_env;
  `uvm_component_utils(mbtrain_env)

  mbtrain_agent      agent;
  mbtrain_scoreboard scoreboard;
  mbtrain_coverage  coverage;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = mbtrain_agent::type_id::create("agent", this);
    scoreboard = mbtrain_scoreboard::type_id::create("scoreboard", this);
    coverage   = mbtrain_coverage::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.monitor.item_collected_port.connect(scoreboard.item_collected_export);
    agent.monitor.item_collected_port.connect(coverage.analysis_export);
  endfunction

endclass
`endif

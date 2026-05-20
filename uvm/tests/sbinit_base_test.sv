`ifndef SBINIT_BASE_TEST_SV
`define SBINIT_BASE_TEST_SV

class sbinit_base_test extends uvm_test;
  `uvm_component_utils(sbinit_base_test)

  sbinit_env     env;
  sbinit_env_cfg cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg = sbinit_env_cfg::type_id::create("cfg");
    uvm_config_db#(sbinit_env_cfg)::set(this, "env", "cfg", cfg);
    env = sbinit_env::type_id::create("env", this);
  endfunction

  function sbinit_virtual_sequencer get_vseqr();
    return env.vseqr;
  endfunction

endclass

`endif

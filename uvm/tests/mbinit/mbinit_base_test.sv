`ifndef MBINIT_BASE_TEST_SV
`define MBINIT_BASE_TEST_SV

class mbinit_base_test extends uvm_test;
  `uvm_component_utils(mbinit_base_test)

  mbinit_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = mbinit_env::type_id::create("env", this);
  endfunction

endclass

`endif

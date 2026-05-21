`ifndef MBTRAIN_BASE_TEST_SV
`define MBTRAIN_BASE_TEST_SV

class mbtrain_base_test extends uvm_test;
  `uvm_component_utils(mbtrain_base_test)

  mbtrain_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = mbtrain_env::type_id::create("env", this);
  endfunction

endclass
`endif

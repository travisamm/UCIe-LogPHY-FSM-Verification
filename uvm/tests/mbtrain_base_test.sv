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

  task run_phase(uvm_phase phase);
    seq_mbtrain_full seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "Starting seq_mbtrain_full...", UVM_LOW)
    seq = seq_mbtrain_full::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #20000ns;

    `uvm_info("TEST", "Test finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass
`endif

`ifndef MBINIT_TESTS_SV
`define MBINIT_TESTS_SV

// Covers the main P0 MBINIT path from the verification plan:
// MP-01/02/03/06, MC-01/02, RC-05, RV-07, LR-01/06, RM-08.
class test_mbinit_sanity extends mbinit_base_test;
  `uvm_component_utils(test_mbinit_sanity)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbinit_full seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "Starting seq_mbinit_full...", UVM_LOW)
    seq = seq_mbinit_full::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #20000ns;

    `uvm_info("TEST", "Test seq_mbinit_full finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// Focused PARAM negotiation test: MP-01/02/03.
class test_mbinit_param_only extends mbinit_base_test;
  `uvm_component_utils(test_mbinit_param_only)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbinit_param_only seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbinit = 0;
    env.scoreboard.expect_fsm_done    = 0;

    `uvm_info("TEST", "Starting seq_mbinit_param_only...", UVM_LOW)
    seq = seq_mbinit_param_only::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #5000ns;

    `uvm_info("TEST", "Test seq_mbinit_param_only finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// Negative PARAM negotiation test: MP-04.
class test_mbinit_param_mismatch extends mbinit_base_test;
  `uvm_component_utils(test_mbinit_param_mismatch)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbinit_param_mismatch seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbinit       = 0;
    env.scoreboard.expect_param_messages    = 0;
    env.scoreboard.expect_param_common_rate = 0;
    env.scoreboard.expect_param_negotiation = 0;
    env.scoreboard.expect_interop_failure   = 1;
    env.scoreboard.expect_fsm_done          = 0;
    env.scoreboard.expect_fsm_error         = 1;

    `uvm_info("TEST", "Starting seq_mbinit_param_mismatch...", UVM_LOW)
    seq = seq_mbinit_param_mismatch::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #5000ns;

    `uvm_info("TEST", "Test seq_mbinit_param_mismatch finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

`endif

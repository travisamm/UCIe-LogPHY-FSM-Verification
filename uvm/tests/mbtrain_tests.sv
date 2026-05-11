`ifndef MBTRAIN_TESTS_SV
`define MBTRAIN_TESTS_SV

// Focused VALVREF coverage for VV-01/02/03/04/06.
class test_mbtrain_valvref extends mbtrain_base_test;
  `uvm_component_utils(test_mbtrain_valvref)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbtrain_valvref seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbtrain = 0;
    env.scoreboard.expect_valvref_checks = 1;
    env.scoreboard.expect_datavref_checks = 0;
    env.scoreboard.expect_fsm_done = 0;
    env.scoreboard.expect_fsm_error = 0;
    env.scoreboard.expected_max_error_threshold = 16'h0007;

    `uvm_info("TEST", "Starting seq_mbtrain_valvref...", UVM_LOW)
    seq = seq_mbtrain_valvref::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #10000ns;

    `uvm_info("TEST", "Test seq_mbtrain_valvref finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// Focused DATAVREF coverage for DV-01/02/03.
class test_mbtrain_datavref extends mbtrain_base_test;
  `uvm_component_utils(test_mbtrain_datavref)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbtrain_datavref seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbtrain = 0;
    env.scoreboard.expect_valvref_checks = 0;
    env.scoreboard.expect_datavref_checks = 1;
    env.scoreboard.expect_fsm_done = 0;
    env.scoreboard.expect_fsm_error = 0;
    env.scoreboard.expected_max_error_threshold = 16'h0009;

    `uvm_info("TEST", "Starting seq_mbtrain_datavref...", UVM_LOW)
    seq = seq_mbtrain_datavref::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #12000ns;

    `uvm_info("TEST", "Test seq_mbtrain_datavref finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// Full happy-path through all 12 MBTRAIN sub-states:
// VALVREF → DATAVREF → SPEEDIDLE → TXSELFCAL → RXCLKCAL →
// VALTRAINCENTER → VALTRAINVREF → DATATRAINCENTER1 →
// DATATRAINVREF → RXDESKEW → DATATRAINCENTER2 → LINKSPEED
class test_mbtrain_sanity extends mbtrain_base_test;
  `uvm_component_utils(test_mbtrain_sanity)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbtrain_full seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "Starting seq_mbtrain_full...", UVM_LOW)
    seq = seq_mbtrain_full::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #20000ns;

    `uvm_info("TEST", "Test seq_mbtrain_full finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

`endif

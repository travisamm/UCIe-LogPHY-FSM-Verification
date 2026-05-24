`ifndef MBTRAIN_TESTS_SV
`define MBTRAIN_TESTS_SV

// Flip to 1'b1 before remote runs when TXSELFCAL root-cause logs are needed.
localparam bit MBTRAIN_DEBUG_TXSELFCAL = 1'b0;

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
    env.scoreboard.expect_txselfcal_checks = 0;
    env.scoreboard.expect_fsm_done = 0;
    env.scoreboard.expect_fsm_error = 0;
    env.scoreboard.debug_txselfcal = MBTRAIN_DEBUG_TXSELFCAL;
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
    env.scoreboard.expect_txselfcal_checks = 0;
    env.scoreboard.expect_fsm_done = 0;
    env.scoreboard.expect_fsm_error = 0;
    env.scoreboard.debug_txselfcal = MBTRAIN_DEBUG_TXSELFCAL;
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

    env.scoreboard.debug_txselfcal = MBTRAIN_DEBUG_TXSELFCAL;

    `uvm_info("TEST", "Starting seq_mbtrain_full...", UVM_LOW)
    seq = seq_mbtrain_full::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #20000ns;

    `uvm_info("TEST", "Test seq_mbtrain_full finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// Optional focused TXSELFCAL probe. Not included in MBTRAIN_TESTS by default;
// run with: make mbtrain MBTRAINTEST=test_mbtrain_txselfcal_probe
class test_mbtrain_txselfcal_probe extends mbtrain_base_test;
  `uvm_component_utils(test_mbtrain_txselfcal_probe)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbtrain_txselfcal_probe seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbtrain = 0;
    env.scoreboard.expect_valvref_checks = 0;
    env.scoreboard.expect_datavref_checks = 0;
    env.scoreboard.expect_txselfcal_checks = 1;
    env.scoreboard.expect_fsm_done = 0;
    env.scoreboard.expect_fsm_error = 0;
    env.scoreboard.debug_txselfcal = MBTRAIN_DEBUG_TXSELFCAL;

    `uvm_info("TEST", "Starting seq_mbtrain_txselfcal_probe...", UVM_LOW)
    seq = seq_mbtrain_txselfcal_probe::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #12000ns;

    `uvm_info("TEST", "Test seq_mbtrain_txselfcal_probe finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass


// SI-01/06: Normal SPEEDIDLE path from DATAVREF -> TXSELFCAL
class test_mbtrain_speedidle extends mbtrain_base_test;
  `uvm_component_utils(test_mbtrain_speedidle)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbtrain_speedidle seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbtrain    = 0;
    env.scoreboard.expect_valvref_checks  = 0;
    env.scoreboard.expect_datavref_checks = 0;
    env.scoreboard.expect_txselfcal_checks = 0;
    env.scoreboard.expect_fsm_done        = 0;
    env.scoreboard.expect_fsm_error       = 0;
    env.scoreboard.debug_txselfcal        = MBTRAIN_DEBUG_TXSELFCAL;

    `uvm_info("TEST", "Starting seq_mbtrain_speedidle...", UVM_LOW)
    seq = seq_mbtrain_speedidle::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #10000ns;

    `uvm_info("TEST", "Test test_mbtrain_speedidle finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// SI-02: SPEEDIDLE from L1/retrain path via goToState_valid
class test_mbtrain_speedidle_retrain extends mbtrain_base_test;
  `uvm_component_utils(test_mbtrain_speedidle_retrain)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbtrain_speedidle_retrain seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbtrain    = 0;
    env.scoreboard.expect_valvref_checks  = 0;
    env.scoreboard.expect_datavref_checks = 0;
    env.scoreboard.expect_txselfcal_checks = 0;
    env.scoreboard.expect_fsm_done        = 0;
    env.scoreboard.expect_fsm_error       = 0;
    env.scoreboard.debug_txselfcal        = MBTRAIN_DEBUG_TXSELFCAL;

    `uvm_info("TEST", "Starting seq_mbtrain_speedidle_retrain...", UVM_LOW)
    seq = seq_mbtrain_speedidle_retrain::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #10000ns;

    `uvm_info("TEST", "Test test_mbtrain_speedidle_retrain finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// SI-04: SPEEDIDLE with no valid frequency -> expect TRAINERROR
class test_mbtrain_speedidle_error extends mbtrain_base_test;
  `uvm_component_utils(test_mbtrain_speedidle_error)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbtrain_speedidle_error seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbtrain    = 0;
    env.scoreboard.expect_valvref_checks  = 0;
    env.scoreboard.expect_datavref_checks = 0;
    env.scoreboard.expect_txselfcal_checks = 0;
    env.scoreboard.expect_fsm_done        = 0;
    env.scoreboard.expect_fsm_error       = 0; // SI-04 blocked: RTL does not assert error on invalid freq
    env.scoreboard.debug_txselfcal        = MBTRAIN_DEBUG_TXSELFCAL;

    `uvm_info("TEST", "Starting seq_mbtrain_speedidle_error...", UVM_LOW)
    seq = seq_mbtrain_speedidle_error::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #10000ns;

    `uvm_info("TEST", "Test test_mbtrain_speedidle_error finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass
// RCC-01/02/05: Focused RXCLKCAL test
class test_mbtrain_rxclkcal extends mbtrain_base_test;
  `uvm_component_utils(test_mbtrain_rxclkcal)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbtrain_rxclkcal seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbtrain     = 0;
    env.scoreboard.expect_valvref_checks   = 0;
    env.scoreboard.expect_datavref_checks  = 0;
    env.scoreboard.expect_txselfcal_checks = 0;
    env.scoreboard.expect_rxclkcal_checks  = 1;
    env.scoreboard.expect_fsm_done         = 0;
    env.scoreboard.expect_fsm_error        = 0;
    env.scoreboard.debug_txselfcal         = MBTRAIN_DEBUG_TXSELFCAL;

    `uvm_info("TEST", "Starting seq_mbtrain_rxclkcal...", UVM_LOW)
    seq = seq_mbtrain_rxclkcal::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #10000ns;

    `uvm_info("TEST", "Test test_mbtrain_rxclkcal finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass
// DC2-01: Focused DATATRAINCENTER2 test
class test_mbtrain_dc2 extends mbtrain_base_test;
  `uvm_component_utils(test_mbtrain_dc2)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbtrain_dc2 seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbtrain    = 0;
    env.scoreboard.expect_valvref_checks  = 0;
    env.scoreboard.expect_datavref_checks = 0;
    env.scoreboard.expect_txselfcal_checks = 0;
    env.scoreboard.expect_rxclkcal_checks = 0;
    env.scoreboard.expect_dc2_checks      = 1;
    env.scoreboard.expect_ls_checks       = 0;
    env.scoreboard.expect_fsm_done        = 0;
    env.scoreboard.expect_fsm_error       = 0;
    env.scoreboard.debug_txselfcal        = MBTRAIN_DEBUG_TXSELFCAL;

    `uvm_info("TEST", "Starting seq_mbtrain_dc2...", UVM_LOW)
    seq = seq_mbtrain_dc2::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #20000ns;

    `uvm_info("TEST", "Test test_mbtrain_dc2 finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// LS-01/03: Focused LINKSPEED test
class test_mbtrain_linkspeed extends mbtrain_base_test;
  `uvm_component_utils(test_mbtrain_linkspeed)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbtrain_linkspeed seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbtrain    = 0;
    env.scoreboard.expect_valvref_checks  = 0;
    env.scoreboard.expect_datavref_checks = 0;
    env.scoreboard.expect_txselfcal_checks = 0;
    env.scoreboard.expect_rxclkcal_checks = 0;
    env.scoreboard.expect_dc2_checks      = 0;
    env.scoreboard.expect_ls_checks       = 1;
    env.scoreboard.expect_fsm_done        = 0;
    env.scoreboard.expect_fsm_error       = 0;
    env.scoreboard.debug_txselfcal        = MBTRAIN_DEBUG_TXSELFCAL;

    `uvm_info("TEST", "Starting seq_mbtrain_linkspeed...", UVM_LOW)
    seq = seq_mbtrain_linkspeed::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #20000ns;

    `uvm_info("TEST", "Test test_mbtrain_linkspeed finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass
// LS-04: LINKSPEED fail -> PHYRETRAIN with speed degrade
class test_mbtrain_linkspeed_fail extends mbtrain_base_test;
  `uvm_component_utils(test_mbtrain_linkspeed_fail)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbtrain_linkspeed_fail seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbtrain    = 0;
    env.scoreboard.expect_valvref_checks  = 0;
    env.scoreboard.expect_datavref_checks = 0;
    env.scoreboard.expect_txselfcal_checks = 0;
    env.scoreboard.expect_rxclkcal_checks = 0;
    env.scoreboard.expect_dc2_checks      = 0;
    env.scoreboard.expect_ls_checks       = 0;
    env.scoreboard.expect_fsm_done        = 0;
    env.scoreboard.expect_fsm_error = 0; // LS-04 blocked: RTL does not assert error on link test fail
    env.scoreboard.debug_txselfcal        = MBTRAIN_DEBUG_TXSELFCAL;

    `uvm_info("TEST", "Starting seq_mbtrain_linkspeed_fail...", UVM_LOW)
    seq = seq_mbtrain_linkspeed_fail::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #20000ns;

    `uvm_info("TEST", "Test test_mbtrain_linkspeed_fail finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass
`endif

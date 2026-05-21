`ifndef MBINIT_TESTS_SV
`define MBINIT_TESTS_SV

// Covers the main P0 MBINIT path from the verification plan:
// MP-01/02/03/06, MC-01/02, RC-01/02/05, RV-01/07, LR-01/06, RM-08.
// CAL-focused: `test_mbinit_cal` + `seq_mbinit_cal_only`.
// REPAIRCLK-focused: `test_mbinit_repairclk` + `seq_mbinit_repairclk_only`.
// Note: expect_fsm_done is off until dual-die fsmCtrl_done (responder closure) is fixed — RM-08 tombtrain + messages still checked.
class test_mbinit_sanity extends mbinit_base_test;
  `uvm_component_utils(test_mbinit_sanity)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // MBInitState on io_currentState is the *requester* only (see MBInitSM.scala).
  // fsmCtrl_done = requester.done && responder.done — so state==6 with done==0
  // means requester reached TOMBTRAIN but responder did not assert done (no waves needed).
  task run_phase(uvm_phase phase);
    seq_mbinit_full seq;
    virtual mbinit_if vif;
    phase.raise_objection(this);

    env.scoreboard.expect_fsm_done = 0;

    `uvm_info("TEST", "Starting seq_mbinit_full...", UVM_LOW)
    seq = seq_mbinit_full::type_id::create("seq");
    seq.start(env.agent.sequencer);

    if (uvm_config_db#(virtual mbinit_if)::get(this, "", "mbinit_vif", vif))
      `uvm_info("TEST_SNAP", $sformatf(
        "After seq: fsmCtrl_done=%b fsmCtrl_error=%b requester_currentState=%0d (6=TOMBTRAIN) req_rx_v=%b rsp_rx_v=%b",
        vif.fsmCtrl_done, vif.fsmCtrl_error, vif.currentState,
        vif.requesterSbLaneIo_rx_valid, vif.responderSbLaneIo_rx_valid), UVM_LOW)
    else
      `uvm_warning("TEST", "mbinit_vif not in config_db — add for TEST_SNAP diagnostics")

    #20000ns;

    if (uvm_config_db#(virtual mbinit_if)::get(this, "", "mbinit_vif", vif))
      `uvm_info("TEST_SNAP", $sformatf(
        "After +20us idle: fsmCtrl_done=%b fsmCtrl_error=%b requester_currentState=%0d",
        vif.fsmCtrl_done, vif.fsmCtrl_error, vif.currentState), UVM_LOW)

    `uvm_info("TEST", "Test seq_mbinit_full finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// MBINIT.CAL — MC-01/02 (and MP-06) with delayed mbInitCalDone (see seq_mbinit_cal_only).
class test_mbinit_cal extends mbinit_base_test;
  `uvm_component_utils(test_mbinit_cal)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbinit_cal_only seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbinit        = 0;
    env.scoreboard.expect_mbinit_through_cal = 1;
    env.scoreboard.expect_param_messages     = 0;
    env.scoreboard.expect_param_common_rate  = 0;
    env.scoreboard.expect_param_negotiation  = 0;
    env.scoreboard.expect_fsm_done           = 0;

    `uvm_info("TEST", "Starting seq_mbinit_cal_only...", UVM_LOW)
    seq = seq_mbinit_cal_only::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #8000ns;

    `uvm_info("TEST", "Test test_mbinit_cal finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// MBINIT.REPAIRCLK — RC-01/02/05 (PARAM/CAL prefix + full RCLK happy path).
class test_mbinit_repairclk extends mbinit_base_test;
  `uvm_component_utils(test_mbinit_repairclk)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbinit_repairclk_only seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbinit             = 0;
    env.scoreboard.expect_mbinit_through_cal      = 0;
    env.scoreboard.expect_mbinit_through_repairclk = 1;
    env.scoreboard.expect_param_messages          = 0;
    env.scoreboard.expect_param_common_rate       = 0;
    env.scoreboard.expect_param_negotiation       = 0;
    env.scoreboard.expect_fsm_done                = 0;

    `uvm_info("TEST", "Starting seq_mbinit_repairclk_only...", UVM_LOW)
    seq = seq_mbinit_repairclk_only::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #12000ns;

    `uvm_info("TEST", "Test test_mbinit_repairclk finished.", UVM_LOW)
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

// RC-03: unrepairable clock repair — DUT must assert fsmCtrl_error.
class test_mbinit_repairclk_unrep extends mbinit_base_test;
  `uvm_component_utils(test_mbinit_repairclk_unrep)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbinit_repairclk_fail seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbinit = 0;
    env.scoreboard.expect_fsm_done    = 0;
    env.scoreboard.expect_fsm_error   = 1;
    env.scoreboard.expect_repairclk_rc03 = 1;

    `uvm_info("TEST", "Starting seq_mbinit_repairclk_fail...", UVM_LOW)
    seq = seq_mbinit_repairclk_fail::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #5000ns;

    `uvm_info("TEST", "Test test_mbinit_repairclk_unrep finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// RV-06: unrepairable valid repair — DUT must assert fsmCtrl_error.
class test_mbinit_repairval_unrep extends mbinit_base_test;
  `uvm_component_utils(test_mbinit_repairval_unrep)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbinit_repairval_fail seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbinit = 0;
    env.scoreboard.expect_fsm_done    = 0;
    env.scoreboard.expect_fsm_error   = 1;

    `uvm_info("TEST", "Starting seq_mbinit_repairval_fail...", UVM_LOW)
    seq = seq_mbinit_repairval_fail::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #5000ns;

    `uvm_info("TEST", "Test test_mbinit_repairval_unrep finished.", UVM_LOW)
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

// LR-04: REVERSALMB RESULT fail then pass — requester must assert applyLaneReversal (retry path).
class test_mbinit_lr04_reversal_apply extends mbinit_base_test;
  `uvm_component_utils(test_mbinit_lr04_reversal_apply)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbinit_full_lr04_retry seq;
    phase.raise_objection(this);

    env.scoreboard.expect_fsm_done               = 0;
    env.scoreboard.expect_lr04_apply_lane_reversal = 1;

    `uvm_info("TEST", "Starting seq_mbinit_full_lr04_retry...", UVM_LOW)
    seq = seq_mbinit_full_lr04_retry::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #20000ns;

    `uvm_info("TEST", "Test test_mbinit_lr04_reversal_apply finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// LR-07: second REVERSALMB RESULT still fails after lane-reversal apply → MBInit requester error
// (fsmCtrl_error on this TB; fused LTSM TRAINERROR SB not checked).
class test_mbinit_lr07_reversal_trainerror extends mbinit_base_test;
  `uvm_component_utils(test_mbinit_lr07_reversal_trainerror)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbinit_lr07_reversal_double_fail seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbinit = 0;
    env.scoreboard.expect_fsm_done    = 0;
    env.scoreboard.expect_fsm_error   = 1;

    `uvm_info("TEST", "Starting seq_mbinit_lr07_reversal_double_fail...", UVM_LOW)
    seq = seq_mbinit_lr07_reversal_double_fail::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #15000ns;

    `uvm_info("TEST", "Test test_mbinit_lr07_reversal_trainerror finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// RM-02: PatternReader response carries heterogeneous per-lane pass/fail in REPAIRMB (driver inject).
class test_mbinit_rm02_per_lane_reader extends mbinit_base_test;
  `uvm_component_utils(test_mbinit_rm02_per_lane_reader)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    mbinit_driver dr;
    super.end_of_elaboration_phase(phase);
    if (!$cast(dr, env.agent.driver))
      `uvm_fatal("TEST", "test_mbinit_rm02_per_lane_reader: expected mbinit_driver")
    dr.rm02_mixed_pt_first = 1'b1;
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbinit_full seq;
    phase.raise_objection(this);

    env.scoreboard.expect_fsm_done               = 0;
    env.scoreboard.expect_rm02_per_lane_reader   = 1;

    `uvm_info("TEST", "Starting seq_mbinit_full (RM-02 mixed first Tx point-test in REPAIRMB)...", UVM_LOW)
    seq = seq_mbinit_full::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #20000ns;

    `uvm_info("TEST", "Test test_mbinit_rm02_per_lane_reader finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// RM-07: unrepairable lane situation in REPAIRMB → fsmCtrl_error (LTSM TRAINERROR not in MBInit-only TB).
class test_mbinit_rm07_unrepairable extends mbinit_base_test;
  `uvm_component_utils(test_mbinit_rm07_unrepairable)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    mbinit_driver dr;
    super.end_of_elaboration_phase(phase);
    if (!$cast(dr, env.agent.driver))
      `uvm_fatal("TEST", "test_mbinit_rm07_unrepairable: expected mbinit_driver")
    dr.rm07_first_repairmb_pt_all_fault = 1'b1;
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbinit_full seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbinit              = 0;
    env.scoreboard.expect_fsm_done                 = 0;
    env.scoreboard.expect_fsm_error                = 1;
    env.scoreboard.expect_rm07_repairmb_unrepairable = 1;

    `uvm_info("TEST", "Starting seq_mbinit_full (RM-07 all-fault first REPAIRMB point test)...", UVM_LOW)
    seq = seq_mbinit_full::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #20000ns;

    `uvm_info("TEST", "Test test_mbinit_rm07_unrepairable finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// RM-05: directed upper-half fault then full-fault PT in REPAIRMB — witness ≥2 result beats +
// io_txWidthChanged pulse (see vplan gap: fsmCtrl_error / TRAINERROR not closed on this path).
class test_mbinit_rm05_post_repair_persist extends mbinit_base_test;
  `uvm_component_utils(test_mbinit_rm05_post_repair_persist)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    mbinit_driver dr;
    super.end_of_elaboration_phase(phase);
    if (!$cast(dr, env.agent.driver))
      `uvm_fatal("TEST", "test_mbinit_rm05_post_repair_persist: expected mbinit_driver")
    dr.rm05_post_repair_pt_sequence = 1'b1;
  endfunction

  task run_phase(uvm_phase phase);
    seq_mbinit_full_rm05 seq;
    phase.raise_objection(this);

    env.scoreboard.expect_full_mbinit                = 0;
    env.scoreboard.expect_fsm_done                   = 0;
    env.scoreboard.expect_fsm_error                  = 0;
    env.scoreboard.expect_rm05_post_repair_witness  = 1;

    `uvm_info("TEST", "Starting seq_mbinit_full_rm05 (RM-05 upper-half fault then all-fault PT)...", UVM_LOW)
    seq = seq_mbinit_full_rm05::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #25000ns;

    `uvm_info("TEST", "Test test_mbinit_rm05_post_repair_persist finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

`endif

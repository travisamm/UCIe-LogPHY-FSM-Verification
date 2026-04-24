`ifndef LOGPHY_SBINIT_TESTS_SV
`define LOGPHY_SBINIT_TESTS_SV

// SB-01: UCIe Module must send 64-UI clock pattern (1010...) and 32-UI low on both SB data Tx
// SB-02: UCIe Module Partner must sample incoming SB data patterns with incoming clock
// SB-03: On pattern detection, must stop sending after completing current iteration
class test_sbinit_sanity extends logphy_base_test;
  `uvm_component_utils(test_sbinit_sanity)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_sbinit_ideal seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "Starting seq_sbinit_ideal...", UVM_LOW)
    seq = seq_sbinit_ideal::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #10000ns;

    `uvm_info("TEST", "Test seq_sbinit_ideal finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// SB-04: If pattern not detected, must continue alternating for total of 8ms then timeout to TRAINERROR
class test_sbinit_timeout extends logphy_base_test;
  // Test should show fsm_done=0, but will not properly error until SBInit.scala line 32
  // is changed so that error is not hardcoded to false.
  `uvm_component_utils(test_sbinit_timeout)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_sbinit_timeout seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "Starting seq_sbinit_timeout...", UVM_LOW)
    seq = seq_sbinit_timeout::type_id::create("seq");
    seq.start(env.agent.sequencer);

    // Give it enough time to hit the 8ms timeout
    #10000ns; 

    `uvm_info("TEST", "Test seq_sbinit_timeout finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// SB-06: Must send {SBINIT Out of Reset} sideband message continuously until partner detection
class test_sbinit_partner_not_ready extends logphy_base_test;
  `uvm_component_utils(test_sbinit_partner_not_ready)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_sbinit_delayed_ready seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "Starting seq_sbinit_delayed_ready...", UVM_LOW)
    seq = seq_sbinit_delayed_ready::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #10000ns;

    `uvm_info("TEST", "Test seq_sbinit_delayed_ready finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// SB-09: Module partner must collapse multiple outstanding {SBINIT done req} messages into single response
class test_sbinit_multiple_reqs extends logphy_base_test;
  `uvm_component_utils(test_sbinit_multiple_reqs)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_sbinit_collapse_reqs seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "Starting seq_sbinit_collapse_reqs...", UVM_LOW)
    seq = seq_sbinit_collapse_reqs::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #10000ns;

    `uvm_info("TEST", "Test seq_sbinit_collapse_reqs finished.", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

`endif

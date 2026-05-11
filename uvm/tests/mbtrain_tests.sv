`ifndef MBTRAIN_TESTS_SV
`define MBTRAIN_TESTS_SV

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

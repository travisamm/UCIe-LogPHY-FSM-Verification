`ifndef MBINIT_SERVICE_CFG_SV
`define MBINIT_SERVICE_CFG_SV

// ---------------------------------------------------------------------------
// mbinit_service_cfg  (Pass 3)
// ---------------------------------------------------------------------------
// Shared live policy for the autonomous service stubs (cal / pattern-writer /
// pattern-reader / point-test). The legacy adapter owns one instance, updates
// the per-item knobs as it consumes each mbinit_transaction, and copies the RM
// scenario flags (set by the rm02/rm07/rm05 tests on env.agent.driver) into it
// at start_of_simulation. The stubs read these fields live when they act.
//
// This is the Pass 3 mechanism for "forward the RM flags + service knobs into
// the point-test/service stubs" without the stubs needing the legacy driver.
// ---------------------------------------------------------------------------
class mbinit_service_cfg extends uvm_object;
  `uvm_object_utils(mbinit_service_cfg)

  // Per-item service knobs (updated by the adapter as items arrive).
  int unsigned cal_done_repeat_cycles   = 3;
  bit [15:0]   pattern_reader_per_lane   = 16'hFFFF;
  bit          pattern_reader_aggregate  = 1'b1;
  bit [15:0]   pt_test_results           = 16'h0000;

  // REPAIRMB point-test scenario injects (copied from the legacy driver fields).
  bit          rm02_mixed_pt_first              = 1'b0;
  bit          rm07_first_repairmb_pt_all_fault = 1'b0;
  bit          rm05_post_repair_pt_sequence     = 1'b0;

  function new(string name = "mbinit_service_cfg");
    super.new(name);
  endfunction
endclass

`endif

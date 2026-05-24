`ifndef SBINIT_RESET_TRANSACTION_SV
`define SBINIT_RESET_TRANSACTION_SV

// ---------------------------------------------------------------------------
// sbinit_reset_transaction
// ---------------------------------------------------------------------------
// A request to inject a reset pulse: wait `delay` cycles, then hold the DUT in
// reset for `cycles` cycles, then release.
// ---------------------------------------------------------------------------
class sbinit_reset_transaction extends uvm_sequence_item;

  rand int delay;    // cycles to wait before asserting reset
  rand int cycles;   // cycles to hold reset asserted

  `uvm_object_utils_begin(sbinit_reset_transaction)
    `uvm_field_int(delay,  UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(cycles, UVM_ALL_ON | UVM_DEC)
  `uvm_object_utils_end

  function new(string name = "sbinit_reset_transaction");
    super.new(name);
    delay  = 0;
    cycles = 5;
  endfunction

endclass

`endif

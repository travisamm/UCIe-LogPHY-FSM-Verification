`ifndef SBINIT_TXREADY_TRANSACTION_SV
`define SBINIT_TXREADY_TRANSACTION_SV

// ---------------------------------------------------------------------------
// sbinit_txready_transaction
// ---------------------------------------------------------------------------
// Drive item for the tx-ready (back-pressure) channel, shared by both lanes
// since the field set is identical. tx_ready is a LEVEL: the driver applies it
// and holds it for `hold_cycles`, then leaves it at that value until the next
// item changes it. `delay` waits at the current level before applying the new
// one. This lets a sequence assert/deassert back-pressure independently of the
// rx channel on the same lane.
// ---------------------------------------------------------------------------
class sbinit_txready_transaction extends uvm_sequence_item;
  rand logic tx_ready;
  rand int   delay;
  rand int   hold_cycles;

  `uvm_object_utils_begin(sbinit_txready_transaction)
    `uvm_field_int(tx_ready,    UVM_ALL_ON)
    `uvm_field_int(delay,       UVM_ALL_ON)
    `uvm_field_int(hold_cycles, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "sbinit_txready_transaction");
    super.new(name);
    tx_ready    = 1;  // partner ready to accept by default
    delay       = 0;
    hold_cycles = 1;
  endfunction
endclass

`endif

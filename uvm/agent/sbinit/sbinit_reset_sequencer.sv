`ifndef SBINIT_RESET_SEQUENCER_SV
`define SBINIT_RESET_SEQUENCER_SV

// ---------------------------------------------------------------------------
// sbinit_reset_sequencer
// ---------------------------------------------------------------------------
// Sequencer for reset-injection items. Lives at env level (with the reset
// driver and monitor); a vseq drives it via sbinit_base_vseq::pulse_reset().
// ---------------------------------------------------------------------------
class sbinit_reset_sequencer extends uvm_sequencer #(sbinit_reset_transaction);
  `uvm_component_utils(sbinit_reset_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass

`endif

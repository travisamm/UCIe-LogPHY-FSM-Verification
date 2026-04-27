`ifndef MBINIT_AGENT_PKG_SV
`define MBINIT_AGENT_PKG_SV

package mbinit_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Base transaction (logphy_transaction) must be defined first
  import logphy_agent_pkg::*;

  // MBINIT-specific transaction (extends logphy_transaction)
  `include "mbinit_transaction.sv"

  // Inline sequencer typed to the MBINIT transaction
  class mbinit_sequencer extends uvm_sequencer #(mbinit_transaction);
    `uvm_component_utils(mbinit_sequencer)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  `include "mbinit_driver.sv"
  `include "mbinit_monitor.sv"

  // Agent — same structure as logphy_agent, typed to MBINIT classes
  class mbinit_agent extends uvm_agent;
    `uvm_component_utils(mbinit_agent)

    mbinit_driver    driver;
    mbinit_sequencer sequencer;
    mbinit_monitor   monitor;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      monitor = mbinit_monitor::type_id::create("monitor", this);
      if (get_is_active() == UVM_ACTIVE) begin
        driver    = mbinit_driver::type_id::create("driver", this);
        sequencer = mbinit_sequencer::type_id::create("sequencer", this);
      end
    endfunction

    function void connect_phase(uvm_phase phase);
      if (get_is_active() == UVM_ACTIVE)
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass

endpackage
`endif

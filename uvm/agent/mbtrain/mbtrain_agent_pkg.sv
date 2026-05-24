`ifndef MBTRAIN_AGENT_PKG_SV
`define MBTRAIN_AGENT_PKG_SV

package mbtrain_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Base transaction (logphy_transaction) must be defined first
  import logphy_agent_pkg::*;

  // MBTrain-specific transaction (extends logphy_transaction)
  `include "mbtrain_transaction.sv"

  // Inline sequencer typed to the MBTrain transaction
  class mbtrain_sequencer extends uvm_sequencer #(mbtrain_transaction);
    `uvm_component_utils(mbtrain_sequencer)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  `include "mbtrain_driver.sv"
  `include "mbtrain_monitor.sv"

  // Agent
  class mbtrain_agent extends uvm_agent;
    `uvm_component_utils(mbtrain_agent)

    mbtrain_driver    driver;
    mbtrain_sequencer sequencer;
    mbtrain_monitor   monitor;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      monitor = mbtrain_monitor::type_id::create("monitor", this);
      if (get_is_active() == UVM_ACTIVE) begin
        driver    = mbtrain_driver::type_id::create("driver", this);
        sequencer = mbtrain_sequencer::type_id::create("sequencer", this);
      end
    endfunction

    function void connect_phase(uvm_phase phase);
      if (get_is_active() == UVM_ACTIVE)
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass

endpackage
`endif

`ifndef LOGPHY_AGENT_PKG_SV
`define LOGPHY_AGENT_PKG_SV

package logphy_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "logphy_transaction.sv"
  `include "logphy_sequencer.sv"
  `include "logphy_driver.sv"
  `include "logphy_monitor.sv"
  `include "logphy_agent.sv"

endpackage
`endif

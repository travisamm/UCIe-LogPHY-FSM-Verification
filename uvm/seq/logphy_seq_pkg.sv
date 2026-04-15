`ifndef LOGPHY_SEQ_PKG_SV
`define LOGPHY_SEQ_PKG_SV

package logphy_seq_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import logphy_agent_pkg::*;

  `include "logphy_base_seq.sv"
  `include "logphy_sbinit_seq.sv"

endpackage
`endif

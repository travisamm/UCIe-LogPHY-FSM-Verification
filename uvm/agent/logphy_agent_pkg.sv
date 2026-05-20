// logphy_agent_pkg
//
// Minimal back-compat surface kept around solely for the MBINIT and MBTRAIN
// suites, whose mbinit_transaction / mbtrain_transaction classes extend
// logphy_transaction. The SBINIT suite no longer references anything in this
// package — it builds against sbinit_agent_pkg instead.
//
// Do not add new SBINIT content here. If MBINIT/MBTRAIN are eventually
// refactored to stop extending logphy_transaction, this file can go away
// entirely.

`ifndef LOGPHY_AGENT_PKG_SV
`define LOGPHY_AGENT_PKG_SV

package logphy_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "logphy_transaction.sv"

endpackage

`endif

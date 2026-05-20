// This file declares two packages:
//
//   * `logphy_agent_pkg` — minimal back-compat surface (logphy_transaction
//     and logphy_sequencer) consumed by mbinit_agent_pkg / mbtrain_agent_pkg
//     and by the legacy SBINIT test bodies (env.agent.sequencer).
//
//   * `sbinit_agent_pkg` — the new two-agent SBINIT verification surface.
//
// Both packages live in this single physical file because the Makefile
// compiles it by historical filename; the SV LRM has no requirement that
// file name and package name match.

`ifndef LOGPHY_AGENT_PKG_SV
`define LOGPHY_AGENT_PKG_SV

`include "sbinit_msg_pkg.sv"

package logphy_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "logphy_transaction.sv"
  `include "logphy_sequencer.sv"

endpackage

package sbinit_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import sbinit_msg_pkg::*;
  // Re-export logphy_transaction / logphy_sequencer so back-compat
  // consumers that import sbinit_agent_pkg also see them.
  import logphy_agent_pkg::*;

  `include "sbinit_req_transaction.sv"
  `include "sbinit_req_sequencer.sv"
  `include "sbinit_req_driver.sv"
  `include "sbinit_req_monitor.sv"
  `include "sbinit_req_agent.sv"
  `include "sbinit_rsp_transaction.sv"
  `include "sbinit_rsp_sequencer.sv"
  `include "sbinit_rsp_driver.sv"
  `include "sbinit_rsp_monitor.sv"
  `include "sbinit_rsp_agent.sv"

endpackage

`endif

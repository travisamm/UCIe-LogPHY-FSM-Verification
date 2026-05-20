`ifndef SBINIT_AGENT_PKG_SV
`define SBINIT_AGENT_PKG_SV

`include "sbinit_msg_pkg.sv"

package sbinit_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import sbinit_msg_pkg::*;

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

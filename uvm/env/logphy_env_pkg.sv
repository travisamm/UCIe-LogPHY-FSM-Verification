// Compiled by the Makefile under its historical filename
// (./env/logphy_env_pkg.sv). The actual package payload is sbinit_env_pkg.

`ifndef LOGPHY_ENV_PKG_SV
`define LOGPHY_ENV_PKG_SV

package sbinit_env_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import logphy_agent_pkg::*;
  import sbinit_agent_pkg::*;
  import sbinit_msg_pkg::*;

  `include "sbinit_env_cfg.sv"
  `include "sbinit_virtual_sequencer.sv"
  `include "../coverage/sbinit_coverage.sv"
  `include "sbinit_scoreboard.sv"
  `include "sbinit_env.sv"

endpackage

`endif

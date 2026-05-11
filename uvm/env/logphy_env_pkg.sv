`ifndef LOGPHY_ENV_PKG_SV
`define LOGPHY_ENV_PKG_SV

package logphy_env_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import logphy_agent_pkg::*;

  `include "logphy_scoreboard.sv"
  `include "../coverage/sbinit_coverage.sv"
  `include "logphy_env.sv"

endpackage
`endif

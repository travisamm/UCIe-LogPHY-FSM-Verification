`ifndef MBINIT_ENV_PKG_SV
`define MBINIT_ENV_PKG_SV

package mbinit_env_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import mbinit_agent_pkg::*;

  `include "mbinit_scoreboard.sv"
  `include "mbinit_env.sv"

endpackage
`endif

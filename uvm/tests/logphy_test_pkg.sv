// Compiled by the Makefile under its historical filename
// (./tests/logphy_test_pkg.sv). The actual package payload is
// sbinit_test_pkg.

`ifndef LOGPHY_TEST_PKG_SV
`define LOGPHY_TEST_PKG_SV

package sbinit_test_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import logphy_agent_pkg::*;
  import sbinit_agent_pkg::*;
  import sbinit_env_pkg::*;
  import sbinit_seq_pkg::*;
  import sbinit_msg_pkg::*;

  `include "sbinit_base_test.sv"
  `include "logphy_sbinit_tests.sv"

endpackage

`endif

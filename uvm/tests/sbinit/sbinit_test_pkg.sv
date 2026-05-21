`ifndef SBINIT_TEST_PKG_SV
`define SBINIT_TEST_PKG_SV
`timescale 1ns/1ps

package sbinit_test_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import sbinit_agent_pkg::*;
  import sbinit_env_pkg::*;
  import sbinit_seq_pkg::*;
  import sbinit_msg_pkg::*;

  `include "sbinit_base_test.sv"
  `include "sbinit_tests.sv"

endpackage

`endif

// Compiled by the Makefile under its historical filename
// (./seq/logphy_seq_pkg.sv). The actual package payload is sbinit_seq_pkg.

`ifndef LOGPHY_SEQ_PKG_SV
`define LOGPHY_SEQ_PKG_SV

package sbinit_seq_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import logphy_agent_pkg::*;
  import sbinit_agent_pkg::*;
  import sbinit_msg_pkg::*;

  `include "sbinit_base_vseq.sv"

  // Legacy back-compat: the test bodies in logphy_sbinit_tests.sv still
  // construct these sequence classes verbatim. They extend uvm_sequence
  // #(logphy_transaction) and are no longer wired up to a real driver;
  // TODO: rewrite them onto the two-agent virtual sequencer.
  `include "logphy_base_seq.sv"
  `include "logphy_sbinit_seq.sv"

endpackage

`endif

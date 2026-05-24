`ifndef SBINIT_SEQ_PKG_SV
`define SBINIT_SEQ_PKG_SV
`timescale 1ns/1ps

package sbinit_seq_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import sbinit_agent_pkg::*;
  import sbinit_msg_pkg::*;
  import sbinit_env_pkg::*;   // for sbinit_virtual_sequencer (p_sequencer type)

  `include "sbinit_base_vseq.sv"
  `include "sbinit_seq.sv"

endpackage

`endif
